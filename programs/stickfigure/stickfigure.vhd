-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: stickfigure.vhd - Stickfigure Program for Videomancer
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
--   Stickfigure
--
-- Author:
--   Holger Rupprecht
--
-- Overview:
--   Reduces incoming video to simplified line drawings reminiscent of
--   stick figures (Strichmännchen).  Uses multi-axis edge detection
--   (horizontal + vertical via BRAM line buffer) to extract outlines.
--   Detected edges are rendered as dark (or light) lines on a
--   configurable background, with optional colored lines, posterization,
--   and pre-filtering.
--
--   Edge detection methods:
--     Sobel-like:  3-tap horizontal and vertical gradient approximation
--                  using current, previous pixel, and previous-line pixel
--     Roberts:     diagonal cross-gradient (current vs prev-line-prev-pixel)
--   Toggle 7 selects between the two edge operators.
--
--   The pipeline pre-filters luma with a simple 2-tap IIR low-pass
--   (toggle 10) to suppress noise before edge detection.  After edge
--   magnitude is computed, a threshold gate converts the gradient into
--   a binary or soft-weighted edge mask.  Line Weight scales the edge
--   magnitude before thresholding for bolder or finer lines.
--
--   Output compositing:  edge pixels receive Line Hue / Hue Sat color;
--   non-edge pixels receive Fill Luma brightness (white paper to black).
--   Invert toggle swaps line/background polarity.  Posterize toggle
--   quantises the edge magnitude to 4 levels for a woodcut look.
--
--   Zero-cost dry/wet mix via three interpolator_u instances.
--
-- Resources:
--   2 BRAM  (video_line_buffer for previous-line Y storage, dual-bank)
--   ~2500 LUTs estimated (edge detection, threshold, compose, sync delay)
--   3x interpolator_u (wet/dry mix per channel)
--
-- Pipeline:
--   1 clk  : input register + optional IIR pre-filter
--   1 clk  : BRAM line buffer read (previous line Y available)
--   1 clk  : horizontal + vertical + diagonal delta computation
--   1 clk  : edge magnitude combine + line weight multiply
--   1 clk  : threshold + posterize + soft edge
--   1 clk  : compose line color + fill luma + invert
--   4 clk  : interpolator_u (wet/dry mix)
--   Total  : 10 clocks
--
-- Parameters:
--   Pot 1  (registers_in(0))    : Threshold  — edge detection sensitivity
--   Pot 2  (registers_in(1))    : Line Wt    — edge line boldness/weight
--   Pot 3  (registers_in(2))    : Smooth     — pre-filter IIR smoothing amount
--   Pot 4  (registers_in(3))    : Fill Luma  — background brightness
--   Pot 5  (registers_in(4))    : Line Hue   — hue angle for line color
--   Pot 6  (registers_in(5))    : Hue Sat    — saturation of line color
--   Tog 7  (registers_in(6)(0)) : Edge Mode  — Sobel / Roberts
--   Tog 8  (registers_in(6)(1)) : Invert     — dark lines / light lines
--   Tog 9  (registers_in(6)(2)) : Color Edge — luma only / luma+chroma
--   Tog 10 (registers_in(6)(3)) : Pre-Filter — noise suppression off/on
--   Tog 11 (registers_in(6)(4)) : Posterize  — smooth / 4-level quantise
--   Fader  (registers_in(7))    : Mix        — dry/wet crossfade
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

use work.clamp_pkg.all;

