-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: howler.vhd - Howler Program for Videomancer
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
--   Howler
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Video feedback loop simulation inspired by the BBC Radiophonic Workshop
--   howl-round technique and the original Doctor Who title sequence.
--   A scanline-level IIR feedback loop using BRAM as a persistent canvas:
--   each scanline is read back from the buffer at a transformed (zoomed)
--   address, blended with the incoming video, hue-rotated, and written
--   back. Over successive frames this creates self-similar recursive
--   patterns that bloom, tunnel, and evolve organically.
--
-- Resources:
--   3x BRAM (10-bit x 2048 dual-port, one per Y/U/V channel)
--   2x lfsr16 (self-excitation noise seed)
--
-- Pipeline (deeply pipelined for HD timing closure at 74.25 MHz):
--   Address computation (8 stages):
--     A0 : register zoom_factor, effective_wrap, position source, center, h_shift
--     A1 : compute signed offset = position - center
--     A2 : multiply offset x zoom_factor (12x11 signed)
--     A3 : extract product + add center -> partial address
--     A4 : add h_shift -> raw address
--     A5 : wrap step 1 (if < 0 then add wrap)
--     A6 : wrap step 2 (if < 0 then add wrap else if >= wrap then sub wrap)
--     A7 : wrap step 3 (if >= wrap then sub wrap) -> s_rd_addr
--   BRAM read (1 stage):
--     B0 : read Y/U/V from BRAM at s_rd_addr
--   Processing (7 stages):
--     P0 : input source selection (video or LFSR noise)
--     P1 : decay multiply + inject multiply (6x 10-bit)
--     P2 : saturating accumulate
--     P3 : color drift prep (center U/V, compute drift_k)
--     P4 : rotation multiply (Givens approx)
--     P5 : re-center + clamp + brightness multiply
--     P6 : brightness clip + write-back
--   Total: 16 clocks
--   Sync delay: 16 + 4 (interpolator) = 20, divisible by 4
--
-- Horizontal wrap strategy:
--   Active width is measured dynamically via avid edge detection.
--   SD modes (active < 1024): read/write addresses use an active-only
--     pixel counter (0..active_width-1).  Read addresses wrap modulo
--     active_width so H Shift scrolls seamlessly with no blank gaps.
--   HD modes (active >= 1024): original h_count addressing with
--     modulo-1024 bit truncation (buffer fills completely, no gaps).
--
-- Parameters:
--   Pot 1  (registers_in(0))  : Zoom       — read stride (feedback spatial scale)
--   Pot 2  (registers_in(1))  : Decay      — feedback persistence
--   Pot 3  (registers_in(2))  : Inject     — input video injection amount
--   Pot 4  (registers_in(3))  : Color Drift — hue rotation per feedback iteration
--   Pot 5  (registers_in(4))  : H Shift    — horizontal spatial drift rate
--   Pot 6  (registers_in(5))  : Brightness — output gain
--   Tog 7  (registers_in(6)(0)) : Zoom Polarity (expand/contract)
--   Tog 8  (registers_in(6)(1)) : Drift Direction (CW/CCW)
--   Tog 9  (registers_in(6)(2)) : Self-Excite (LFSR seeds feedback)
--   Tog 10 (registers_in(6)(3)) : Channel Lock (independent/locked drift)
--   Tog 11 (registers_in(6)(4)) : Freeze (hold feedback buffer)
--   Fader  (registers_in(7))  : Mix (dry/wet crossfade)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture howler of program_top is

    constant C_PROCESSING_DELAY_CLKS : integer := 16;
    constant C_SYNC_DELAY_CLKS       : integer := 20;  -- 16 + 4 (interpolator) = 20
    constant C_BUF_DEPTH             : integer := 11;   -- 2048 pixels
    constant C_BUF_SIZE              : integer := 2**C_BUF_DEPTH;

    -- ========================================================================
    -- Parameter signals (directly from register port)
    -- ========================================================================
    signal s_zoom_raw       : unsigned(9 downto 0);
    signal s_decay          : unsigned(9 downto 0);
    signal s_inject         : unsigned(9 downto 0);
    signal s_color_drift    : unsigned(9 downto 0);
    signal s_h_shift_amt    : unsigned(9 downto 0);
    signal s_brightness     : unsigned(9 downto 0);
    signal s_zoom_contract  : std_logic;
    signal s_drift_ccw      : std_logic;
    signal s_self_excite    : std_logic;
    signal s_channel_lock   : std_logic;
    signal s_freeze         : std_logic;
    signal s_mix_amount     : unsigned(9 downto 0);

    -- ========================================================================
    -- Timing
    -- ========================================================================
    signal s_video_timing   : t_video_timing_port;

    -- ========================================================================
    -- Position counters
    -- ========================================================================
    signal s_h_count        : unsigned(11 downto 0) := (others => '0');
    signal s_v_count        : unsigned(11 downto 0) := (others => '0');
    signal s_prev_hsync_n   : std_logic := '1';
    signal s_prev_vsync_n   : std_logic := '1';

    -- ========================================================================
    -- BRAM feedback buffers (dual-port: port A = read, port B = write)
    -- ========================================================================
    type t_bram is array (0 to C_BUF_SIZE - 1)
        of std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

    signal bram_y : t_bram := (others => (others => '0'));
    signal bram_u : t_bram := (others => (5 => '1', others => '0'));  -- init to 512
    signal bram_v : t_bram := (others => (5 => '1', others => '0'));  -- init to 512

    -- Read/write addresses
    signal s_rd_addr        : unsigned(C_BUF_DEPTH - 1 downto 0);
    signal s_wr_addr        : unsigned(C_BUF_DEPTH - 1 downto 0);

    -- BRAM read outputs (registered)
    signal s_fb_y_rd        : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_fb_u_rd        : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_fb_v_rd        : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Address pipeline signals (A0..A7)
    -- ========================================================================
    -- A0: registered parameters and position
    signal s_a0_zoom_factor   : unsigned(10 downto 0) := (others => '0');
    signal s_a0_is_sd         : std_logic := '0';
    signal s_a0_position      : unsigned(11 downto 0) := (others => '0');
    signal s_a0_center        : signed(11 downto 0) := (others => '0');
    signal s_a0_h_shift       : unsigned(9 downto 0) := (others => '0');
    signal s_a0_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a0_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A1: offset from center
    signal s_a1_offset        : signed(11 downto 0) := (others => '0');
    signal s_a1_zoom_factor   : unsigned(10 downto 0) := (others => '0');
    signal s_a1_center        : signed(11 downto 0) := (others => '0');
    signal s_a1_h_shift       : unsigned(9 downto 0) := (others => '0');
    signal s_a1_is_sd         : std_logic := '0';
    signal s_a1_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a1_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A2: multiply result
    signal s_a2_product       : signed(23 downto 0) := (others => '0');
    signal s_a2_center        : signed(11 downto 0) := (others => '0');
    signal s_a2_h_shift       : unsigned(9 downto 0) := (others => '0');
    signal s_a2_is_sd         : std_logic := '0';
    signal s_a2_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a2_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A3: partial address (product extract + center)
    signal s_a3_partial       : signed(12 downto 0) := (others => '0');
    signal s_a3_h_shift       : unsigned(9 downto 0) := (others => '0');
    signal s_a3_is_sd         : std_logic := '0';
    signal s_a3_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a3_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A4: raw address (partial + h_shift)
    signal s_a4_rd_raw        : signed(12 downto 0) := (others => '0');
    signal s_a4_is_sd         : std_logic := '0';
    signal s_a4_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a4_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A5: wrap step 1
    signal s_a5_wrapped       : signed(12 downto 0) := (others => '0');
    signal s_a5_is_sd         : std_logic := '0';
    signal s_a5_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a5_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A6: wrap step 2
    signal s_a6_wrapped       : signed(12 downto 0) := (others => '0');
    signal s_a6_is_sd         : std_logic := '0';
    signal s_a6_eff_wrap      : unsigned(11 downto 0) := (others => '0');
    signal s_a6_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- A7: write address pipeline endpoint
    signal s_a7_wr_addr       : unsigned(C_BUF_DEPTH - 1 downto 0) := (others => '0');

    -- ========================================================================
    -- Processing pipeline signals (P0..P6)
    -- ========================================================================
    -- P0: input selection
    signal s_p0_input_y      : unsigned(9 downto 0) := (others => '0');
    signal s_p0_input_u      : unsigned(9 downto 0) := (others => '0');
    signal s_p0_input_v      : unsigned(9 downto 0) := (others => '0');
    signal s_p0_fb_y         : unsigned(9 downto 0) := (others => '0');
    signal s_p0_fb_u         : unsigned(9 downto 0) := (others => '0');
    signal s_p0_fb_v         : unsigned(9 downto 0) := (others => '0');

    -- P1: decay and inject multiply results
    signal s_p1_fb_y_decayed : unsigned(9 downto 0) := (others => '0');
    signal s_p1_fb_u_decayed : unsigned(9 downto 0) := (others => '0');
    signal s_p1_fb_v_decayed : unsigned(9 downto 0) := (others => '0');
    signal s_p1_inject_y     : unsigned(9 downto 0) := (others => '0');
    signal s_p1_inject_u     : unsigned(9 downto 0) := (others => '0');
    signal s_p1_inject_v     : unsigned(9 downto 0) := (others => '0');

    -- P2: accumulation results
    signal s_p2_accum_y      : unsigned(9 downto 0) := (others => '0');
    signal s_p2_accum_u      : unsigned(9 downto 0) := (others => '0');
    signal s_p2_accum_v      : unsigned(9 downto 0) := (others => '0');

    -- P3: color drift prep
    signal s_p3_y            : unsigned(9 downto 0) := (others => '0');
    signal s_p3_u_centered   : signed(10 downto 0) := (others => '0');
    signal s_p3_v_centered   : signed(10 downto 0) := (others => '0');
    signal s_p3_drift_k      : signed(10 downto 0) := (others => '0');
    signal s_p3_channel_lock : std_logic := '0';

    -- P4: rotation products
    signal s_p4_y            : unsigned(9 downto 0) := (others => '0');
    signal s_p4_u_rotated    : signed(11 downto 0) := (others => '0');
    signal s_p4_v_rotated    : signed(11 downto 0) := (others => '0');
    signal s_p4_channel_lock : std_logic := '0';

    -- P5: drift clamped + brightness multiply
    signal s_p5_drift_y      : unsigned(9 downto 0) := (others => '0');
    signal s_p5_drift_u      : unsigned(9 downto 0) := (others => '0');
    signal s_p5_drift_v      : unsigned(9 downto 0) := (others => '0');
    signal s_p5_brt_product  : unsigned(19 downto 0) := (others => '0');

    -- P6: final output + write-back
    signal s_out_y           : unsigned(9 downto 0) := (others => '0');
    signal s_out_u           : unsigned(9 downto 0) := (others => '0');
    signal s_out_v           : unsigned(9 downto 0) := (others => '0');

    -- Write-back data
    signal s_wb_y            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_wb_u            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_wb_v            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_wb_addr         : unsigned(C_BUF_DEPTH - 1 downto 0);
    signal s_wb_en           : std_logic := '0';

    -- LFSR noise
    signal s_lfsr_a_out     : std_logic_vector(15 downto 0);
    signal s_lfsr_b_out     : std_logic_vector(15 downto 0);

    -- H-shift accumulator
    signal s_h_shift_accum  : unsigned(15 downto 0) := (others => '0');

    -- ========================================================================
    -- Active pixel tracking (for seamless horizontal wrap)
    -- ========================================================================
    signal s_active_pixel     : unsigned(11 downto 0) := (others => '0');
    signal s_active_width_reg : unsigned(11 downto 0) := to_unsigned(720, 12);
    signal s_prev_avid        : std_logic := '0';

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

    -- Mix outputs
    signal s_mix_y_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_y_valid    : std_logic;
    signal s_mix_u_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_u_valid    : std_logic;
    signal s_mix_v_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_v_valid    : std_logic;

    -- Saturating add helper
    function sat_add_u(a : unsigned(9 downto 0); b : unsigned(9 downto 0))
        return unsigned is
        variable s : unsigned(10 downto 0);
    begin
        s := ('0' & a) + ('0' & b);
        if s(10) = '1' then
            return to_unsigned(1023, 10);
        else
            return s(9 downto 0);
        end if;
    end function;

    -- Signed clamp to 10-bit unsigned
    function clamp_s_to_u(v : signed(11 downto 0)) return unsigned is
    begin
        if v < 0 then
            return to_unsigned(0, 10);
        elsif v > 1023 then
            return to_unsigned(1023, 10);
        else
            return unsigned(v(9 downto 0));
        end if;
    end function;

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_zoom_raw      <= unsigned(registers_in(0));
    s_decay         <= unsigned(registers_in(1));
    s_inject        <= unsigned(registers_in(2));
    s_color_drift   <= unsigned(registers_in(3));
    s_h_shift_amt   <= unsigned(registers_in(4));
    s_brightness    <= unsigned(registers_in(5));
    s_zoom_contract <= registers_in(6)(0);
    s_drift_ccw     <= registers_in(6)(1);
    s_self_excite   <= registers_in(6)(2);
    s_channel_lock  <= registers_in(6)(3);
    s_freeze        <= registers_in(6)(4);
    s_mix_amount    <= unsigned(registers_in(7));

    -- ========================================================================
    -- Video Timing Generator
    -- ========================================================================
    timing_gen_inst : entity work.video_timing_generator
        port map(
            clk         => clk,
            ref_hsync_n => data_in.hsync_n,
            ref_vsync_n => data_in.vsync_n,
            ref_avid    => data_in.avid,
            timing      => s_video_timing
        );

    -- ========================================================================
    -- LFSR noise sources (for self-excitation seeding)
    -- ========================================================================
    lfsr_a_inst : entity work.lfsr16
        port map(clk => clk, enable => '1', seed => x"CAFE", load => '0',
                 q => s_lfsr_a_out);
    lfsr_b_inst : entity work.lfsr16
        port map(clk => clk, enable => '1', seed => x"FADE", load => '0',
                 q => s_lfsr_b_out);

    -- ========================================================================
    -- Position counters + H shift accumulator
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_prev_hsync_n <= data_in.hsync_n;
            s_prev_vsync_n <= data_in.vsync_n;
            s_prev_avid    <= data_in.avid;

            if data_in.hsync_n = '0' and s_prev_hsync_n = '1' then
                s_h_count <= (others => '0');
                s_v_count <= s_v_count + 1;
                s_active_pixel <= (others => '0');
            else
                s_h_count <= s_h_count + 1;
                if data_in.avid = '1' then
                    s_active_pixel <= s_active_pixel + 1;
                end if;
            end if;

            -- Latch active width at end of active region
            if data_in.avid = '0' and s_prev_avid = '1' then
                s_active_width_reg <= s_active_pixel;
            end if;

            if data_in.vsync_n = '0' and s_prev_vsync_n = '1' then
                s_v_count <= (others => '0');
                -- Advance horizontal shift accumulator each frame
                s_h_shift_accum <= s_h_shift_accum + ("000000" & s_h_shift_amt);
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A0: Register parameters and position source
    -- ========================================================================
    p_addr_a0 : process(clk)
        variable v_is_sd   : std_logic;
        variable v_eff_wrap : unsigned(11 downto 0);
    begin
        if rising_edge(clk) then
            -- Effective wrap width: min(active_width, buffer_size)
            if s_active_width_reg >= to_unsigned(C_BUF_SIZE, 12) then
                v_eff_wrap := to_unsigned(C_BUF_SIZE, 12);
                v_is_sd := '0';
            else
                v_eff_wrap := s_active_width_reg;
                v_is_sd := '1';
            end if;

            s_a0_eff_wrap <= v_eff_wrap;
            s_a0_is_sd    <= v_is_sd;

            -- Zoom factor: zoom_raw maps to 0.5..1.5 (1.10 unsigned fixed-point)
            if s_zoom_contract = '0' then
                s_a0_zoom_factor <= resize(s_zoom_raw, 11) + to_unsigned(512, 11);
            else
                s_a0_zoom_factor <= to_unsigned(1536, 11) - resize(s_zoom_raw, 11);
            end if;

            -- Position source and center
            if v_is_sd = '1' then
                s_a0_position <= s_active_pixel;
                s_a0_center   <= signed(std_logic_vector(resize(
                    shift_right(v_eff_wrap, 1), 12)));
                s_a0_wr_addr  <= s_active_pixel(C_BUF_DEPTH - 1 downto 0);
            else
                s_a0_position <= s_h_count;
                s_a0_center   <= to_signed(512, 12);
                s_a0_wr_addr  <= s_h_count(C_BUF_DEPTH - 1 downto 0);
            end if;

            s_a0_h_shift <= s_h_shift_accum(15 downto 6);
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A1: Compute offset from center
    -- ========================================================================
    p_addr_a1 : process(clk)
    begin
        if rising_edge(clk) then
            s_a1_offset      <= signed(resize(s_a0_position, 12)) - s_a0_center;
            s_a1_zoom_factor <= s_a0_zoom_factor;
            s_a1_center      <= s_a0_center;
            s_a1_h_shift     <= s_a0_h_shift;
            s_a1_is_sd       <= s_a0_is_sd;
            s_a1_eff_wrap    <= s_a0_eff_wrap;
            s_a1_wr_addr     <= s_a0_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A2: Multiply offset x zoom_factor
    -- ========================================================================
    p_addr_a2 : process(clk)
    begin
        if rising_edge(clk) then
            s_a2_product  <= s_a1_offset * signed('0' & std_logic_vector(s_a1_zoom_factor));
            s_a2_center   <= s_a1_center;
            s_a2_h_shift  <= s_a1_h_shift;
            s_a2_is_sd    <= s_a1_is_sd;
            s_a2_eff_wrap <= s_a1_eff_wrap;
            s_a2_wr_addr  <= s_a1_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A3: Extract product bits + add center ONLY
    -- ========================================================================
    p_addr_a3 : process(clk)
    begin
        if rising_edge(clk) then
            s_a3_partial  <= resize(s_a2_product(22 downto 10), 13)
                             + resize(s_a2_center, 13);
            s_a3_h_shift  <= s_a2_h_shift;
            s_a3_is_sd    <= s_a2_is_sd;
            s_a3_eff_wrap <= s_a2_eff_wrap;
            s_a3_wr_addr  <= s_a2_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A4: Add h_shift -> raw address
    -- ========================================================================
    p_addr_a4 : process(clk)
    begin
        if rising_edge(clk) then
            s_a4_rd_raw   <= s_a3_partial + signed(resize(s_a3_h_shift, 13));
            s_a4_is_sd    <= s_a3_is_sd;
            s_a4_eff_wrap <= s_a3_eff_wrap;
            s_a4_wr_addr  <= s_a3_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A5: Wrap step 1 (if < 0 then + wrap)
    -- ========================================================================
    p_addr_a5 : process(clk)
        variable v_eff_wrap_s : signed(12 downto 0);
    begin
        if rising_edge(clk) then
            v_eff_wrap_s := signed(resize(s_a4_eff_wrap, 13));
            if s_a4_is_sd = '1' and s_a4_rd_raw < 0 then
                s_a5_wrapped <= s_a4_rd_raw + v_eff_wrap_s;
            else
                s_a5_wrapped <= s_a4_rd_raw;
            end if;
            s_a5_is_sd    <= s_a4_is_sd;
            s_a5_eff_wrap <= s_a4_eff_wrap;
            s_a5_wr_addr  <= s_a4_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A6: Wrap step 2
    --   if still < 0 then + wrap; else if >= wrap then - wrap
    -- ========================================================================
    p_addr_a6 : process(clk)
        variable v_eff_wrap_s : signed(12 downto 0);
    begin
        if rising_edge(clk) then
            v_eff_wrap_s := signed(resize(s_a5_eff_wrap, 13));
            if s_a5_is_sd = '1' then
                if s_a5_wrapped < 0 then
                    s_a6_wrapped <= s_a5_wrapped + v_eff_wrap_s;
                elsif s_a5_wrapped >= v_eff_wrap_s then
                    s_a6_wrapped <= s_a5_wrapped - v_eff_wrap_s;
                else
                    s_a6_wrapped <= s_a5_wrapped;
                end if;
            else
                s_a6_wrapped <= s_a5_wrapped;
            end if;
            s_a6_is_sd    <= s_a5_is_sd;
            s_a6_eff_wrap <= s_a5_eff_wrap;
            s_a6_wr_addr  <= s_a5_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- Address Pipeline — Stage A7: Wrap step 3 (final) + HD truncation
    -- ========================================================================
    p_addr_a7 : process(clk)
        variable v_eff_wrap_s : signed(12 downto 0);
    begin
        if rising_edge(clk) then
            if s_a6_is_sd = '0' then
                -- HD mode: truncate to buffer width
                s_rd_addr <= unsigned(s_a6_wrapped(C_BUF_DEPTH - 1 downto 0));
            else
                -- SD mode: final wrap if still >= wrap
                v_eff_wrap_s := signed(resize(s_a6_eff_wrap, 13));
                if s_a6_wrapped >= v_eff_wrap_s then
                    s_rd_addr <= unsigned(resize(
                        unsigned(std_logic_vector(s_a6_wrapped - v_eff_wrap_s)),
                        C_BUF_DEPTH));
                else
                    s_rd_addr <= unsigned(s_a6_wrapped(C_BUF_DEPTH - 1 downto 0));
                end if;
            end if;
            s_wr_addr    <= s_a6_wr_addr;
            s_a7_wr_addr <= s_a6_wr_addr;
        end if;
    end process;

    -- ========================================================================
    -- BRAM read (Stage B0: 1 clock latency)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_fb_y_rd <= bram_y(to_integer(s_rd_addr));
            s_fb_u_rd <= bram_u(to_integer(s_rd_addr));
            s_fb_v_rd <= bram_v(to_integer(s_rd_addr));
        end if;
    end process;

    -- ========================================================================
    -- BRAM write (from pipeline write-back)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if s_wb_en = '1' and s_freeze = '0' then
                bram_y(to_integer(s_wb_addr)) <= s_wb_y;
                bram_u(to_integer(s_wb_addr)) <= s_wb_u;
                bram_v(to_integer(s_wb_addr)) <= s_wb_v;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P0: Input source selection
    -- ========================================================================
    p_proc_p0 : process(clk)
    begin
        if rising_edge(clk) then
            -- Choose input source: video or self-excitation noise
            if s_self_excite = '1' then
                s_p0_input_y <= unsigned(s_lfsr_a_out(9 downto 0));
                s_p0_input_u <= unsigned(s_lfsr_b_out(9 downto 0));
                s_p0_input_v <= unsigned(s_lfsr_a_out(15 downto 6));
            else
                s_p0_input_y <= unsigned(data_in.y);
                s_p0_input_u <= unsigned(data_in.u);
                s_p0_input_v <= unsigned(data_in.v);
            end if;
            -- Register feedback from BRAM
            s_p0_fb_y <= unsigned(s_fb_y_rd);
            s_p0_fb_u <= unsigned(s_fb_u_rd);
            s_p0_fb_v <= unsigned(s_fb_v_rd);
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P1: Decay multiply + inject multiply
    -- ========================================================================
    p_proc_p1 : process(clk)
        variable v_fb_y_prod : unsigned(19 downto 0);
        variable v_fb_u_prod : unsigned(19 downto 0);
        variable v_fb_v_prod : unsigned(19 downto 0);
        variable v_in_y_prod : unsigned(19 downto 0);
        variable v_in_u_prod : unsigned(19 downto 0);
        variable v_in_v_prod : unsigned(19 downto 0);
    begin
        if rising_edge(clk) then
            -- Decay: feedback * decay_factor >> 10
            v_fb_y_prod := s_p0_fb_y * s_decay;
            v_fb_u_prod := s_p0_fb_u * s_decay;
            v_fb_v_prod := s_p0_fb_v * s_decay;
            s_p1_fb_y_decayed <= v_fb_y_prod(19 downto 10);
            s_p1_fb_u_decayed <= v_fb_u_prod(19 downto 10);
            s_p1_fb_v_decayed <= v_fb_v_prod(19 downto 10);

            -- Scale input by inject amount
            v_in_y_prod := s_p0_input_y * s_inject;
            v_in_u_prod := s_p0_input_u * s_inject;
            v_in_v_prod := s_p0_input_v * s_inject;
            s_p1_inject_y <= v_in_y_prod(19 downto 10);
            s_p1_inject_u <= v_in_u_prod(19 downto 10);
            s_p1_inject_v <= v_in_v_prod(19 downto 10);
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P2: Saturating accumulate
    -- ========================================================================
    p_proc_p2 : process(clk)
    begin
        if rising_edge(clk) then
            s_p2_accum_y <= sat_add_u(s_p1_fb_y_decayed, s_p1_inject_y);
            s_p2_accum_u <= sat_add_u(s_p1_fb_u_decayed, s_p1_inject_u);
            s_p2_accum_v <= sat_add_u(s_p1_fb_v_decayed, s_p1_inject_v);
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P3: Color drift prep
    -- ========================================================================
    p_proc_p3 : process(clk)
    begin
        if rising_edge(clk) then
            s_p3_y <= s_p2_accum_y;

            -- Center U/V around zero for rotation
            s_p3_u_centered <= signed('0' & std_logic_vector(s_p2_accum_u)) - to_signed(512, 11);
            s_p3_v_centered <= signed('0' & std_logic_vector(s_p2_accum_v)) - to_signed(512, 11);

            -- Compute drift coefficient
            if s_drift_ccw = '0' then
                s_p3_drift_k <= signed(resize(s_color_drift, 11)) - to_signed(512, 11);
            else
                s_p3_drift_k <= to_signed(512, 11) - signed(resize(s_color_drift, 11));
            end if;

            s_p3_channel_lock <= s_channel_lock;
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P4: Rotation multiply (Givens approximation)
    -- ========================================================================
    p_proc_p4 : process(clk)
    begin
        if rising_edge(clk) then
            s_p4_y <= s_p3_y;

            -- Small-angle Givens rotation:
            -- U' = U - V * k / 512
            -- V' = V + U * k / 512
            s_p4_u_rotated <= resize(s_p3_u_centered, 12) -
                              resize(shift_right(s_p3_v_centered * s_p3_drift_k, 9), 12);
            s_p4_v_rotated <= resize(s_p3_v_centered, 12) +
                              resize(shift_right(s_p3_u_centered * s_p3_drift_k, 9), 12);

            s_p4_channel_lock <= s_p3_channel_lock;
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P5: Re-center + clamp + brightness multiply
    -- ========================================================================
    p_proc_p5 : process(clk)
        variable v_drift_y : unsigned(9 downto 0);
        variable v_drift_u : unsigned(9 downto 0);
        variable v_drift_v : unsigned(9 downto 0);
    begin
        if rising_edge(clk) then
            v_drift_y := s_p4_y;

            -- Re-center and clamp
            if s_p4_channel_lock = '1' then
                v_drift_u := clamp_s_to_u(s_p4_u_rotated + to_signed(512, 12));
                v_drift_v := clamp_s_to_u(s_p4_v_rotated + to_signed(512, 12));
            else
                v_drift_u := clamp_s_to_u(s_p4_u_rotated + to_signed(512, 12));
                v_drift_v := clamp_s_to_u(-s_p4_v_rotated + to_signed(512, 12));
            end if;

            s_p5_drift_y <= v_drift_y;
            s_p5_drift_u <= v_drift_u;
            s_p5_drift_v <= v_drift_v;

            -- Brightness multiply (registered at this stage, clipped at next)
            s_p5_brt_product <= v_drift_y * s_brightness;
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline — Stage P6: Brightness clip + write-back
    -- ========================================================================
    p_proc_p6 : process(clk)
    begin
        if rising_edge(clk) then
            -- Brightness clip
            if s_p5_brt_product(19 downto 9) > to_unsigned(1023, 11) then
                s_out_y <= to_unsigned(1023, 10);
            else
                s_out_y <= s_p5_brt_product(18 downto 9);
            end if;
            s_out_u <= s_p5_drift_u;
            s_out_v <= s_p5_drift_v;

            -- Write back to BRAM: write the accumulated (pre-brightness) data
            -- so feedback loop operates on raw accumulation, not gained output
            s_wb_y    <= std_logic_vector(s_p5_drift_y);
            s_wb_u    <= std_logic_vector(s_p5_drift_u);
            s_wb_v    <= std_logic_vector(s_p5_drift_v);
            s_wb_addr <= s_wr_addr;
            s_wb_en   <= '1';
        end if;
    end process;

    -- ========================================================================
    -- Interpolator Stage — wet/dry mix (4 clocks each)
    -- ========================================================================
    mix_y_inst : entity work.interpolator_u
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_y_d), b => s_out_y,
                 t => s_mix_amount, result => s_mix_y_result, valid => s_mix_y_valid);

    mix_u_inst : entity work.interpolator_u
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_u_d), b => s_out_u,
                 t => s_mix_amount, result => s_mix_u_result, valid => s_mix_u_valid);

    mix_v_inst : entity work.interpolator_u
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_v_d), b => s_out_v,
                 t => s_mix_amount, result => s_mix_v_result, valid => s_mix_v_valid);

    -- ========================================================================
    -- Sync and Data Delay Pipeline
    -- ========================================================================
    process(clk)
        type t_sync_delay is array (0 to C_SYNC_DELAY_CLKS - 1) of std_logic;
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
            v_avid_delay  := data_in.avid    & v_avid_delay(0 to C_SYNC_DELAY_CLKS - 2);
            v_hsync_delay := data_in.hsync_n & v_hsync_delay(0 to C_SYNC_DELAY_CLKS - 2);
            v_vsync_delay := data_in.vsync_n & v_vsync_delay(0 to C_SYNC_DELAY_CLKS - 2);
            v_field_delay := data_in.field_n & v_field_delay(0 to C_SYNC_DELAY_CLKS - 2);
            v_y_delay     := data_in.y       & v_y_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_u_delay     := data_in.u       & v_u_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_v_delay     := data_in.v       & v_v_delay(0 to C_PROCESSING_DELAY_CLKS - 2);

            s_avid_d    <= v_avid_delay(C_SYNC_DELAY_CLKS - 1);
            s_hsync_n_d <= v_hsync_delay(C_SYNC_DELAY_CLKS - 1);
            s_vsync_n_d <= v_vsync_delay(C_SYNC_DELAY_CLKS - 1);
            s_field_n_d <= v_field_delay(C_SYNC_DELAY_CLKS - 1);
            s_y_d       <= v_y_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_u_d       <= v_u_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_v_d       <= v_v_delay(C_PROCESSING_DELAY_CLKS - 1);
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment (sync delay = 20, divisible by 4, no IO align needed)
    -- ========================================================================
    -- Gate to studio blanking outside AVID: extreme zoom/shift
    -- resampling must never paint the blanking interval.
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

end howler;
