-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: perlin.vhd - Perlin Program for Videomancer
-- License: GNU General Public License v3.0
-- https://github.com/lzxindustries/videomancer-sdk
--
-- This file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- Program Name:
--   Perlin
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Gradient noise texture synthesizer with BRAM-backed artist colour palettes.
--   Implements animated 2D Perlin noise with a two-octave fBm variant: octave 1
--   uses the classic gradient noise algorithm (8 compass-point gradient directions,
--   per-cell XOR-fold hash); octave 2 reuses the same smoothstep weights but
--   samples value noise at 2x lattice frequency (doubled cell resolution from the
--   same scaled coordinate, requiring no extra multiply).
--
--   Domain warp: a per-column line buffer (1 BRAM, 256 slots) stores each line's
--   noise output and applies it as a Y-axis coordinate perturbation to the
--   following line, creating flowing self-referential warp feedback.
--
--   Four rich artist colour palettes (Marble, Fire, Ocean, Neon) are each
--   stored as 256 full-colour YUV entries in BRAM.  The palette memory uses 6
--   EBR blocks: Y=2, U=2, V=2 (1024 entries x 8-bit per channel).
--   Palette phase is animated by a dedicated DDS accumulator (Pot 6).
--
--   Cubic smoothstep (f=3t^2-2t^3) replaces the quadratic approximation,
--   eliminating grid-line continuity artifacts.  Implemented over 3 pipeline
--   stages (squarer, factor, product) for HD timing closure.
--
--   Gentle contrast (1.125x) is centre-stretched around mid-luma to avoid
--   hard clipping.  Palettes use smooth symmetric indexing so that the
--   256-entry wrap point produces no visible seam.  Ridge mode (toggle 7) folds
--   the noise through an absolute-value for turbulence / ridged-mountain
--   aesthetics.  Video-multiply mode (toggle 10) gates the noise luma through
--   the input video for texture-overlay compositing.  Wet/dry crossfade at
--   the output uses a 3-stage pipelined multiplier.
--
-- Resources:
--   7x BRAM : 1 warp buffer + 2 pal-Y + 2 pal-U + 2 pal-V
--   ~6800 LCs (hash x8, grad-dot x8, cubic smoothstep x2 shared,
--              bilinear lerp x4 oct1 + x4 oct2 (value noise),
--              octave blend, ridge, palette, contrast, video-mul, mix)
--
-- Pipeline (all clocked; BRAM reads = 1-cycle registered latency):
--   S0  (implicit) : warp BRAM pre-read issued at s_hcount
--   S1  : scroll + warp offset applied to hcount/vcount
--   S2  : coordinate scale multiply (23-bit; shared oct1 + oct2 by different bit-slice)
--   S3  : cell/frac extraction; 8-corner XOR-fold hash (oct1 x4, oct2 x4)
--   S4  : cubic smoothstep sq (7x7 squarers); delay hash/frac
--   S5  : cubic smoothstep factor (384-2t); delay sq/hash
--   S6  : cubic smoothstep product (sq x factor >> 14 = sx/sy); oct1 dot products
--   S7  : register sx/sy, dots (oct1), value-noise (oct2)
--   S8  : horizontal lerp diffs (4 oct1, 4 oct2)
--   S9  : horizontal lerp products (9bx7b each)
--   S10 : horizontal lerp sums -> lerp_top/bot per octave
--   S11 : vertical lerp diffs + base delay
--   S12 : vertical lerp products
--   S13 : vertical lerp sums -> noise1 (oct1), noise2 (oct2)
--   S14 : octave blend; ridge mode; palette index; warp BRAM write
--   [palette BRAM read initiated from s_palbram_addr at S14]
--   S15 : palette YUV expansion (8->10bit); palette BRAM output registered
--   S16 : contrast multiply (12bx11b); video-mod; output
--   S17-S19 : wet/dry mix (3 registered stages)
--   Total C_PROCESSING_DELAY_CLKS = 26
--
-- Parameters:
--   Pot 1  (registers_in(0))     : Scroll X     -- horizontal DDS velocity
--   Pot 2  (registers_in(1))     : Scale        -- lattice zoom (steps_8)
--   Pot 3  (registers_in(2))     : Scroll Y     -- vertical DDS velocity
--   Pot 4  (registers_in(3))     : Warp         -- domain-warp feedback gain
--   Pot 5  (registers_in(4))     : Palette Shift -- static colour phase offset
--   Pot 6  (registers_in(5))     : Palette Speed -- animated cycle rate
--   Tog 7  (registers_in(6)(0))  : Texture      -- 0=Gradient, 1=Ridged
--   Tog 8  (registers_in(6)(1))  : Palette      -- 0=A (Marble/Fire), 1=B (Ocean/Neon)
--   Tog 9  (registers_in(6)(2))  : Color        -- 0=Warm (Marble/Ocean), 1=Cool (Fire/Neon)
--   Tog 10 (registers_in(6)(3))  : Video        -- 0=Noise, 1=Multiply with input Y
--   Tog 11 (registers_in(6)(4))  : Octave       -- 0=oct1 only, 1=fBm blend oct1+oct2
--   Fader  (registers_in(7))     : Mix          -- wet/dry
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture perlin of program_top is

    -- Total pipeline delay: 2 warp pre-reads + 16 processing stages
    -- + 1 pal-BRAM latency + 3 mix = 22.  Add 4 for sync alignment.
    constant C_PROCESSING_DELAY_CLKS : integer := 26;

    -- ========================================================================
    -- Parameters
    -- ========================================================================
    signal s_scroll_x    : unsigned(9 downto 0);
    signal s_scale       : unsigned(9 downto 0);
    signal s_scroll_y    : unsigned(9 downto 0);
    signal s_warp_amt    : unsigned(9 downto 0);
    signal s_pal_shift   : unsigned(9 downto 0);
    signal s_pal_speed   : unsigned(9 downto 0);
    signal s_ridge_mode  : std_logic;
    signal s_pal_bank    : std_logic;
    signal s_pal_color   : std_logic;
    signal s_video_mul   : std_logic;
    signal s_octave_en   : std_logic;
    signal s_mix_amt     : unsigned(9 downto 0);

    -- Vsync-registered working copies
    signal s_scale_mul   : unsigned(10 downto 0) := to_unsigned(32, 11);
    signal s_warp_gain   : unsigned(9 downto 0)  := (others => '0');
    signal s_pal_bank_r  : std_logic := '0';
    signal s_pal_color_r : std_logic := '0';
    signal s_video_mul_r : std_logic := '0';
    signal s_octave_r    : std_logic := '0';
    signal s_ridge_r     : std_logic := '0';

    -- ========================================================================
    -- Scroll DDS + palette DDS
    -- ========================================================================
    signal s_x_offset    : unsigned(15 downto 0) := (others => '0');
    signal s_y_offset    : unsigned(15 downto 0) := (others => '0');
    signal s_pal_offset  : unsigned(9 downto 0)  := (others => '0');

    -- ========================================================================
    -- Video Timing + pixel counters
    -- ========================================================================
    signal s_timing      : t_video_timing_port;
    signal s_hcount      : unsigned(11 downto 0) := (others => '0');
    signal s_vcount      : unsigned(11 downto 0) := (others => '0');

    -- ========================================================================
    -- Warp BRAM  (1 EBR: 256 x signed 8-bit)
    -- Written at S14 (delayed hcount), read pre-issued at hcount for S1.
    -- ========================================================================
    type t_warp_bram is array(0 to 255) of signed(7 downto 0);
    signal s_warp_bram    : t_warp_bram := (others => (others => '0'));
    signal s_warp_rd      : signed(7 downto 0) := (others => '0');
    signal s_warp_rd2     : signed(7 downto 0) := (others => '0');  -- extra pipeline reg

    -- hcount delayed by 15 cycles (S0..S14) for warp-BRAM write address
    type t_hc14 is array(0 to 15) of unsigned(7 downto 0);
    signal s_hc14         : t_hc14 := (others => (others => '0'));

    -- ========================================================================
    -- Palette BRAMs  (6 EBR total: Y 2 + U 2 + V 2)
    -- 4 palettes x 256 entries = 1024 total.
    -- Address: {pal_sel[1:0], palette_index[7:0]}
    -- Palettes: 0=Marble, 1=Fire, 2=Ocean, 3=Neon
    -- ========================================================================
    type t_pal is array(0 to 1023) of std_logic_vector(7 downto 0);

    -- --- palette helpers (evaluated at elaboration time) ---
    function ilerp(a, b, t, tmax : integer) return integer is
    begin
        if tmax = 0 then return a; end if;
        return a + (b - a) * t / tmax;
    end function;

    function iclamp(x : integer) return integer is
    begin
        if x < 0 then return 0; elsif x > 255 then return 255;
        else return x; end if;
    end function;

    -- Smooth symmetric index: maps 0..255 to a seamless 0..255..0
    -- cycle using cubic smoothstep so palette wrapping has no seam.
    function fn_smooth_idx(idx : integer) return integer is
        variable t   : integer;
        variable ss  : integer;
    begin
        if idx < 128 then
            t := idx;
        else
            t := 255 - idx;
        end if;
        -- Cubic smoothstep: f(t) = t^2*(384-2t)/16384, t in [0..128]->[0..128]
        -- Then scale to 0..255.
        ss := (t * t * (384 - 2 * t)) / 16384;
        ss := (ss * 255) / 128;
        if ss > 255 then ss := 255; end if;
        if ss < 0   then ss := 0;   end if;
        return ss;
    end function;

    function fn_y(pal, idx : integer) return integer is
        variable y : integer := 0;
    begin
        case pal is
            when 0 =>   -- Marble: warm grayscale
                y := (idx * 245) / 255;
            when 1 =>   -- Fire
                if    idx < 60  then y := ilerp(0,   40,  idx,      60);
                elsif idx < 100 then y := ilerp(40,   90,  idx-60,  40);
                elsif idx < 150 then y := ilerp(90,  150,  idx-100, 50);
                elsif idx < 200 then y := ilerp(150, 210,  idx-150, 50);
                elsif idx < 240 then y := ilerp(210, 245,  idx-200, 40);
                else                 y := ilerp(245, 255,  idx-240, 15); end if;
            when 2 =>   -- Ocean
                if    idx < 64  then y := ilerp(0,   25,  idx,      64);
                elsif idx < 128 then y := ilerp(25,   80,  idx-64,  64);
                elsif idx < 192 then y := ilerp(80,  170,  idx-128, 64);
                else                 y := ilerp(170, 245,  idx-192, 63); end if;
            when others => -- Neon
                if    idx < 64  then y := ilerp(0,   50,  idx,      64);
                elsif idx < 128 then y := ilerp(50,  130,  idx-64,  64);
                elsif idx < 192 then y := ilerp(130, 190,  idx-128, 64);
                else                 y := ilerp(190, 255,  idx-192, 63); end if;
        end case;
        return iclamp(y);
    end function;

    function fn_u(pal, idx : integer) return integer is
        variable u : integer := 128;
    begin
        case pal is
            when 0 =>  u := iclamp(128 - (idx * 4) / 255);  -- Marble: slight cool
            when 1 =>  -- Fire: push low (orange/yellow)
                if    idx < 60  then u := ilerp(128,  98,  idx,      60);
                elsif idx < 100 then u := ilerp(98,   75,  idx-60,  40);
                elsif idx < 150 then u := ilerp(75,   50,  idx-100, 50);
                elsif idx < 200 then u := ilerp(50,   55,  idx-150, 50);
                elsif idx < 240 then u := ilerp(55,   90,  idx-200, 40);
                else                 u := ilerp(90,  120,  idx-240, 15); end if;
            when 2 =>  -- Ocean: high Cb (blue)
                if    idx < 64  then u := ilerp(128, 185,  idx,      64);
                elsif idx < 128 then u := ilerp(185, 200,  idx-64,  64);
                elsif idx < 192 then u := ilerp(200, 175,  idx-128, 64);
                else                 u := ilerp(175, 148,  idx-192, 63); end if;
            when others =>  -- Neon: low Cb for violet; dives for acid-green
                if    idx < 64  then u := ilerp(128,  70,  idx,      64);
                elsif idx < 128 then u := ilerp(70,   85,  idx-64,  64);
                elsif idx < 192 then u := ilerp(85,   40,  idx-128, 64);
                else                 u := ilerp(40,  100,  idx-192, 63); end if;
        end case;
        return iclamp(u);
    end function;

    function fn_v(pal, idx : integer) return integer is
        variable v : integer := 128;
    begin
        case pal is
            when 0 =>  v := iclamp(128 + (idx * 3) / 255);  -- Marble: slight warm
            when 1 =>  -- Fire: high Cr (red), descend to neutral
                if    idx < 60  then v := ilerp(128, 200,  idx,      60);
                elsif idx < 100 then v := ilerp(200, 215,  idx-60,  40);
                elsif idx < 150 then v := ilerp(215, 195,  idx-100, 50);
                elsif idx < 200 then v := ilerp(195, 170,  idx-150, 50);
                elsif idx < 240 then v := ilerp(170, 148,  idx-200, 40);
                else                 v := ilerp(148, 135,  idx-240, 15); end if;
            when 2 =>  -- Ocean: low Cr (toward cyan)
                if    idx < 64  then v := ilerp(128,  88,  idx,      64);
                elsif idx < 128 then v := ilerp(88,   90,  idx-64,  64);
                elsif idx < 192 then v := ilerp(90,  100,  idx-128, 64);
                else                 v := ilerp(100, 115,  idx-192, 63); end if;
            when others =>  -- Neon: high Cr for violet; plunge for acid-green
                if    idx < 64  then v := ilerp(128, 175,  idx,      64);
                elsif idx < 128 then v := ilerp(175, 155,  idx-64,  64);
                elsif idx < 192 then v := ilerp(155,  75,  idx-128, 64);
                else                 v := ilerp(75,  110,  idx-192, 63); end if;
        end case;
        return iclamp(v);
    end function;

    function fn_init_y return t_pal is
        variable r : t_pal;
        variable m : integer;
    begin
        for p in 0 to 3 loop
            for i in 0 to 255 loop
                m := fn_smooth_idx(i);
                r(p*256+i) := std_logic_vector(to_unsigned(fn_y(p,m),8));
            end loop;
        end loop;
        return r;
    end function;

    function fn_init_u return t_pal is
        variable r : t_pal;
        variable m : integer;
    begin
        for p in 0 to 3 loop
            for i in 0 to 255 loop
                m := fn_smooth_idx(i);
                r(p*256+i) := std_logic_vector(to_unsigned(fn_u(p,m),8));
            end loop;
        end loop;
        return r;
    end function;

    function fn_init_v return t_pal is
        variable r : t_pal;
        variable m : integer;
    begin
        for p in 0 to 3 loop
            for i in 0 to 255 loop
                m := fn_smooth_idx(i);
                r(p*256+i) := std_logic_vector(to_unsigned(fn_v(p,m),8));
            end loop;
        end loop;
        return r;
    end function;

    signal s_pal_y : t_pal := fn_init_y;
    signal s_pal_u : t_pal := fn_init_u;
    signal s_pal_v : t_pal := fn_init_v;

    -- Palette BRAM read control + registered outputs
    signal s_pal_addr : unsigned(9 downto 0) := (others => '0');
    signal s_pray     : unsigned(7 downto 0) := (others => '0');
    signal s_prau     : unsigned(7 downto 0) := to_unsigned(128, 8);
    signal s_prav     : unsigned(7 downto 0) := to_unsigned(128, 8);

    -- ========================================================================
    -- Hash function: 3-step XOR-fold (no multipliers, good avalanche)
    -- ========================================================================
    function perlin_hash(x : unsigned(7 downto 0);
                         y : unsigned(7 downto 0)) return unsigned is
        variable h : unsigned(7 downto 0);
    begin
        h := x xor (y(4 downto 0) & y(7 downto 5));   -- XOR x with y rot-right-3
        h := h xor (h(5 downto 0) & h(7 downto 6));   -- self-mix rot-right-2
        h := h xor to_unsigned(107, 8);                -- prime constant
        h := h xor (h(1 downto 0) & h(7 downto 2));   -- final fold rot-right-6
        return h;
    end function;

    -- ========================================================================
    -- 8-direction gradient dot product (shift/add only, no multipliers)
    -- fx, fy: unsigned 7-bit fractional distance from the corner [0..127]
    -- Pass NOT(frac) for the "far edge" corners (10, 01, 11).
    -- Returns signed 8-bit; axis-aligned range ±127, diagonal range ±63.
    -- ========================================================================
    function grad_dot8(grad : unsigned(2 downto 0);
                       fx   : unsigned(6 downto 0);
                       fy   : unsigned(6 downto 0)) return signed is
        variable px : signed(8 downto 0) := signed(resize(fx, 9));
        variable py : signed(8 downto 0) := signed(resize(fy, 9));
        variable nx : signed(8 downto 0);
        variable ny : signed(8 downto 0);
    begin
        nx := -px;
        ny := -py;
        case grad is
            when "000" => return resize(px, 8);                        -- E
            when "001" => return resize(shift_right(px+py, 1), 8);   -- NE
            when "010" => return resize(py, 8);                        -- N
            when "011" => return resize(shift_right(nx+py, 1), 8);   -- NW
            when "100" => return resize(nx, 8);                        -- W
            when "101" => return resize(shift_right(nx+ny, 1), 8);   -- SW
            when "110" => return resize(ny, 8);                        -- S
            when others => return resize(shift_right(px+ny, 1), 8);  -- SE
        end case;
    end function;

    -- ========================================================================
    -- Pipeline stage signals  (S1 … S16)
    -- ========================================================================

    -- S1: warped pixel coordinates
    signal s1_px   : unsigned(10 downto 0) := (others => '0');
    signal s1_py   : unsigned(10 downto 0) := (others => '0');

    -- S2: 23-bit scaled coordinates
    signal s2_pxs  : unsigned(21 downto 0) := (others => '0');
    signal s2_pys  : unsigned(21 downto 0) := (others => '0');

    -- S3: cell/frac + hashes for 4 oct1 corners and 4 oct2 corners
    signal s3_fx   : unsigned(6 downto 0) := (others => '0');
    signal s3_fy   : unsigned(6 downto 0) := (others => '0');
    signal s3_h00  : unsigned(7 downto 0) := (others => '0');
    signal s3_h10  : unsigned(7 downto 0) := (others => '0');
    signal s3_h01  : unsigned(7 downto 0) := (others => '0');
    signal s3_h11  : unsigned(7 downto 0) := (others => '0');
    signal s3_v00  : unsigned(7 downto 0) := (others => '0');  -- oct2
    signal s3_v10  : unsigned(7 downto 0) := (others => '0');
    signal s3_v01  : unsigned(7 downto 0) := (others => '0');
    signal s3_v11  : unsigned(7 downto 0) := (others => '0');

    -- S4: smoothstep squarers + delayed hash/frac
    signal s4_sqx  : unsigned(9 downto 0) := (others => '0');
    signal s4_sqy  : unsigned(9 downto 0) := (others => '0');
    signal s4_fx   : unsigned(6 downto 0) := (others => '0');
    signal s4_fy   : unsigned(6 downto 0) := (others => '0');
    signal s4_h00  : unsigned(7 downto 0) := (others => '0');
    signal s4_h10  : unsigned(7 downto 0) := (others => '0');
    signal s4_h01  : unsigned(7 downto 0) := (others => '0');
    signal s4_h11  : unsigned(7 downto 0) := (others => '0');
    signal s4_v00  : unsigned(7 downto 0) := (others => '0');
    signal s4_v10  : unsigned(7 downto 0) := (others => '0');
    signal s4_v01  : unsigned(7 downto 0) := (others => '0');
    signal s4_v11  : unsigned(7 downto 0) := (others => '0');

    -- S5: smoothstep factor + delayed
    signal s5_facx : unsigned(9 downto 0) := to_unsigned(384, 10);
    signal s5_facy : unsigned(9 downto 0) := to_unsigned(384, 10);
    signal s5_sqx  : unsigned(9 downto 0) := (others => '0');
    signal s5_sqy  : unsigned(9 downto 0) := (others => '0');
    signal s5_fx   : unsigned(6 downto 0) := (others => '0');
    signal s5_fy   : unsigned(6 downto 0) := (others => '0');
    signal s5_h00  : unsigned(7 downto 0) := (others => '0');
    signal s5_h10  : unsigned(7 downto 0) := (others => '0');
    signal s5_h01  : unsigned(7 downto 0) := (others => '0');
    signal s5_h11  : unsigned(7 downto 0) := (others => '0');
    signal s5_v00  : unsigned(7 downto 0) := (others => '0');
    signal s5_v10  : unsigned(7 downto 0) := (others => '0');
    signal s5_v01  : unsigned(7 downto 0) := (others => '0');
    signal s5_v11  : unsigned(7 downto 0) := (others => '0');

    -- S6: smoothstep output (sx,sy) + oct1 dot products + oct2 value signals
    signal s6_sx   : unsigned(6 downto 0) := (others => '0');
    signal s6_sy   : unsigned(6 downto 0) := (others => '0');
    signal s6_d00  : signed(7 downto 0) := (others => '0');
    signal s6_d10  : signed(7 downto 0) := (others => '0');
    signal s6_d01  : signed(7 downto 0) := (others => '0');
    signal s6_d11  : signed(7 downto 0) := (others => '0');
    signal s6_n00  : signed(7 downto 0) := (others => '0');  -- oct2 value noise
    signal s6_n10  : signed(7 downto 0) := (others => '0');
    signal s6_n01  : signed(7 downto 0) := (others => '0');
    signal s6_n11  : signed(7 downto 0) := (others => '0');

    -- S7: registered sx/sy + dots/values
    signal s7_sx   : unsigned(6 downto 0) := (others => '0');
    signal s7_sy   : unsigned(6 downto 0) := (others => '0');
    signal s7_d00  : signed(7 downto 0) := (others => '0');
    signal s7_d10  : signed(7 downto 0) := (others => '0');
    signal s7_d01  : signed(7 downto 0) := (others => '0');
    signal s7_d11  : signed(7 downto 0) := (others => '0');
    signal s7_n00  : signed(7 downto 0) := (others => '0');
    signal s7_n10  : signed(7 downto 0) := (others => '0');
    signal s7_n01  : signed(7 downto 0) := (others => '0');
    signal s7_n11  : signed(7 downto 0) := (others => '0');

    -- S8: horizontal lerp diffs
    signal s8_dt1  : signed(8 downto 0) := (others => '0');
    signal s8_db1  : signed(8 downto 0) := (others => '0');
    signal s8_at1  : signed(7 downto 0) := (others => '0');
    signal s8_ab1  : signed(7 downto 0) := (others => '0');
    signal s8_dt2  : signed(8 downto 0) := (others => '0');
    signal s8_db2  : signed(8 downto 0) := (others => '0');
    signal s8_at2  : signed(7 downto 0) := (others => '0');
    signal s8_ab2  : signed(7 downto 0) := (others => '0');
    signal s8_sx   : unsigned(6 downto 0) := (others => '0');
    signal s8_sy   : unsigned(6 downto 0) := (others => '0');

    -- S9: horizontal lerp products
    signal s9_pt1  : signed(16 downto 0) := (others => '0');
    signal s9_pb1  : signed(16 downto 0) := (others => '0');
    signal s9_at1  : signed(7 downto 0) := (others => '0');
    signal s9_ab1  : signed(7 downto 0) := (others => '0');
    signal s9_pt2  : signed(16 downto 0) := (others => '0');
    signal s9_pb2  : signed(16 downto 0) := (others => '0');
    signal s9_at2  : signed(7 downto 0) := (others => '0');
    signal s9_ab2  : signed(7 downto 0) := (others => '0');
    signal s9_sy   : unsigned(6 downto 0) := (others => '0');

    -- S10: horizontal lerp sums
    signal s10_lt1 : signed(7 downto 0) := (others => '0');
    signal s10_lb1 : signed(7 downto 0) := (others => '0');
    signal s10_lt2 : signed(7 downto 0) := (others => '0');
    signal s10_lb2 : signed(7 downto 0) := (others => '0');
    signal s10_sy  : unsigned(6 downto 0) := (others => '0');

    -- S11: vertical lerp diffs + base
    signal s11_vd1 : signed(8 downto 0) := (others => '0');
    signal s11_av1 : signed(7 downto 0) := (others => '0');
    signal s11_vd2 : signed(8 downto 0) := (others => '0');
    signal s11_av2 : signed(7 downto 0) := (others => '0');
    signal s11_sy  : unsigned(6 downto 0) := (others => '0');

    -- S12: vertical lerp products + base delay
    signal s12_vp1 : signed(16 downto 0) := (others => '0');
    signal s12_av1 : signed(7 downto 0) := (others => '0');
    signal s12_vp2 : signed(16 downto 0) := (others => '0');
    signal s12_av2 : signed(7 downto 0) := (others => '0');

    -- S13: noise per octave
    signal s13_n1  : signed(8 downto 0) := (others => '0');
    signal s13_n2  : signed(8 downto 0) := (others => '0');

    -- S14: blended noise + palette address
    signal s14_noise : signed(8 downto 0) := (others => '0');
    signal s14_vidmul : std_logic := '0';

    -- S15: palette YUV 10-bit + propagated control
    signal s15_y   : unsigned(9 downto 0) := (others => '0');
    signal s15_u   : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal s15_v   : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal s15_vidmul : std_logic := '0';

    -- S16: output pixel
    signal s16_y   : unsigned(9 downto 0) := (others => '0');
    signal s16_u   : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal s16_v   : unsigned(9 downto 0) := to_unsigned(512, 10);

    -- video_mul delayed through 13 main-pipeline stages (S1→S14 = 13 steps)
    type t_vmd is array(0 to 12) of std_logic;
    signal s_vmd : t_vmd := (others => '0');

    -- Mix pipeline (S17..S19)
    signal smA_dy  : signed(10 downto 0) := (others => '0');
    signal smA_du  : signed(10 downto 0) := (others => '0');
    signal smA_dv  : signed(10 downto 0) := (others => '0');
    signal smA_dry : unsigned(9 downto 0) := (others => '0');
    signal smA_dru : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal smA_drv : unsigned(9 downto 0) := to_unsigned(512, 10);

    signal smB_py  : signed(19 downto 0) := (others => '0');
    signal smB_pu  : signed(19 downto 0) := (others => '0');
    signal smB_pv  : signed(19 downto 0) := (others => '0');
    signal smB_dry : unsigned(9 downto 0) := (others => '0');
    signal smB_dru : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal smB_drv : unsigned(9 downto 0) := to_unsigned(512, 10);

    signal smC_y   : unsigned(9 downto 0) := (others => '0');
    signal smC_u   : unsigned(9 downto 0) := to_unsigned(512, 10);
    signal smC_v   : unsigned(9 downto 0) := to_unsigned(512, 10);

    -- Dry data tap + sync delay
    signal s_dry_y : std_logic_vector(9 downto 0);
    signal s_dry_u : std_logic_vector(9 downto 0);
    signal s_dry_v : std_logic_vector(9 downto 0);
    signal s_avid_d    : std_logic;
    signal s_hsync_n_d : std_logic;
    signal s_vsync_n_d : std_logic;
    signal s_field_n_d : std_logic;

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_scroll_x   <= unsigned(registers_in(0));
    s_scale      <= unsigned(registers_in(1));
    s_scroll_y   <= unsigned(registers_in(2));
    s_warp_amt   <= unsigned(registers_in(3));
    s_pal_shift  <= unsigned(registers_in(4));
    s_pal_speed  <= unsigned(registers_in(5));
    s_ridge_mode <= registers_in(6)(0);
    s_pal_bank   <= registers_in(6)(1);
    s_pal_color  <= registers_in(6)(2);
    s_video_mul  <= registers_in(6)(3);
    s_octave_en  <= registers_in(6)(4);
    s_mix_amt    <= unsigned(registers_in(7));

    -- ========================================================================
    -- Video Timing Generator
    -- ========================================================================
    timing_gen_inst : entity work.video_timing_generator
        port map(
            clk         => clk,
            ref_hsync_n => data_in.hsync_n,
            ref_vsync_n => data_in.vsync_n,
            ref_avid    => data_in.avid,
            timing      => s_timing
        );

    -- ========================================================================
    -- Pixel Counters
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if s_timing.avid = '1' then
                s_hcount <= s_hcount + 1;
            end if;
            if s_timing.hsync_start = '1' then
                s_hcount <= (others => '0');
                s_vcount <= s_vcount + 1;
            end if;
            if s_timing.vsync_start = '1' then
                s_vcount <= (others => '0');
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Vsync: Parameter Capture + Scroll DDS Update
    -- ========================================================================
    process(clk)
        variable v_sxi : signed(10 downto 0);
        variable v_syi : signed(10 downto 0);
    begin
        if rising_edge(clk) then
            if s_timing.vsync_start = '1' then
                -- Scale multiplier: 8 discrete steps [0..1023] → lattice mult ~8..72
                s_scale_mul   <= to_unsigned(8,11) + resize(shift_right(resize(s_scale,11),1),11);

                s_warp_gain   <= s_warp_amt;
                s_pal_bank_r  <= s_pal_bank;
                s_pal_color_r <= s_pal_color;
                s_video_mul_r <= s_video_mul;
                s_octave_r    <= s_octave_en;
                s_ridge_r     <= s_ridge_mode;

                -- Bidirectional scroll DDS (512 = stopped, 0 = backward, 1023 = forward)
                v_sxi := signed('0' & s_scroll_x) - to_signed(512, 11);
                v_syi := signed('0' & s_scroll_y) - to_signed(512, 11);
                s_x_offset <= unsigned(signed(s_x_offset) +
                              resize(shift_right(v_sxi, 3), 16));
                s_y_offset <= unsigned(signed(s_y_offset) +
                              resize(shift_right(v_syi, 3), 16));

                -- Palette animation DDS
                s_pal_offset <= s_pal_offset +
                                resize(s_pal_speed(9 downto 2), 10);
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Warp BRAM Pre-read (1-cycle latency; result s_warp_rd used in S1)
    -- Reads the noise stored by the previous line at this column position.
    -- A second register stage (s_warp_rd2) breaks the BRAM→multiply critical path.
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_warp_rd  <= s_warp_bram(to_integer(s_hcount(9 downto 2)));
            s_warp_rd2 <= s_warp_rd;   -- break BRAM→multiply path
        end if;
    end process;

    -- ========================================================================
    -- Palette BRAM Read (address set at S14 via s_pal_addr;
    -- registered outputs s_pray/prau/prav available the next cycle = S15)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_pray <= unsigned(s_pal_y(to_integer(s_pal_addr)));
            s_prau <= unsigned(s_pal_u(to_integer(s_pal_addr)));
            s_prav <= unsigned(s_pal_v(to_integer(s_pal_addr)));
        end if;
    end process;

    -- ========================================================================
    -- Warp BRAM Write (S14's s14_noise → stored at delayed hcount for next line)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_warp_bram(to_integer(s_hc14(15))) <= s14_noise(7 downto 0);
        end if;
    end process;

    -- ========================================================================
    -- Main Processing Pipeline  S1 … S16
    -- ========================================================================
    process(clk)
        variable v_px       : unsigned(10 downto 0);
        variable v_py       : unsigned(10 downto 0);
        variable v_vy       : signed(11 downto 0);
        variable v_warp     : signed(11 downto 0);
        variable v_pxs      : unsigned(21 downto 0);
        variable v_pys      : unsigned(21 downto 0);
        variable v_cx       : unsigned(7 downto 0);
        variable v_cy       : unsigned(7 downto 0);
        variable v_fx       : unsigned(6 downto 0);
        variable v_fy       : unsigned(6 downto 0);
        variable v_cx2      : unsigned(7 downto 0);
        variable v_cy2      : unsigned(7 downto 0);
        variable v_sqx      : unsigned(13 downto 0);
        variable v_sqy      : unsigned(13 downto 0);
        variable v_facx     : unsigned(9 downto 0);
        variable v_facy     : unsigned(9 downto 0);
        variable v_spx      : unsigned(19 downto 0);
        variable v_spy      : unsigned(19 downto 0);
        variable v_blend    : signed(18 downto 0);
        variable v_noise    : signed(8 downto 0);
        variable v_nabs     : unsigned(8 downto 0);
        variable v_pidx     : unsigned(9 downto 0);
        variable v_psel     : unsigned(1 downto 0);
        variable v_lc       : signed(11 downto 0);
        variable v_lout     : signed(11 downto 0);
        variable v_wet_y    : unsigned(9 downto 0);
        variable v_vmul     : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then

            -- ==============================================================
            -- Pipeline: hcount[7:0] delayed 14 stages for warp-BRAM write
            -- ==============================================================
            s_hc14(0) <= s_hcount(9 downto 2);
            for i in 1 to 15 loop
                s_hc14(i) <= s_hc14(i-1);
            end loop;

            -- ==============================================================
            -- Pipeline: video_mul control bit through 13 stages S1→S14
            -- ==============================================================
            s_vmd(0) <= s_video_mul_r;
            for i in 1 to 12 loop
                s_vmd(i) <= s_vmd(i-1);
            end loop;

            -- ==============================================================
            -- S1: Apply scroll offsets and per-column domain warp
            -- s_warp_rd = noise value stored by PREVIOUS line at this column.
            -- Warp scaled by s_warp_gain >> 4 to keep perturbation gentle.
            -- ==============================================================
            v_warp := resize(
                shift_right(s_warp_rd2 * signed(resize(s_warp_gain(9 downto 4), 8)), 6),
                12);

            v_px := s_hcount(10 downto 0) + s_x_offset(15 downto 5);
            v_vy := signed(resize(s_vcount(10 downto 0) + s_y_offset(15 downto 5), 12)) + v_warp;
            v_py := unsigned(v_vy(10 downto 0));

            s1_px <= v_px;
            s1_py <= v_py;

            -- ==============================================================
            -- S2: Coordinate scale multiply (shared; oct2 uses upper bit-slice)
            -- s_scale_mul range [8..524] → cells of 1..64 pixels wide at HD.
            -- ==============================================================
            v_pxs := s1_px * s_scale_mul;
            v_pys := s1_py * s_scale_mul;

            s2_pxs <= v_pxs;
            s2_pys <= v_pys;

            -- ==============================================================
            -- S3: Cell extraction (bit-slice), frac, + 8-corner hashes.
            -- Oct1: cell = bits[21:14], frac = bits[13:7]
            -- Oct2: cell = bits[20:13], frac = bits[12:6]  (2x freq, same multiply)
            -- ==============================================================
            v_cx  := s2_pxs(20 downto 13);
            v_cy  := s2_pys(20 downto 13);
            v_fx  := s2_pxs(12 downto 6);
            v_fy  := s2_pys(12 downto 6);
            v_cx2 := s2_pxs(19 downto 12);
            v_cy2 := s2_pys(19 downto 12);

            s3_fx  <= v_fx;
            s3_fy  <= v_fy;

            -- Oct1 hashes
            s3_h00 <= perlin_hash(v_cx,     v_cy);
            s3_h10 <= perlin_hash(v_cx+1,   v_cy);
            s3_h01 <= perlin_hash(v_cx,     v_cy+1);
            s3_h11 <= perlin_hash(v_cx+1,   v_cy+1);

            -- Oct2 hashes (used as signed value noise, not gradient)
            s3_v00 <= perlin_hash(v_cx2,    v_cy2);
            s3_v10 <= perlin_hash(v_cx2+1,  v_cy2);
            s3_v01 <= perlin_hash(v_cx2,    v_cy2+1);
            s3_v11 <= perlin_hash(v_cx2+1,  v_cy2+1);

            -- ==============================================================
            -- S4: Cubic smoothstep stage-1: squarers  (7x7 → 14 bit)
            -- ==============================================================
            v_sqx := s3_fx * s3_fx;
            v_sqy := s3_fy * s3_fy;

            s4_sqx <= v_sqx(13 downto 4);
            s4_sqy <= v_sqy(13 downto 4);
            s4_fx  <= s3_fx;  s4_fy  <= s3_fy;
            s4_h00 <= s3_h00; s4_h10 <= s3_h10;
            s4_h01 <= s3_h01; s4_h11 <= s3_h11;
            s4_v00 <= s3_v00; s4_v10 <= s3_v10;
            s4_v01 <= s3_v01; s4_v11 <= s3_v11;

            -- ==============================================================
            -- S5: Cubic smoothstep stage-2: factor = 384 - 2t
            -- f(t) = t^2*(384-2t) >> 14  implements  3t^2 - 2t^3 scaled
            -- ==============================================================
            v_facx := to_unsigned(384,10) -
                      resize(shift_left(resize(s4_fx,10),1), 10);
            v_facy := to_unsigned(384,10) -
                      resize(shift_left(resize(s4_fy,10),1), 10);

            s5_facx <= v_facx;  s5_facy <= v_facy;
            s5_sqx  <= s4_sqx;  s5_sqy  <= s4_sqy;
            s5_fx   <= s4_fx;   s5_fy   <= s4_fy;
            s5_h00  <= s4_h00;  s5_h10  <= s4_h10;
            s5_h01  <= s4_h01;  s5_h11  <= s4_h11;
            s5_v00  <= s4_v00;  s5_v10  <= s4_v10;
            s5_v01  <= s4_v01;  s5_v11  <= s4_v11;

            -- ==============================================================
            -- S6: Cubic smoothstep stage-3: product >> 14 → sx, sy [0..127]
            -- Also compute oct1 gradient dot-products (shift/add only).
            -- And oct2 value-noise: map hash byte to signed [-64..63].
            -- ==============================================================
            v_spx := s5_sqx * s5_facx;
            v_spy := s5_sqy * s5_facy;

            s6_sx <= v_spx(16 downto 10);
            s6_sy <= v_spy(16 downto 10);

            -- Oct1 gradient dot products (8 directions)
            s6_d00 <= grad_dot8(s5_h00(2 downto 0), s5_fx,      s5_fy);
            s6_d10 <= grad_dot8(s5_h10(2 downto 0), not s5_fx,  s5_fy);
            s6_d01 <= grad_dot8(s5_h01(2 downto 0), s5_fx,      not s5_fy);
            s6_d11 <= grad_dot8(s5_h11(2 downto 0), not s5_fx,  not s5_fy);

            -- Oct2 value noise: hash upper 7 bits, centered to [-64..63]
            s6_n00 <= signed(s5_v00(7 downto 1)) - to_signed(64, 8);
            s6_n10 <= signed(s5_v10(7 downto 1)) - to_signed(64, 8);
            s6_n01 <= signed(s5_v01(7 downto 1)) - to_signed(64, 8);
            s6_n11 <= signed(s5_v11(7 downto 1)) - to_signed(64, 8);

            -- ==============================================================
            -- S7: Register sx/sy + all dots/values
            -- ==============================================================
            s7_sx  <= s6_sx;   s7_sy  <= s6_sy;
            s7_d00 <= s6_d00;  s7_d10 <= s6_d10;
            s7_d01 <= s6_d01;  s7_d11 <= s6_d11;
            s7_n00 <= s6_n00;  s7_n10 <= s6_n10;
            s7_n01 <= s6_n01;  s7_n11 <= s6_n11;

            -- ==============================================================
            -- S8: Horizontal lerp differences
            -- ==============================================================
            s8_dt1 <= resize(s7_d10,9) - resize(s7_d00,9);
            s8_db1 <= resize(s7_d11,9) - resize(s7_d01,9);
            s8_at1 <= s7_d00;  s8_ab1 <= s7_d01;
            s8_dt2 <= resize(s7_n10,9) - resize(s7_n00,9);
            s8_db2 <= resize(s7_n11,9) - resize(s7_n01,9);
            s8_at2 <= s7_n00;  s8_ab2 <= s7_n01;
            s8_sx  <= s7_sx;   s8_sy  <= s7_sy;

            -- ==============================================================
            -- S9: Horizontal lerp products  (9b × 7b = 16b)
            -- ==============================================================
            s9_pt1 <= s8_dt1 * signed(resize(s8_sx, 8));
            s9_pb1 <= s8_db1 * signed(resize(s8_sx, 8));
            s9_at1 <= s8_at1;  s9_ab1 <= s8_ab1;
            s9_pt2 <= s8_dt2 * signed(resize(s8_sx, 8));
            s9_pb2 <= s8_db2 * signed(resize(s8_sx, 8));
            s9_at2 <= s8_at2;  s9_ab2 <= s8_ab2;
            s9_sy  <= s8_sy;

            -- ==============================================================
            -- S10: Horizontal lerp sums: lerp = a + (diff * sx) >> 7
            -- ==============================================================
            s10_lt1 <= s9_at1 + s9_pt1(13 downto 7);
            s10_lb1 <= s9_ab1 + s9_pb1(13 downto 7);
            s10_lt2 <= s9_at2 + s9_pt2(13 downto 7);
            s10_lb2 <= s9_ab2 + s9_pb2(13 downto 7);
            s10_sy  <= s9_sy;

            -- ==============================================================
            -- S11: Vertical lerp differences
            -- ==============================================================
            s11_vd1 <= resize(s10_lb1,9) - resize(s10_lt1,9);
            s11_av1 <= s10_lt1;
            s11_vd2 <= resize(s10_lb2,9) - resize(s10_lt2,9);
            s11_av2 <= s10_lt2;
            s11_sy  <= s10_sy;

            -- ==============================================================
            -- S12: Vertical lerp products  (9b × 7b = 16b)
            -- ==============================================================
            s12_vp1 <= s11_vd1 * signed(resize(s11_sy, 8));
            s12_av1 <= s11_av1;
            s12_vp2 <= s11_vd2 * signed(resize(s11_sy, 8));
            s12_av2 <= s11_av2;

            -- ==============================================================
            -- S13: Vertical lerp sums → noise1 (oct1), noise2 (oct2)
            -- ==============================================================
            s13_n1 <= resize(s12_av1,9) + resize(s12_vp1(13 downto 7),9);
            s13_n2 <= resize(s12_av2,9) + resize(s12_vp2(13 downto 7),9);

            -- ==============================================================
            -- S14: Octave blend + ridge mode + palette address computation.
            -- Also: write warp BRAM and propagate video_mul.
            -- ==============================================================
            -- Octave blend (if octave_en = 1': 50/50 fBm sum; else oct1 only)
            if s_octave_r = '1' then
                v_blend  := resize(s13_n1,19) + resize(s13_n2,19);
                v_noise  := resize(shift_right(v_blend,1),9);
            else
                v_noise  := s13_n1;
            end if;
            s14_noise <= v_noise;

            -- Ridge: absolute-value fold
            if v_noise < 0 then
                v_nabs := unsigned(-v_noise);
            else
                v_nabs := unsigned(v_noise);
            end if;

            -- Palette index computation (wraps mod 256 naturally via 8-bit slice)
            if s_ridge_r = '1' then
                v_pidx := resize(v_nabs, 10) +
                          s_pal_shift(9 downto 2) + s_pal_offset;
            else
                -- signed noise → unsigned [0..255]: add 128 (centre at mid-palette)
                v_pidx := unsigned(resize(v_noise + 128, 10)) +
                          s_pal_shift(9 downto 2) + s_pal_offset;
            end if;

            v_psel := s_pal_bank_r & s_pal_color_r;
            s_pal_addr <= v_psel & v_pidx(7 downto 0);

            s14_vidmul <= s_vmd(12);

            -- ==============================================================
            -- S15: Expand 8-bit palette to 10-bit (shift-left 2).
            -- s_pray/prau/prav are BRAM registered outputs from the read
            -- initiated at S14 (s_pal_addr set above).
            -- ==============================================================
            s15_y      <= shift_left(resize(s_pray, 10), 2);
            s15_u      <= shift_left(resize(s_prau, 10), 2);
            s15_v      <= shift_left(resize(s_prav, 10), 2);
            s15_vidmul <= s14_vidmul;

            -- ==============================================================
            -- S16: Gentle contrast + video-multiply + output
            -- contrast_k ~ 1.125x (subtle punch, avoids hard clipping)
            -- luma_out = ((luma - 512) * 1.125) + 512
            -- ==============================================================
            v_lc    := signed(resize(s15_y, 12)) - to_signed(512,12);
            v_lout  := v_lc + shift_right(v_lc, 3) +
                       to_signed(512,12);

            if v_lout < 0 then
                v_wet_y := (others => '0');
            elsif v_lout > 1023 then
                v_wet_y := to_unsigned(1023, 10);
            else
                v_wet_y := unsigned(v_lout(9 downto 0));
            end if;
            s16_y <= v_wet_y;
            s16_u <= s15_u;
            s16_v <= s15_v;

            -- Video multiply: gate with input luma
            if s15_vidmul = '1' then
                v_vmul := v_wet_y(9 downto 2) *
                          unsigned(data_in.y(9 downto 2));
                s16_y <= v_vmul(15 downto 6);
                s16_u <= unsigned(data_in.u);
                s16_v <= unsigned(data_in.v);
            end if;

        end if;
    end process;

    -- ========================================================================
    -- Mix Stage A  (S17): diff = wet - dry
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            smA_dy  <= signed(resize(s16_y, 11)) - signed(resize(unsigned(s_dry_y), 11));
            smA_du  <= signed(resize(s16_u, 11)) - signed(resize(unsigned(s_dry_u), 11));
            smA_dv  <= signed(resize(s16_v, 11)) - signed(resize(unsigned(s_dry_v), 11));
            smA_dry <= unsigned(s_dry_y);
            smA_dru <= unsigned(s_dry_u);
            smA_drv <= unsigned(s_dry_v);
        end if;
    end process;

    -- ========================================================================
    -- Mix Stage B  (S18): product = diff * mix_amount[9:2]
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            smB_py  <= smA_dy * signed(resize(s_mix_amt(9 downto 2), 9));
            smB_pu  <= smA_du * signed(resize(s_mix_amt(9 downto 2), 9));
            smB_pv  <= smA_dv * signed(resize(s_mix_amt(9 downto 2), 9));
            smB_dry <= smA_dry;
            smB_dru <= smA_dru;
            smB_drv <= smA_drv;
        end if;
    end process;

    -- ========================================================================
    -- Mix Stage C  (S19): result = dry + product >> 8, clamped
    -- ========================================================================
    process(clk)
        variable v_y : signed(10 downto 0);
        variable v_u : signed(10 downto 0);
        variable v_v : signed(10 downto 0);
    begin
        if rising_edge(clk) then
            v_y := signed(resize(smB_dry, 11)) + resize(smB_py(17 downto 8), 11);
            v_u := signed(resize(smB_dru, 11)) + resize(smB_pu(17 downto 8), 11);
            v_v := signed(resize(smB_drv, 11)) + resize(smB_pv(17 downto 8), 11);

            if v_y < 0 then smC_y <= (others=>'0');
            elsif v_y > 1023 then smC_y <= to_unsigned(1023,10);
            else smC_y <= unsigned(v_y(9 downto 0)); end if;

            if v_u < 0 then smC_u <= (others=>'0');
            elsif v_u > 1023 then smC_u <= to_unsigned(1023,10);
            else smC_u <= unsigned(v_u(9 downto 0)); end if;

            if v_v < 0 then smC_v <= (others=>'0');
            elsif v_v > 1023 then smC_v <= to_unsigned(1023,10);
            else smC_v <= unsigned(v_v(9 downto 0)); end if;
        end if;
    end process;

    -- ========================================================================
    -- Sync and Data Delay Pipeline
    -- ========================================================================
    process(clk)
        type t_sdly is array(0 to C_PROCESSING_DELAY_CLKS-1) of std_logic;
        type t_ddly is array(0 to C_PROCESSING_DELAY_CLKS-1)
            of std_logic_vector(C_VIDEO_DATA_WIDTH-1 downto 0);

        variable v_avid : t_sdly := (others=>'0');
        variable v_hs   : t_sdly := (others=>'1');
        variable v_vs   : t_sdly := (others=>'1');
        variable v_fd   : t_sdly := (others=>'1');
        variable v_yd   : t_ddly := (others=>(others=>'0'));
        variable v_ud   : t_ddly := (others=>(others=>'0'));
        variable v_vd   : t_ddly := (others=>(others=>'0'));
    begin
        if rising_edge(clk) then
            v_avid := data_in.avid    & v_avid(0 to C_PROCESSING_DELAY_CLKS-2);
            v_hs   := data_in.hsync_n & v_hs(0   to C_PROCESSING_DELAY_CLKS-2);
            v_vs   := data_in.vsync_n & v_vs(0   to C_PROCESSING_DELAY_CLKS-2);
            v_fd   := data_in.field_n & v_fd(0   to C_PROCESSING_DELAY_CLKS-2);
            v_yd   := data_in.y       & v_yd(0   to C_PROCESSING_DELAY_CLKS-2);
            v_ud   := data_in.u       & v_ud(0   to C_PROCESSING_DELAY_CLKS-2);
            v_vd   := data_in.v       & v_vd(0   to C_PROCESSING_DELAY_CLKS-2);

            s_avid_d    <= v_avid(C_PROCESSING_DELAY_CLKS-1);
            s_hsync_n_d <= v_hs(C_PROCESSING_DELAY_CLKS-1);
            s_vsync_n_d <= v_vs(C_PROCESSING_DELAY_CLKS-1);
            s_field_n_d <= v_fd(C_PROCESSING_DELAY_CLKS-1);

            -- Dry tap aligned to mix stage-A (3 mix stages before final output)
            s_dry_y <= v_yd(C_PROCESSING_DELAY_CLKS-4);
            s_dry_u <= v_ud(C_PROCESSING_DELAY_CLKS-4);
            s_dry_v <= v_vd(C_PROCESSING_DELAY_CLKS-4);
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment
    -- ========================================================================
    -- Gate to studio blanking outside the delay-matched AVID.
    data_out.y      <= std_logic_vector(smC_y) when s_avid_d = '1'
                       else std_logic_vector(to_unsigned(64, smC_y'length));
    data_out.u      <= std_logic_vector(smC_u) when s_avid_d = '1'
                       else std_logic_vector(to_unsigned(512, smC_u'length));
    data_out.v      <= std_logic_vector(smC_v) when s_avid_d = '1'
                       else std_logic_vector(to_unsigned(512, smC_v'length));
    data_out.avid   <= s_avid_d;
    data_out.hsync_n <= s_hsync_n_d;
    data_out.vsync_n <= s_vsync_n_d;
    data_out.field_n <= s_field_n_d;

end architecture perlin;
