-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: stic.vhd - STIC Program for Videomancer
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
--   STIC
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Intellivision STIC (Standard Television Interface Chip) display
--   processor renderer.  Quantizes input video to the Intellivision's
--   fixed 16-colour palette via Manhattan distance matching in YUV
--   space, then applies the two distinctive STIC rendering modes:
--
--     Color Stack : Each tile gets a foreground colour (nearest palette
--                   match to input) and a background colour that cycles
--                   through a 4-entry rotating stack.  The stack hue is
--                   user-selectable and advances every N tiles (rate
--                   controlled by Pot 3).
--
--     Colored Squares : Each 8x8 tile is subdivided into four 4x4
--                       quadrant blocks.  Each block is independently
--                       quantized to the 7 STIC foreground colours.  The
--                       remaining area uses the Color Stack background.
--                       This replicates the ultra-blocky mosaic mode
--                       used in games like Snafu.
--
--   Additional features: tile boundary grid overlay, CRT scanline
--   dimming, simulated 20 Hz sprite flicker (characteristic of
--   Intellivision Exec framework games), and wet/dry mix.
--
--   Zero BRAM -- all processing is combinational + LUT ROM.
--
-- Resources:
--   0 BRAM
--   ~1000 LUTs (16-colour palette matching, tile grid, colour stack
--               logic, quadrant block decomposition, output mux)
--   3x interpolator_u (wet/dry mix per channel)
--
-- Pipeline:
--   1 clk : input register + timing detection + tile tracking
--   1 clk : foreground palette distances 0-3  (group A compute)
--   1 clk : foreground palette reduce A + distances 4-7 (group B compute)
--   1 clk : foreground palette reduce B + distances 8-11 (group C compute)
--   1 clk : foreground palette reduce C + distances 12-15 (group D compute)
--   1 clk : foreground palette reduce D → winner index
--   1 clk : palette ROM lookup + mode mux (Color Stack vs Colored Squares)
--   1 clk : brightness multiply + saturation offset
--   1 clk : saturation multiply + brightness truncate
--   1 clk : saturation clamp
--   1 clk : grid overlay + scanlines + flicker
--   1 clk : output register
--   4 clk : interpolator_u wet/dry mix
--   Total: 16 clocks
--
-- Parameters:
--   Pot 1  (registers_in(0))  : Tile Size    -- tile cell width in pixels
--   Pot 2  (registers_in(1))  : Stack Hue    -- base hue for Color Stack
--   Pot 3  (registers_in(2))  : Stack Rate   -- Color Stack advance speed
--   Pot 4  (registers_in(3))  : Saturation   -- chroma intensity
--   Pot 5  (registers_in(4))  : Threshold    -- foreground/background split
--   Pot 6  (registers_in(5))  : Brightness   -- output brightness
--   Tog 7  (registers_in(6)(0)) : Mode (0=Color Stack, 1=Colored Squares)
--   Tog 8  (registers_in(6)(1)) : Grid overlay enable
--   Tog 9  (registers_in(6)(2)) : Scanline dimming enable
--   Tog 10 (registers_in(6)(3)) : Sprite flicker enable (20 Hz simulation)
--   Tog 11 (registers_in(6)(4)) : Scan Str (heavy scanline dimming)
--   Fader  (registers_in(7))  : Mix          -- dry/wet crossfade
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture stic of program_top is

    -- Pipeline: 1+1+1+1+1+1+1+1+1+4 = 14 clocks
    --   Stage 1 : input register + timing + tile tracking
    --   Stage 2 : all 16 palette distances (parallel)
    --   Stage 3 : 16→4 reduction (four independent 4-way mins)
    --   Stage 4 : 4→1 final reduction → winner index
    --   Stage 5 : palette ROM lookup + mode mux
    --   Stage 6 : brightness multiply + saturation offset
    --   Stage 7 : sat U multiply + brightness truncate
    --   Stage 8 : sat V multiply + sat U clamp
    --   Stage 9 : sat V clamp + grid/scanline/flicker
    --   Stage 10: output register (implicit in s_proc)
    --   4 clk   : interpolator wet/dry mix
    -- Total data latency incl. the 4-clk mix interpolators (and %4
    -- padding): sync/AVID tap the full depth, dry data taps 4 short so
    -- data-through-mix and sync reach data_out co-timed (was 14 with
    -- sync tapped at the same depth as dry data - video trailed the
    -- program's own sync by the mix latency).
    constant C_MIX_LATENCY_CLKS : integer := 4;
    constant C_PROCESSING_DELAY_CLKS : integer := 20;
    constant C_DRY_TAP : integer := C_PROCESSING_DELAY_CLKS - C_MIX_LATENCY_CLKS;
    constant C_CHROMA_MID : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        to_unsigned(512, C_VIDEO_DATA_WIDTH);

    -- Manhattan distance: 6-bit truncated channels, max 63*3 = 189, needs 8 bits
    constant C_DIST_WIDTH : integer := 8;

    -- ========================================================================
    -- Intellivision 16-colour palette in YUV space (10-bit, mid=512 for UV)
    -- ========================================================================
    type t_palette_entry is record
        y : unsigned(9 downto 0);
        u : unsigned(9 downto 0);
        v : unsigned(9 downto 0);
    end record;

    type t_palette is array(0 to 15) of t_palette_entry;

    constant C_INTV_PALETTE : t_palette := (
        (y => to_unsigned( 64, 10), u => to_unsigned(512, 10), v => to_unsigned(512, 10)),
        (y => to_unsigned(180, 10), u => to_unsigned(740, 10), v => to_unsigned(380, 10)),
        (y => to_unsigned(300, 10), u => to_unsigned(380, 10), v => to_unsigned(780, 10)),
        (y => to_unsigned(280, 10), u => to_unsigned(380, 10), v => to_unsigned(380, 10)),
        (y => to_unsigned(620, 10), u => to_unsigned(420, 10), v => to_unsigned(540, 10)),
        (y => to_unsigned(350, 10), u => to_unsigned(360, 10), v => to_unsigned(340, 10)),
        (y => to_unsigned(800, 10), u => to_unsigned(340, 10), v => to_unsigned(560, 10)),
        (y => to_unsigned(940, 10), u => to_unsigned(512, 10), v => to_unsigned(512, 10)),
        (y => to_unsigned(620, 10), u => to_unsigned(512, 10), v => to_unsigned(512, 10)),
        (y => to_unsigned(550, 10), u => to_unsigned(660, 10), v => to_unsigned(380, 10)),
        (y => to_unsigned(560, 10), u => to_unsigned(360, 10), v => to_unsigned(700, 10)),
        (y => to_unsigned(260, 10), u => to_unsigned(420, 10), v => to_unsigned(600, 10)),
        (y => to_unsigned(600, 10), u => to_unsigned(560, 10), v => to_unsigned(720, 10)),
        (y => to_unsigned(520, 10), u => to_unsigned(620, 10), v => to_unsigned(460, 10)),
        (y => to_unsigned(620, 10), u => to_unsigned(380, 10), v => to_unsigned(420, 10)),
        (y => to_unsigned(300, 10), u => to_unsigned(680, 10), v => to_unsigned(720, 10))
    );

    -- ========================================================================
    -- Manhattan distance helper (6-bit truncated for shorter carry chains)
    -- ========================================================================
    function f_manhattan_dist(
        pixel_y : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        pixel_u : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        pixel_v : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        pal_y   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        pal_u   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        pal_v   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0)
    ) return unsigned is
        variable v_py : unsigned(5 downto 0);
        variable v_pu : unsigned(5 downto 0);
        variable v_pv : unsigned(5 downto 0);
        variable v_cy : unsigned(5 downto 0);
        variable v_cu : unsigned(5 downto 0);
        variable v_cv : unsigned(5 downto 0);
        variable v_dy : unsigned(5 downto 0);
        variable v_du : unsigned(5 downto 0);
        variable v_dv : unsigned(5 downto 0);
    begin
        v_py := pixel_y(9 downto 4);
        v_pu := pixel_u(9 downto 4);
        v_pv := pixel_v(9 downto 4);
        v_cy := pal_y(9 downto 4);
        v_cu := pal_u(9 downto 4);
        v_cv := pal_v(9 downto 4);
        if v_py > v_cy then v_dy := v_py - v_cy;
        else                v_dy := v_cy - v_py;
        end if;
        if v_pu > v_cu then v_du := v_pu - v_cu;
        else                v_du := v_cu - v_pu;
        end if;
        if v_pv > v_cv then v_dv := v_pv - v_cv;
        else                v_dv := v_cv - v_pv;
        end if;
        return resize(v_dy, C_DIST_WIDTH) +
               resize(v_du, C_DIST_WIDTH) +
               resize(v_dv, C_DIST_WIDTH);
    end function;

    -- ========================================================================
    -- Parameter signals
    -- ========================================================================
    signal s_tile_size      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_hue      : unsigned(3 downto 0);
    signal s_stack_rate     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_saturation     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_threshold      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_brightness     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mode_sel       : std_logic;
    signal s_grid_en        : std_logic;
    signal s_scanlines_en   : std_logic;
    signal s_flicker_en     : std_logic;
    signal s_scan_str       : std_logic;
    signal s_mix_amount     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Timing detection
    -- ========================================================================
    signal s_prev_hsync_n   : std_logic := '1';
    signal s_prev_vsync_n   : std_logic := '1';
    signal s_hsync_fall     : std_logic;
    signal s_vsync_fall     : std_logic;
    signal s_x_counter      : unsigned(11 downto 0) := (others => '0');
    signal s_y_counter      : unsigned(11 downto 0) := (others => '0');

    -- ========================================================================
    -- Cell tracking
    -- ========================================================================
    signal s_local_x        : unsigned(5 downto 0) := (others => '0');
    signal s_local_y        : unsigned(5 downto 0) := (others => '0');
    signal s_held_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_held_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_held_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := to_unsigned(512, C_VIDEO_DATA_WIDTH);

    signal s_quad_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_quad_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_quad_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := to_unsigned(512, C_VIDEO_DATA_WIDTH);

    -- Color Stack state
    signal s_tile_counter   : unsigned(15 downto 0) := (others => '0');
    signal s_stack_phase    : unsigned(15 downto 0) := (others => '0');
    signal s_stack_idx      : unsigned(1 downto 0)  := (others => '0');
    signal s_stack_bg_y     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_u     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_v     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Sprite flicker
    signal s_frame_counter  : unsigned(1 downto 0) := (others => '0');
    signal s_flicker_dim    : std_logic := '0';

    -- ========================================================================
    -- Palette matching pipeline — flat parallel architecture
    -- ========================================================================
    type t_dist_array is array(0 to 15) of unsigned(C_DIST_WIDTH - 1 downto 0);

    -- Stage 2: all 16 distances computed in parallel
    signal s_dist           : t_dist_array;

    -- Stage 3: 16→4 group winners (four independent 4-way reductions)
    signal s_grp_min_a      : unsigned(C_DIST_WIDTH - 1 downto 0);
    signal s_grp_idx_a      : unsigned(3 downto 0);
    signal s_grp_min_b      : unsigned(C_DIST_WIDTH - 1 downto 0);
    signal s_grp_idx_b      : unsigned(3 downto 0);
    signal s_grp_min_c      : unsigned(C_DIST_WIDTH - 1 downto 0);
    signal s_grp_idx_c      : unsigned(3 downto 0);
    signal s_grp_min_d      : unsigned(C_DIST_WIDTH - 1 downto 0);
    signal s_grp_idx_d      : unsigned(3 downto 0);

    -- Stage 4: final winner
    signal s_match_idx      : unsigned(3 downto 0);

    -- Threshold pipeline (delay to align with palette result at Stage 5)
    signal s_is_fg_d1       : std_logic := '0';
    signal s_is_fg_d2       : std_logic := '0';
    signal s_is_fg_d3       : std_logic := '0';
    signal s_is_fg_d4       : std_logic := '0';

    -- Stack BG pipeline (4 stages: d1..d4 to align with Stage 5)
    signal s_stack_bg_y_d1  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_u_d1  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_v_d1  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_y_d2  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_u_d2  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_v_d2  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_y_d3  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_u_d3  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_v_d3  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_y_d4  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_u_d4  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_stack_bg_v_d4  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Mode pipeline (4 stages: d1..d4)
    signal s_mode_sel_d1    : std_logic;
    signal s_mode_sel_d2    : std_logic;
    signal s_mode_sel_d3    : std_logic;
    signal s_mode_sel_d4    : std_logic;

    -- Grid/scanline/flicker pipeline (d1..d8)
    signal s_grid_flag_d1   : std_logic := '0';
    signal s_grid_flag_d2   : std_logic := '0';
    signal s_grid_flag_d3   : std_logic := '0';
    signal s_grid_flag_d4   : std_logic := '0';
    signal s_grid_flag_d5   : std_logic := '0';
    signal s_grid_flag_d6   : std_logic := '0';
    signal s_grid_flag_d7   : std_logic := '0';
    signal s_grid_flag_d8   : std_logic := '0';
    signal s_scanline_d1    : std_logic := '0';
    signal s_scanline_d2    : std_logic := '0';
    signal s_scanline_d3    : std_logic := '0';
    signal s_scanline_d4    : std_logic := '0';
    signal s_scanline_d5    : std_logic := '0';
    signal s_scanline_d6    : std_logic := '0';
    signal s_scanline_d7    : std_logic := '0';
    signal s_scanline_d8    : std_logic := '0';
    signal s_flicker_d1     : std_logic := '0';
    signal s_flicker_d2     : std_logic := '0';
    signal s_flicker_d3     : std_logic := '0';
    signal s_flicker_d4     : std_logic := '0';
    signal s_flicker_d5     : std_logic := '0';
    signal s_flicker_d6     : std_logic := '0';
    signal s_flicker_d7     : std_logic := '0';
    signal s_flicker_d8     : std_logic := '0';

    -- Stage 5: palette lookup + mode mux results
    signal s_mux_y          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mux_u          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mux_v          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Stage 6: brightness multiply + saturation offset
    signal s_bri_product    : unsigned(2 * C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_sat_off_u      : signed(10 downto 0);
    signal s_sat_off_v      : signed(10 downto 0);

    -- Stage 7: sat U multiply + brightness truncate
    signal s_bri_y          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_sat_prod_u     : signed(21 downto 0);
    signal s_sat_off_v_d7   : signed(10 downto 0);

    -- Stage 8: sat V multiply + sat U clamp
    signal s_sat_prod_v     : signed(21 downto 0);
    signal s_out_y_d8       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_out_u_d8       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Processing output
    -- ========================================================================
    signal s_proc_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_proc_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_proc_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_proc_valid     : std_logic := '0';

    -- ========================================================================
    -- Mix stage
    -- ========================================================================
    signal s_mix_y_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_y_valid    : std_logic;
    signal s_mix_u_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_u_valid    : std_logic;
    signal s_mix_v_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_v_valid    : std_logic;

    -- ========================================================================
    -- Sync delay and bypass
    -- ========================================================================
    signal s_avid_d         : std_logic;
    signal s_hsync_n_d      : std_logic;
    signal s_vsync_n_d      : std_logic;
    signal s_field_n_d      : std_logic;
    signal s_y_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_tile_size     <= unsigned(registers_in(0));
    s_stack_hue     <= unsigned(registers_in(1)(9 downto 6));
    s_stack_rate    <= unsigned(registers_in(2));
    s_saturation    <= unsigned(registers_in(3));
    s_threshold     <= unsigned(registers_in(4));
    s_brightness    <= unsigned(registers_in(5));
    s_mode_sel      <= registers_in(6)(0);
    s_grid_en       <= registers_in(6)(1);
    s_scanlines_en  <= registers_in(6)(2);
    s_flicker_en    <= registers_in(6)(3);
    s_scan_str      <= registers_in(6)(4);
    s_mix_amount    <= unsigned(registers_in(7));

    -- ========================================================================
    -- Stage 1: Input Register + Timing Detection + Tile Tracking
    -- ========================================================================
    p_stage1_input : process(clk)
        variable v_cell_w       : unsigned(5 downto 0);
        variable v_half_cell    : unsigned(5 downto 0);
        variable v_is_fg        : std_logic;
        variable v_is_grid      : std_logic;
        variable v_stack_entry  : unsigned(3 downto 0);
    begin
        if rising_edge(clk) then
            -- Sync edge detection
            s_prev_hsync_n <= data_in.hsync_n;
            s_prev_vsync_n <= data_in.vsync_n;
            s_hsync_fall <= (not data_in.hsync_n) and s_prev_hsync_n;
            s_vsync_fall <= (not data_in.vsync_n) and s_prev_vsync_n;

            -- Cell width: map pot 0-1023 to 4-35 pixels
            v_cell_w := s_tile_size(9 downto 5) + "000100";
            v_half_cell := '0' & v_cell_w(5 downto 1);

            -- ================================================================
            -- Cell Tracking (same as nesppu pattern)
            -- ================================================================
            if s_vsync_fall = '1' then
                s_y_counter     <= (others => '0');
                s_local_y       <= (others => '0');
                s_tile_counter  <= (others => '0');
                s_stack_phase   <= (others => '0');
                s_frame_counter <= s_frame_counter + 1;
            elsif s_hsync_fall = '1' then
                s_y_counter <= s_y_counter + 1;
                s_x_counter <= (others => '0');
                s_local_x   <= (others => '0');
                if s_local_y >= v_cell_w then
                    s_local_y <= (others => '0');
                else
                    s_local_y <= s_local_y + 1;
                end if;
            else
                s_x_counter <= s_x_counter + 1;
                if s_local_x >= v_cell_w then
                    s_local_x <= (others => '0');
                    -- Sample pixel at tile boundary (whole-tile sample)
                    s_held_y <= unsigned(data_in.y);
                    s_held_u <= unsigned(data_in.u);
                    s_held_v <= unsigned(data_in.v);
                    -- Advance tile counter for Color Stack
                    s_tile_counter <= s_tile_counter + 1;
                else
                    s_local_x <= s_local_x + 1;
                end if;

                -- Quadrant sample: re-sample at each half-cell boundary
                if s_local_x = 0 or s_local_x = v_half_cell then
                    s_quad_y <= unsigned(data_in.y);
                    s_quad_u <= unsigned(data_in.u);
                    s_quad_v <= unsigned(data_in.v);
                end if;
            end if;

            -- ================================================================
            -- Color Stack Logic
            -- Advances through 4 background colours.  Stack rate controls
            -- how many tiles between advances.  At rate=0 the stack is
            -- static; at max it advances every tile.
            -- ================================================================
            -- Stack rate: s_stack_rate 0-1023 maps to advance period
            -- Lower rate = slower advance = more tiles per stack step
            if s_local_x = 0 and s_local_y = 0 then
                -- At tile origin, decide whether to advance stack
                s_stack_phase <= s_stack_phase + resize(s_stack_rate, 16);
                if s_stack_phase(15) = '1' or s_stack_rate > 900 then
                    s_stack_idx <= s_stack_idx + 1;
                    s_stack_phase <= (others => '0');
                end if;
            end if;

            -- Color Stack background: 4 palette entries offset from base hue
            -- Stack colours are spread equally around the palette
            -- (shift s_stack_idx left by 2 → offsets 0,4,8,12)
            v_stack_entry := s_stack_hue + (s_stack_idx & "00");
            s_stack_bg_y <= C_INTV_PALETTE(to_integer(v_stack_entry)).y;
            s_stack_bg_u <= C_INTV_PALETTE(to_integer(v_stack_entry)).u;
            s_stack_bg_v <= C_INTV_PALETTE(to_integer(v_stack_entry)).v;

            -- ================================================================
            -- Foreground/background decision based on luma threshold
            -- ================================================================
            if unsigned(data_in.y) > s_threshold then
                v_is_fg := '1';
            else
                v_is_fg := '0';
            end if;
            s_is_fg_d1 <= v_is_fg;

            -- Grid flag
            v_is_grid := '0';
            if s_grid_en = '1' then
                if s_local_x = 0 or s_local_y = 0 then
                    v_is_grid := '1';
                end if;
            end if;
            s_grid_flag_d1 <= v_is_grid;

            -- Scanline flag (dim every other line)
            if s_scanlines_en = '1' and s_y_counter(0) = '1' then
                s_scanline_d1 <= '1';
            else
                s_scanline_d1 <= '0';
            end if;

            -- Sprite flicker flag (dim 1 in 3 frames to simulate 20 Hz)
            if s_flicker_en = '1' and s_frame_counter = "10" then
                s_flicker_d1 <= '1';
            else
                s_flicker_d1 <= '0';
            end if;

            -- Mode delay
            s_mode_sel_d1 <= s_mode_sel;
        end if;
    end process;

    -- ========================================================================
    -- Stage 2: All 16 palette distances in parallel
    -- ========================================================================
    p_stage2_all_dist : process(clk)
        variable v_py : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_pu : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_pv : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            -- Select pixel source based on mode
            if s_mode_sel_d1 = '1' then
                v_py := s_quad_y;
                v_pu := s_quad_u;
                v_pv := s_quad_v;
            else
                v_py := s_held_y;
                v_pu := s_held_u;
                v_pv := s_held_v;
            end if;

            -- Compute all 16 distances in parallel
            for i in 0 to 15 loop
                s_dist(i) <= f_manhattan_dist(v_py, v_pu, v_pv,
                    C_INTV_PALETTE(i).y, C_INTV_PALETTE(i).u, C_INTV_PALETTE(i).v);
            end loop;

            -- Pipeline delays
            s_is_fg_d2      <= s_is_fg_d1;
            s_grid_flag_d2  <= s_grid_flag_d1;
            s_scanline_d2   <= s_scanline_d1;
            s_flicker_d2    <= s_flicker_d1;
            s_mode_sel_d2   <= s_mode_sel_d1;
            s_stack_bg_y_d1 <= s_stack_bg_y;
            s_stack_bg_u_d1 <= s_stack_bg_u;
            s_stack_bg_v_d1 <= s_stack_bg_v;
        end if;
    end process;

    -- ========================================================================
    -- Stage 3: 16→4 group reduction (four independent 4-way min comparisons)
    -- ========================================================================
    p_stage3_reduce_16to4 : process(clk)
        variable v_min_01 : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_01 : unsigned(3 downto 0);
        variable v_min_23 : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_23 : unsigned(3 downto 0);
        variable v_min_45 : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_45 : unsigned(3 downto 0);
        variable v_min_67 : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_67 : unsigned(3 downto 0);
        variable v_min_89 : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_89 : unsigned(3 downto 0);
        variable v_min_ab : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_ab : unsigned(3 downto 0);
        variable v_min_cd : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_cd : unsigned(3 downto 0);
        variable v_min_ef : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_ef : unsigned(3 downto 0);
    begin
        if rising_edge(clk) then
            -- Group A: entries 0-3
            if s_dist(0) <= s_dist(1) then
                v_min_01 := s_dist(0); v_idx_01 := x"0";
            else
                v_min_01 := s_dist(1); v_idx_01 := x"1";
            end if;
            if s_dist(2) <= s_dist(3) then
                v_min_23 := s_dist(2); v_idx_23 := x"2";
            else
                v_min_23 := s_dist(3); v_idx_23 := x"3";
            end if;
            if v_min_01 <= v_min_23 then
                s_grp_min_a <= v_min_01; s_grp_idx_a <= v_idx_01;
            else
                s_grp_min_a <= v_min_23; s_grp_idx_a <= v_idx_23;
            end if;

            -- Group B: entries 4-7
            if s_dist(4) <= s_dist(5) then
                v_min_45 := s_dist(4); v_idx_45 := x"4";
            else
                v_min_45 := s_dist(5); v_idx_45 := x"5";
            end if;
            if s_dist(6) <= s_dist(7) then
                v_min_67 := s_dist(6); v_idx_67 := x"6";
            else
                v_min_67 := s_dist(7); v_idx_67 := x"7";
            end if;
            if v_min_45 <= v_min_67 then
                s_grp_min_b <= v_min_45; s_grp_idx_b <= v_idx_45;
            else
                s_grp_min_b <= v_min_67; s_grp_idx_b <= v_idx_67;
            end if;

            -- Group C: entries 8-11
            if s_dist(8) <= s_dist(9) then
                v_min_89 := s_dist(8); v_idx_89 := x"8";
            else
                v_min_89 := s_dist(9); v_idx_89 := x"9";
            end if;
            if s_dist(10) <= s_dist(11) then
                v_min_ab := s_dist(10); v_idx_ab := x"A";
            else
                v_min_ab := s_dist(11); v_idx_ab := x"B";
            end if;
            if v_min_89 <= v_min_ab then
                s_grp_min_c <= v_min_89; s_grp_idx_c <= v_idx_89;
            else
                s_grp_min_c <= v_min_ab; s_grp_idx_c <= v_idx_ab;
            end if;

            -- Group D: entries 12-15
            if s_dist(12) <= s_dist(13) then
                v_min_cd := s_dist(12); v_idx_cd := x"C";
            else
                v_min_cd := s_dist(13); v_idx_cd := x"D";
            end if;
            if s_dist(14) <= s_dist(15) then
                v_min_ef := s_dist(14); v_idx_ef := x"E";
            else
                v_min_ef := s_dist(15); v_idx_ef := x"F";
            end if;
            if v_min_cd <= v_min_ef then
                s_grp_min_d <= v_min_cd; s_grp_idx_d <= v_idx_cd;
            else
                s_grp_min_d <= v_min_ef; s_grp_idx_d <= v_idx_ef;
            end if;

            -- Pipeline delays
            s_is_fg_d3      <= s_is_fg_d2;
            s_grid_flag_d3  <= s_grid_flag_d2;
            s_scanline_d3   <= s_scanline_d2;
            s_flicker_d3    <= s_flicker_d2;
            s_mode_sel_d3   <= s_mode_sel_d2;
            s_stack_bg_y_d2 <= s_stack_bg_y_d1;
            s_stack_bg_u_d2 <= s_stack_bg_u_d1;
            s_stack_bg_v_d2 <= s_stack_bg_v_d1;
        end if;
    end process;

    -- ========================================================================
    -- Stage 4: 4→1 final reduction → winner index
    -- ========================================================================
    p_stage4_reduce_4to1 : process(clk)
        variable v_min_ab : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_ab : unsigned(3 downto 0);
        variable v_min_cd : unsigned(C_DIST_WIDTH - 1 downto 0);
        variable v_idx_cd : unsigned(3 downto 0);
    begin
        if rising_edge(clk) then
            -- Semi-final: A vs B
            if s_grp_min_a <= s_grp_min_b then
                v_min_ab := s_grp_min_a; v_idx_ab := s_grp_idx_a;
            else
                v_min_ab := s_grp_min_b; v_idx_ab := s_grp_idx_b;
            end if;

            -- Semi-final: C vs D
            if s_grp_min_c <= s_grp_min_d then
                v_min_cd := s_grp_min_c; v_idx_cd := s_grp_idx_c;
            else
                v_min_cd := s_grp_min_d; v_idx_cd := s_grp_idx_d;
            end if;

            -- Final
            if v_min_ab <= v_min_cd then
                s_match_idx <= v_idx_ab;
            else
                s_match_idx <= v_idx_cd;
            end if;

            -- Pipeline delays
            s_is_fg_d4      <= s_is_fg_d3;
            s_mode_sel_d4   <= s_mode_sel_d3;
            s_stack_bg_y_d3 <= s_stack_bg_y_d2;
            s_stack_bg_u_d3 <= s_stack_bg_u_d2;
            s_stack_bg_v_d3 <= s_stack_bg_v_d2;
            s_stack_bg_y_d4 <= s_stack_bg_y_d3;
            s_stack_bg_u_d4 <= s_stack_bg_u_d3;
            s_stack_bg_v_d4 <= s_stack_bg_v_d3;
            s_grid_flag_d4  <= s_grid_flag_d3;
            s_scanline_d4   <= s_scanline_d3;
            s_flicker_d4    <= s_flicker_d3;
        end if;
    end process;

    -- ========================================================================
    -- Stage 5: Palette ROM lookup + mode mux (Color Stack vs Colored Squares)
    -- ========================================================================
    p_stage5_palette_mux : process(clk)
        variable v_pal_y : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_pal_u : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_pal_v : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            -- Palette ROM lookup
            v_pal_y := C_INTV_PALETTE(to_integer(s_match_idx)).y;
            v_pal_u := C_INTV_PALETTE(to_integer(s_match_idx)).u;
            v_pal_v := C_INTV_PALETTE(to_integer(s_match_idx)).v;

            -- Mode mux: threshold splits foreground (palette) / background (stack)
            -- in both Color Stack and Colored Squares modes
            if s_is_fg_d4 = '1' then
                s_mux_y <= v_pal_y;
                s_mux_u <= v_pal_u;
                s_mux_v <= v_pal_v;
            else
                s_mux_y <= s_stack_bg_y_d4;
                s_mux_u <= s_stack_bg_u_d4;
                s_mux_v <= s_stack_bg_v_d4;
            end if;

            -- Pipeline delays
            s_grid_flag_d5  <= s_grid_flag_d4;
            s_scanline_d5   <= s_scanline_d4;
            s_flicker_d5    <= s_flicker_d4;
        end if;
    end process;

    -- ========================================================================
    -- Stage 6: Brightness multiply + saturation U/V offset
    -- ========================================================================
    p_stage6_bri_sat_offset : process(clk)
    begin
        if rising_edge(clk) then
            s_bri_product <= s_mux_y * s_brightness;
            s_sat_off_u <= signed('0' & std_logic_vector(s_mux_u))
                         - to_signed(512, 11);
            s_sat_off_v <= signed('0' & std_logic_vector(s_mux_v))
                         - to_signed(512, 11);

            s_grid_flag_d6  <= s_grid_flag_d5;
            s_scanline_d6   <= s_scanline_d5;
            s_flicker_d6    <= s_flicker_d5;
        end if;
    end process;

    -- ========================================================================
    -- Stage 7: Sat U multiply + brightness truncate
    -- ========================================================================
    p_stage7_sat_u : process(clk)
    begin
        if rising_edge(clk) then
            -- Clamp: gain > 1.0 (pot > 512) previously WRAPPED here —
            -- the resize dropped bit 10 and Brightness at max darkened
            -- the picture (found by the vmtest semantic contracts).
            if shift_right(s_bri_product, 9) > 1023 then
                s_bri_y <= (others => '1');
            else
                s_bri_y <= resize(shift_right(s_bri_product, 9), C_VIDEO_DATA_WIDTH);
            end if;
            s_sat_prod_u <= s_sat_off_u
                          * signed('0' & std_logic_vector(s_saturation));
            s_sat_off_v_d7 <= s_sat_off_v;

            s_grid_flag_d7  <= s_grid_flag_d6;
            s_scanline_d7   <= s_scanline_d6;
            s_flicker_d7    <= s_flicker_d6;
        end if;
    end process;

    -- ========================================================================
    -- Stage 8: Sat V multiply + sat U clamp
    -- ========================================================================
    p_stage8_sat_v_u_clamp : process(clk)
        variable v_sat_res_u : signed(10 downto 0);
    begin
        if rising_edge(clk) then
            s_out_y_d8 <= s_bri_y;
            s_sat_prod_v <= s_sat_off_v_d7
                          * signed('0' & std_logic_vector(s_saturation));

            v_sat_res_u := shift_right(s_sat_prod_u, 9)(10 downto 0);
            v_sat_res_u := v_sat_res_u + to_signed(512, 11);
            if v_sat_res_u < 0 then
                s_out_u_d8 <= to_unsigned(0, C_VIDEO_DATA_WIDTH);
            elsif v_sat_res_u > 1023 then
                s_out_u_d8 <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                s_out_u_d8 <= unsigned(std_logic_vector(v_sat_res_u(9 downto 0)));
            end if;

            s_grid_flag_d8  <= s_grid_flag_d7;
            s_scanline_d8   <= s_scanline_d7;
            s_flicker_d8    <= s_flicker_d7;
        end if;
    end process;

    -- ========================================================================
    -- Stage 9: Sat V clamp + grid overlay + scanline + flicker
    -- ========================================================================
    p_stage9_output : process(clk)
        variable v_sat_res_v : signed(10 downto 0);
        variable v_out_y : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_out_u : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_out_v : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then
            v_out_y := s_out_y_d8;
            v_out_u := s_out_u_d8;

            v_sat_res_v := shift_right(s_sat_prod_v, 9)(10 downto 0);
            v_sat_res_v := v_sat_res_v + to_signed(512, 11);
            if v_sat_res_v < 0 then
                v_out_v := to_unsigned(0, C_VIDEO_DATA_WIDTH);
            elsif v_sat_res_v > 1023 then
                v_out_v := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                v_out_v := unsigned(std_logic_vector(v_sat_res_v(9 downto 0)));
            end if;

            if s_grid_flag_d8 = '1' then
                v_out_y := to_unsigned(64, C_VIDEO_DATA_WIDTH);
                v_out_u := C_CHROMA_MID;
                v_out_v := C_CHROMA_MID;
            end if;

            if s_scanline_d8 = '1' then
                if s_scan_str = '1' then
                    v_out_y := shift_right(v_out_y, 1);
                else
                    v_out_y := v_out_y - shift_right(v_out_y, 2);
                end if;
            end if;

            if s_flicker_d8 = '1' then
                v_out_y := shift_right(v_out_y, 1);
            end if;

            s_proc_y     <= v_out_y;
            s_proc_u     <= v_out_u;
            s_proc_v     <= v_out_v;
            s_proc_valid <= '1';
        end if;
    end process;

    -- ========================================================================
    -- Stage 12: Output register (consumed by interpolator)
    -- (Output is registered in s_proc_y/u/v above, this stage is implicit)
    -- ========================================================================

    -- ========================================================================
    -- Interpolator Stage — wet/dry mix (4 clocks each)
    -- ========================================================================
    mix_y_inst : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_valid,
            a      => unsigned(s_y_d),
            b      => s_proc_y,
            t      => s_mix_amount,
            result => s_mix_y_result,
            valid  => s_mix_y_valid
        );

    mix_u_inst : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_valid,
            a      => unsigned(s_u_d),
            b      => s_proc_u,
            t      => s_mix_amount,
            result => s_mix_u_result,
            valid  => s_mix_u_valid
        );

    mix_v_inst : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_valid,
            a      => unsigned(s_v_d),
            b      => s_proc_v,
            t      => s_mix_amount,
            result => s_mix_v_result,
            valid  => s_mix_v_valid
        );

    -- ========================================================================
    -- Sync and Data Delay Pipeline
    -- ========================================================================
    process(clk)
        type t_sync_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1) of std_logic;
        type t_data_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1)
            of std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_avid_delay  : t_sync_delay := (others => '0');
        variable v_hsync_delay : t_sync_delay := (others => '1');
        variable v_vsync_delay : t_sync_delay := (others => '1');
        variable v_field_delay : t_sync_delay := (others => '1');
        variable v_y_delay     : t_data_delay := (others => (others => '0'));
        variable v_u_delay     : t_data_delay := (others => (others => '0'));
        variable v_v_delay     : t_data_delay := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            v_avid_delay  := data_in.avid    & v_avid_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_hsync_delay := data_in.hsync_n & v_hsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_vsync_delay := data_in.vsync_n & v_vsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_field_delay := data_in.field_n & v_field_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_y_delay     := data_in.y       & v_y_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_u_delay     := data_in.u       & v_u_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_v_delay     := data_in.v       & v_v_delay(0 to C_PROCESSING_DELAY_CLKS - 2);

            s_avid_d    <= v_avid_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_hsync_n_d <= v_hsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_vsync_n_d <= v_vsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_field_n_d <= v_field_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_y_d       <= v_y_delay(C_DRY_TAP - 1);
            s_u_d       <= v_u_delay(C_DRY_TAP - 1);
            s_v_d       <= v_v_delay(C_DRY_TAP - 1);
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment
    -- ========================================================================
    -- Gate to studio blanking outside AVID: the mix free-runs during
    -- blanking and parameter extremes must never leak video-level
    -- content into H/V blank.
    data_out.y <= std_logic_vector(s_mix_y_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(64, s_mix_y_result'length));
    data_out.u <= std_logic_vector(s_mix_u_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(512, s_mix_u_result'length));
    data_out.v <= std_logic_vector(s_mix_v_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(512, s_mix_v_result'length));

    data_out.avid    <= s_avid_d;
    data_out.hsync_n <= s_hsync_n_d;
    data_out.vsync_n <= s_vsync_n_d;
    data_out.field_n <= s_field_n_d;

end stic;