architecture stickfigure of program_top is

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------
    constant C_PROCESSING_DELAY_CLKS : integer := 10;
    constant C_LINE_BUF_DEPTH        : integer := 2048;  -- max pixels per line

    ---------------------------------------------------------------------------
    -- Parameter signals
    ---------------------------------------------------------------------------
    signal s_threshold      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_line_weight    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_smooth         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_fill_luma      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_line_hue       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_hue_sat        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_edge_mode      : std_logic;
    signal s_invert         : std_logic;
    signal s_color_edge     : std_logic;
    signal s_pre_filter     : std_logic;
    signal s_posterize      : std_logic;
    signal s_mix_amount     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Line buffer signals (BRAM-based previous line storage)
    ---------------------------------------------------------------------------
    type t_line_buf is array (0 to C_LINE_BUF_DEPTH - 1)
        of unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_line_buf       : t_line_buf := (others => (others => '0'));
    signal s_pixel_addr     : unsigned(10 downto 0) := (others => '0');
    signal s_prev_line_y    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_prev_line_y_m1 : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Stage 1: Input register + pre-filter
    ---------------------------------------------------------------------------
    signal s1_y             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_y_prev        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_u_prev        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_v_prev        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_avid          : std_logic;
    -- IIR state
    signal s_iir_y          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        (others => '0');

    ---------------------------------------------------------------------------
    -- Stage 2: Line buffer read (prev line available)
    ---------------------------------------------------------------------------
    signal s2_y             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_y_prev_h      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_prev_line_y   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_prev_line_ym1 : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_u_prev        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_v_prev        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Stage 3: Delta computation
    ---------------------------------------------------------------------------
    signal s3_edge_mag      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Stage 4: Line weight multiply
    ---------------------------------------------------------------------------
    signal s4_weighted_mag  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Stage 5: Threshold + posterize
    ---------------------------------------------------------------------------
    signal s5_edge_val      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    ---------------------------------------------------------------------------
    -- Stage 6: Compose output
    ---------------------------------------------------------------------------
    signal s_proc_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_valid     : std_logic;

    ---------------------------------------------------------------------------
    -- Mix stage signals
    ---------------------------------------------------------------------------
    signal s_mix_y_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_y_valid    : std_logic;
    signal s_mix_u_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_u_valid    : std_logic;
    signal s_mix_v_result   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_v_valid    : std_logic;

    ---------------------------------------------------------------------------
    -- Sync delay and bypass
    ---------------------------------------------------------------------------
    signal s_avid_d         : std_logic;
    signal s_hsync_n_d      : std_logic;
    signal s_vsync_n_d      : std_logic;
    signal s_field_n_d      : std_logic;
    signal s_y_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Register Mapping
    ---------------------------------------------------------------------------
    s_threshold   <= unsigned(registers_in(0));
    s_line_weight <= unsigned(registers_in(1));
    s_smooth      <= unsigned(registers_in(2));
    s_fill_luma   <= unsigned(registers_in(3));
    s_line_hue    <= unsigned(registers_in(4));
    s_hue_sat     <= unsigned(registers_in(5));
    s_edge_mode   <= registers_in(6)(0);
    s_invert      <= registers_in(6)(1);
    s_color_edge  <= registers_in(6)(2);
    s_pre_filter  <= registers_in(6)(3);
    s_posterize   <= registers_in(6)(4);
    s_mix_amount  <= unsigned(registers_in(7));

    ---------------------------------------------------------------------------
    -- Processing Pipeline
    ---------------------------------------------------------------------------
    p_pipeline : process(clk)
        -- Stage 3 variables
        variable v_dx          : integer range -1023 to 1023;
        variable v_dy          : integer range -1023 to 1023;
        variable v_diag        : integer range -1023 to 1023;
        variable v_abs_dx      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_abs_dy      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_abs_diag    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_chroma_dx   : integer range -1023 to 1023;
        variable v_chroma_mag  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_mag_sum     : integer range 0 to 4095;
        -- Stage 4 variables
        variable v_weight_prod : unsigned(2 * C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Stage 5 variables
        variable v_above_thr   : integer range -1024 to 2047;
        variable v_edge_out    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Stage 6 variables
        variable v_line_y      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_line_u      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_line_v      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_fill_y      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_edge_k      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_comp_y      : integer range -1024 to 2047;
        variable v_comp_u      : integer range -1024 to 2047;
        variable v_comp_v      : integer range -1024 to 2047;
        -- IIR variables
        variable v_iir_sum     : unsigned(C_VIDEO_DATA_WIDTH downto 0);
        variable v_filtered_y  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Hue-to-UV variables
        variable v_hue_quad    : unsigned(1 downto 0);
        variable v_hue_frac    : unsigned(7 downto 0);
        variable v_u_offset    : integer range -512 to 511;
        variable v_v_offset    : integer range -512 to 511;
    begin
        if rising_edge(clk) then

            -- =================================================================
            -- Stage 1: Input register + optional IIR pre-filter
            -- =================================================================
            s1_u      <= unsigned(data_in.u);
            s1_u_prev <= s1_u;
            s1_v      <= unsigned(data_in.v);
            s1_v_prev <= s1_v;
            s1_avid   <= data_in.avid;

            if s_pre_filter = '1' then
                -- Simple IIR: out = (prev + current) / 2
                v_iir_sum := resize(s_iir_y, C_VIDEO_DATA_WIDTH + 1)
                           + resize(unsigned(data_in.y), C_VIDEO_DATA_WIDTH + 1);
                v_filtered_y := v_iir_sum(C_VIDEO_DATA_WIDTH downto 1);
                s_iir_y      <= v_filtered_y;
            else
                v_filtered_y := unsigned(data_in.y);
                s_iir_y      <= unsigned(data_in.y);
            end if;
            s1_y      <= v_filtered_y;
            s1_y_prev <= s1_y;

            -- =================================================================
            -- Stage 2: BRAM line buffer read + write
            -- Read previous line Y, then write current line Y
            -- =================================================================
            if data_in.avid = '1' then
                -- Read previous line value
                s2_prev_line_y   <= s_line_buf(to_integer(s_pixel_addr));
                s2_prev_line_ym1 <= s_prev_line_y;
                s_prev_line_y    <= s_line_buf(to_integer(s_pixel_addr));

                -- Write current filtered Y to line buffer (use variable
                -- for same-cycle value, not the 1-clk-delayed signal s1_y)
                s_line_buf(to_integer(s_pixel_addr)) <= v_filtered_y;

                -- Advance pixel counter
                if s_pixel_addr = C_LINE_BUF_DEPTH - 1 then
                    s_pixel_addr <= (others => '0');
                else
                    s_pixel_addr <= s_pixel_addr + 1;
                end if;
            end if;

            -- Reset pixel counter at start of each line
            if data_in.hsync_n = '0' then
                s_pixel_addr <= (others => '0');
            end if;

            s2_y        <= s1_y;
            s2_y_prev_h <= s1_y_prev;
            s2_u        <= s1_u;
            s2_u_prev   <= s1_u_prev;
            s2_v        <= s1_v;
            s2_v_prev   <= s1_v_prev;

            -- =================================================================
            -- Stage 3: Multi-axis delta computation
            -- =================================================================
            if s_edge_mode = '0' then
                -- Sobel-like: horizontal + vertical gradients
                -- Horizontal: current - previous pixel
                v_dx := to_integer(s2_y) - to_integer(s2_y_prev_h);
                -- Vertical: current - previous line
                v_dy := to_integer(s2_y) - to_integer(s2_prev_line_y);
            else
                -- Roberts cross: diagonal differences
                -- Diagonal 1: current - prev_line_prev_pixel
                v_dx := to_integer(s2_y) - to_integer(s2_prev_line_ym1);
                -- Diagonal 2: prev_pixel - prev_line_current
                v_dy := to_integer(s2_y_prev_h) - to_integer(s2_prev_line_y);
            end if;

            -- Absolute values
            if v_dx < 0 then
                v_abs_dx := to_unsigned(-v_dx, C_VIDEO_DATA_WIDTH);
            else
                v_abs_dx := to_unsigned(v_dx, C_VIDEO_DATA_WIDTH);
            end if;

            if v_dy < 0 then
                v_abs_dy := to_unsigned(-v_dy, C_VIDEO_DATA_WIDTH);
            else
                v_abs_dy := to_unsigned(v_dy, C_VIDEO_DATA_WIDTH);
            end if;

            -- Optional chroma edge contribution
            v_chroma_mag := (others => '0');
            if s_color_edge = '1' then
                v_chroma_dx := to_integer(s2_u) - to_integer(s2_u_prev);
                if v_chroma_dx < 0 then
                    v_chroma_mag := to_unsigned(-v_chroma_dx, C_VIDEO_DATA_WIDTH);
                else
                    v_chroma_mag := to_unsigned(v_chroma_dx, C_VIDEO_DATA_WIDTH);
                end if;
                -- Add V channel delta
                v_chroma_dx := to_integer(s2_v) - to_integer(s2_v_prev);
                if v_chroma_dx < 0 then
                    v_chroma_mag := v_chroma_mag + to_unsigned(-v_chroma_dx, C_VIDEO_DATA_WIDTH);
                else
                    v_chroma_mag := v_chroma_mag + to_unsigned(v_chroma_dx, C_VIDEO_DATA_WIDTH);
                end if;
            end if;

            -- Combine: approximate magnitude = |dx| + |dy| + chroma
            v_mag_sum := to_integer(v_abs_dx) + to_integer(v_abs_dy)
                       + to_integer(v_chroma_mag);
            if v_mag_sum > 1023 then
                s3_edge_mag <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                s3_edge_mag <= to_unsigned(v_mag_sum, C_VIDEO_DATA_WIDTH);
            end if;

            -- =================================================================
            -- Stage 4: Line weight multiply
            -- Scales edge magnitude: weighted = (mag * weight) >> 10
            -- =================================================================
            v_weight_prod := s3_edge_mag * s_line_weight;
            -- Shift right by 7: weight=128 → 1:1, weight=512 → 4:1
            if v_weight_prod(2 * C_VIDEO_DATA_WIDTH - 1 downto 7) > 1023 then
                s4_weighted_mag <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                s4_weighted_mag <= v_weight_prod(C_VIDEO_DATA_WIDTH + 6 downto 7);
            end if;

            -- =================================================================
            -- Stage 5: Threshold + posterize
            -- Subtract threshold; values below threshold become 0 (no edge)
            -- =================================================================
            v_above_thr := to_integer(s4_weighted_mag) - to_integer(s_threshold);

            if v_above_thr <= 0 then
                v_edge_out := (others => '0');
            elsif v_above_thr >= 128 then
                -- Saturate: strong edges snap to full intensity
                v_edge_out := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                -- Amplify 8×: stretch 0..127 → 0..1016 for visible lines
                v_edge_out := to_unsigned(v_above_thr * 8, C_VIDEO_DATA_WIDTH);
            end if;

            -- Posterize: quantise to 4 levels for woodcut effect
            if s_posterize = '1' then
                if v_edge_out = to_unsigned(0, C_VIDEO_DATA_WIDTH) then
                    s5_edge_val <= (others => '0');
                elsif v_edge_out < to_unsigned(256, C_VIDEO_DATA_WIDTH) then
                    s5_edge_val <= to_unsigned(341, C_VIDEO_DATA_WIDTH);
                elsif v_edge_out < to_unsigned(512, C_VIDEO_DATA_WIDTH) then
                    s5_edge_val <= to_unsigned(682, C_VIDEO_DATA_WIDTH);
                else
                    s5_edge_val <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
                end if;
            else
                s5_edge_val <= v_edge_out;
            end if;

            -- =================================================================
            -- Stage 6: Compose output
            -- Blend between fill (background) and line color based on edge_val
            -- =================================================================

            -- Line color from hue angle (simplified 4-quadrant hue mapping)
            -- Hue 0=red, ~341=green, ~682=blue (mapped from 0..1023)
            v_hue_quad := s_line_hue(C_VIDEO_DATA_WIDTH - 1 downto C_VIDEO_DATA_WIDTH - 2);
            v_hue_frac := s_line_hue(C_VIDEO_DATA_WIDTH - 3 downto 0);

            case v_hue_quad is
                when "00" =>
                    -- Red to Yellow: U decreases, V stays high
                    v_u_offset := -to_integer(resize(v_hue_frac, 10));
                    v_v_offset := 200;
                when "01" =>
                    -- Yellow to Cyan: U low, V decreases
                    v_u_offset := -200;
                    v_v_offset := 200 - to_integer(shift_left(resize(v_hue_frac, 10), 1));
                when "10" =>
                    -- Cyan to Blue: U increases, V stays low
                    v_u_offset := -200 + to_integer(shift_left(resize(v_hue_frac, 10), 1));
                    v_v_offset := -200;
                when others =>
                    -- Blue to Red: U high, V increases
                    v_u_offset := 200;
                    v_v_offset := -200 + to_integer(resize(v_hue_frac, 10));
            end case;

            -- Apply saturation scaling: interpolate between achromatic (512)
            -- and fully saturated (512 ± offset).
            -- line_u/v = 512 + (offset * hue_sat) / 1024
            -- When hue_sat=0 → 512 (neutral).  When hue_sat=1023 → 512+offset.
            v_line_u := to_unsigned(
                512 + (v_u_offset * to_integer(s_hue_sat)) / 1024,
                C_VIDEO_DATA_WIDTH);
            v_line_v := to_unsigned(
                512 + (v_v_offset * to_integer(s_hue_sat)) / 1024,
                C_VIDEO_DATA_WIDTH);

            -- Edge compositing: edge_val as blend factor between fill and line
            v_edge_k := s5_edge_val;

            if s_invert = '0' then
                -- Dark lines on bright fill: high edge = dark
                v_fill_y := s_fill_luma;
                v_line_y := (others => '0');
            else
                -- Light lines on dark fill: high edge = bright
                v_fill_y := (others => '0');
                v_line_y := s_fill_luma;
            end if;

            -- Blend: output = fill + (line - fill) * edge_k / 1024
            v_comp_y := to_integer(v_fill_y)
                      + ((to_integer(v_line_y) - to_integer(v_fill_y))
                         * to_integer(v_edge_k)) / 1024;
            v_comp_u := 512
                      + ((to_integer(v_line_u) - 512)
                         * to_integer(v_edge_k)) / 1024;
            v_comp_v := 512
                      + ((to_integer(v_line_v) - 512)
                         * to_integer(v_edge_k)) / 1024;

            s_proc_y <= fn_clamp_int_to_u(v_comp_y, 10);
            s_proc_u <= fn_clamp_int_to_u(v_comp_u, 10);
            s_proc_v <= fn_clamp_int_to_u(v_comp_v, 10);
            s_proc_valid <= '1';

        end if;
    end process p_pipeline;

    ---------------------------------------------------------------------------
    -- Interpolator Stage — wet/dry mix (4 clocks each)
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Sync and Data Delay Pipeline
    ---------------------------------------------------------------------------
    p_sync_delay : process(clk)
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
            s_y_d       <= v_y_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_u_d       <= v_u_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_v_d       <= v_v_delay(C_PROCESSING_DELAY_CLKS - 1);
        end if;
    end process p_sync_delay;

    ---------------------------------------------------------------------------
    -- Output Assignment
    ---------------------------------------------------------------------------
    data_out.y <= std_logic_vector(s_mix_y_result);
    data_out.u <= std_logic_vector(s_mix_u_result);
    data_out.v <= std_logic_vector(s_mix_v_result);

    data_out.avid    <= s_avid_d;
    data_out.hsync_n <= s_hsync_n_d;
    data_out.vsync_n <= s_vsync_n_d;
    data_out.field_n <= s_field_n_d;

end stickfigure;
