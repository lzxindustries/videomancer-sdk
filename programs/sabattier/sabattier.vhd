-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: sabattier.vhd - Sabattier Program for Videomancer
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
--   Sabattier
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Sabattier effect (pseudo-solarization) with Mackie line edge glow.
--   Simulates the darkroom technique where a partially-developed print
--   is re-exposed to light: midtones undergo partial tonal reversal
--   while shadows and highlights remain relatively stable, producing
--   a surreal, metallic appearance. The defining Mackie line artifact —
--   bright luminous borders at tonal boundaries caused by bromide ion
--   migration — is generated via horizontal gradient detection and
--   additive overlay. Supports independent Y and UV solarization,
--   selectable S-curve vs W-curve response, equidensity contour mode,
--   and metallic tinting.
--
--   Zero BRAM usage — curve is computed piecewise, not LUT-based.
--
-- Pipeline (deeply pipelined for timing closure at 74.25 MHz):
--   1 clk : input register + polarity
--   1 clk : Y proximity calculation (distance from midtone centres)
--   1 clk : Y proximity × amount multiply
--   1 clk : Y equidensity + dip subtraction + clamp (solar Y complete)
--   1 clk : UV proximity calculation + Y gradient delay pipeline
--   1 clk : UV proximity × amount multiply + gradient detection
--   1 clk : UV dip subtraction + clamp + gradient threshold gate
--   1 clk : Mackie gain multiply
--   1 clk : Mackie clamp + IIR width spread
--   1 clk : Additive overlay
--   1 clk : Metallic tint multiply
--   1 clk : Tint add/subtract + clamp (proc output)
--   4 clk : interpolator_u (wet/dry mix)
--   Total : 16 clocks
--
-- Parameters:
--   Pot 1  (registers_in(0))    : Y Inversion  — Sabattier depth for luma
--   Pot 2  (registers_in(1))    : UV Inversion — Sabattier depth for chroma
--   Pot 3  (registers_in(2))    : Mackie Gain  — edge glow brightness
--   Pot 4  (registers_in(3))    : Mackie Width — edge glow spread
--   Pot 5  (registers_in(4))    : Tint         — metallic color shift
--   Pot 6  (registers_in(5))    : Threshold    — Mackie line threshold
--   Tog 7  (registers_in(6)(0)) : Equidensity  — normal / contour mode
--   Tog 8  (registers_in(6)(1)) : Polarity     — positive / negative
--   Tog 9  (registers_in(6)(2)) : Channel      — Y only / Y+UV
--   Tog 10 (registers_in(6)(3)) : Curve Shape  — S-curve / W-curve
--   Tog 11 (registers_in(6)(4)) : Metallic (force maximum tint)
--   Fader  (registers_in(7))    : Mix          — dry/wet crossfade
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

use work.clamp_pkg.all;
architecture sabattier of program_top is

    -- Total data latency incl. the 4-clk mix interpolators (and %4
    -- padding): sync/AVID tap the full depth, dry data taps 4 short so
    -- data-through-mix and sync reach data_out co-timed (was 16 with
    -- sync tapped at the same depth as dry data - video trailed the
    -- program's own sync by the mix latency).
    constant C_MIX_LATENCY_CLKS : integer := 4;
    constant C_PROCESSING_DELAY_CLKS : integer := 20;
    constant C_DRY_TAP : integer := C_PROCESSING_DELAY_CLKS - C_MIX_LATENCY_CLKS;

    -- ========================================================================
    -- Parameter signals
    -- ========================================================================
    signal s_y_inversion    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_uv_inversion   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mackie_gain    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mackie_width   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_tint           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_threshold      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_equidensity    : std_logic;
    signal s_polarity       : std_logic;
    signal s_channel_link   : std_logic;
    signal s_curve_shape    : std_logic;
    signal s_metallic       : std_logic;
    signal s_mix_amount     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 1: Input register + polarity
    -- ========================================================================
    signal s1_y             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s1_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 2: Y proximity calculation
    -- ========================================================================
    signal s2_y_proximity   : unsigned(9 downto 0);  -- 0..512 fits in 10 bits
    signal s2_y_amt         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_y_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_equi          : std_logic;
    signal s2_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s2_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 3: Y proximity × amount multiply
    -- ========================================================================
    signal s3_y_dip         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s3_y_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s3_equi          : std_logic;
    signal s3_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s3_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 4: Y solar complete + UV input registered
    -- ========================================================================
    signal s4_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s4_u             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s4_v             : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 5: UV proximity + Y gradient delay pipeline
    -- ========================================================================
    signal s5_u_proximity   : unsigned(9 downto 0);
    signal s5_v_proximity   : unsigned(9 downto 0);
    signal s5_uv_amt        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s5_u_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s5_v_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s5_channel_link  : std_logic;
    signal s5_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s5_solar_y_d1    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s5_solar_y_d2    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 6: UV multiply + gradient detection
    -- ========================================================================
    signal s6_u_dip         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s6_v_dip         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s6_u_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s6_v_in          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s6_channel_link  : std_logic;
    signal s6_gradient      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s6_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 7: UV clamp + gradient threshold
    -- ========================================================================
    signal s7_solar_u       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s7_solar_v       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s7_gradient      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s7_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 8: Mackie gain multiply (register raw product)
    -- ========================================================================
    signal s8_mackie_raw    : unsigned(2 * C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s8_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s8_solar_u       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s8_solar_v       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 9: Mackie clamp + IIR width spread
    -- ========================================================================
    signal s9_mackie_y      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s9_solar_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s9_solar_u       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s9_solar_v       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Mackie IIR state
    signal s_mackie_prev    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        (others => '0');

    -- ========================================================================
    -- Stage 10: Additive overlay
    -- ========================================================================
    signal s10_overlay_y    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s10_overlay_u    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s10_overlay_v    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Stage 11: Metallic tint multiply
    -- ========================================================================
    signal s11_y            : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s11_u            : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s11_v            : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s11_tint_shift   : unsigned(C_VIDEO_DATA_WIDTH - 3 downto 0);

    -- ========================================================================
    -- Stage 12: Tint apply + clamp (proc output)
    -- ========================================================================
    signal s_proc_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_valid     : std_logic;

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

    -- ========================================================================
    -- Proximity calculation function (pure combinational, shallow)
    -- Computes distance-from-midtone as a triangle function.
    -- S-curve: single peak at 512 (range 0..512)
    -- W-curve: two peaks at 256 and 768 (range 0..256, then doubled)
    -- ========================================================================
    function calc_proximity(
        x       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        w_curve : std_logic
    ) return unsigned is
        variable v_xi          : integer range 0 to 1023;
        variable v_mid_dist    : integer range 0 to 1023;
        variable v_prox_q1     : integer range 0 to 256;
        variable v_prox_q3     : integer range 0 to 256;
        variable v_result      : unsigned(9 downto 0);
    begin
        v_xi := to_integer(x);

        if w_curve = '0' then
            -- S-curve: triangle peaked at 512
            if v_xi >= 512 then
                v_mid_dist := v_xi - 512;
            else
                v_mid_dist := 512 - v_xi;
            end if;
            if v_mid_dist < 512 then
                v_result := to_unsigned(512 - v_mid_dist, 10);
            else
                v_result := (others => '0');
            end if;
        else
            -- W-curve: two peaks at 256, 768
            if v_xi < 512 then
                -- Q1 peak at 256
                if v_xi <= 256 then
                    v_prox_q1 := v_xi;
                else
                    v_prox_q1 := 512 - v_xi;
                end if;
                if v_prox_q1 < 0 then
                    v_prox_q1 := 0;
                end if;
                -- Scale ×2 so W-curve range matches S-curve (0..512)
                v_result := to_unsigned(v_prox_q1 * 2, 10);
            else
                -- Q3 peak at 768
                if v_xi <= 768 then
                    v_prox_q3 := v_xi - 512;
                else
                    v_prox_q3 := 1023 - v_xi;
                end if;
                if v_prox_q3 < 0 then
                    v_prox_q3 := 0;
                end if;
                v_result := to_unsigned(v_prox_q3 * 2, 10);
            end if;
        end if;

        return v_result;
    end function;

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_y_inversion  <= unsigned(registers_in(0));
    s_uv_inversion <= unsigned(registers_in(1));
    s_mackie_gain  <= unsigned(registers_in(2));
    s_mackie_width <= unsigned(registers_in(3));
    s_tint         <= unsigned(registers_in(4));
    s_threshold    <= unsigned(registers_in(5));
    s_equidensity  <= registers_in(6)(0);
    s_polarity     <= registers_in(6)(1);
    s_channel_link <= registers_in(6)(2);
    s_curve_shape  <= registers_in(6)(3);
    s_metallic     <= registers_in(6)(4);
    s_mix_amount   <= unsigned(registers_in(7));

    -- ========================================================================
    -- Processing Pipeline
    -- ========================================================================
    process(clk)
        -- Stage 3 variables
        variable v_y_mul       : unsigned(19 downto 0);  -- 10×10 = 20
        variable v_y_dip_raw   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Stage 4 variables
        variable v_y_dip_eq    : unsigned(C_VIDEO_DATA_WIDTH downto 0);  -- 11 bits for ×2
        variable v_y_result    : integer range -1024 to 2047;
        -- Stage 6 variables
        variable v_u_mul       : unsigned(19 downto 0);
        variable v_v_mul       : unsigned(19 downto 0);
        variable v_grad_diff   : integer range -1023 to 1023;
        -- Stage 7 variables
        variable v_u_dip_eq    : unsigned(C_VIDEO_DATA_WIDTH downto 0);
        variable v_v_dip_eq    : unsigned(C_VIDEO_DATA_WIDTH downto 0);
        variable v_u_result    : integer range -1024 to 2047;
        variable v_v_result    : integer range -1024 to 2047;
        -- Stage 8 variables
        variable v_mackie_raw  : unsigned(2 * C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Stage 9 variables
        variable v_mackie_val  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_alpha       : unsigned(3 downto 0);
        variable v_inv_alpha   : unsigned(4 downto 0);
        variable v_blend_a     : unsigned(13 downto 0);
        variable v_blend_b     : unsigned(14 downto 0);
        variable v_blend_sum   : unsigned(14 downto 0);
        -- Stage 10 variables
        variable v_overlay_int : integer range 0 to 2047;
        -- Stage 11 variables
        variable v_tint_k      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_tint_prod   : unsigned(2 * C_VIDEO_DATA_WIDTH - 1 downto 0);
        -- Stage 11 variables
        variable v_u_int       : integer range -256 to 1279;
        variable v_v_int       : integer range -256 to 1279;
    begin
        if rising_edge(clk) then

            -- ================================================================
            -- Stage 1: Input register + polarity inversion
            -- ================================================================
            if s_polarity = '1' then
                s1_y <= to_unsigned(1023, C_VIDEO_DATA_WIDTH) - unsigned(data_in.y);
            else
                s1_y <= unsigned(data_in.y);
            end if;
            s1_u <= unsigned(data_in.u);
            s1_v <= unsigned(data_in.v);

            -- ================================================================
            -- Stage 2: Y proximity calculation (distance from midtone)
            -- ================================================================
            s2_y_proximity <= calc_proximity(s1_y, s_curve_shape);
            s2_y_amt       <= s_y_inversion;
            s2_y_in        <= s1_y;
            s2_equi        <= s_equidensity;
            s2_u           <= s1_u;
            s2_v           <= s1_v;

            -- ================================================================
            -- Stage 3: Y proximity × amount multiply
            -- Divide by 1024 (shift right 10) to normalize
            -- ================================================================
            v_y_mul     := s2_y_proximity * s2_y_amt;
            v_y_dip_raw := v_y_mul(19 downto 10);
            s3_y_dip    <= v_y_dip_raw;
            s3_y_in     <= s2_y_in;
            s3_equi     <= s2_equi;
            s3_u        <= s2_u;
            s3_v        <= s2_v;

            -- ================================================================
            -- Stage 4: Y equidensity doubling + dip subtraction + clamp
            -- Solar Y is now complete
            -- ================================================================
            if s3_equi = '1' then
                v_y_dip_eq := resize(s3_y_dip, C_VIDEO_DATA_WIDTH + 1)
                            + resize(s3_y_dip, C_VIDEO_DATA_WIDTH + 1);
                if v_y_dip_eq > 1023 then
                    v_y_dip_eq := to_unsigned(1023, C_VIDEO_DATA_WIDTH + 1);
                end if;
            else
                v_y_dip_eq := resize(s3_y_dip, C_VIDEO_DATA_WIDTH + 1);
            end if;

            v_y_result := to_integer(s3_y_in) - to_integer(v_y_dip_eq);
            s4_solar_y <= fn_clamp_int_to_u(v_y_result, 10);
            s4_u       <= s3_u;
            s4_v       <= s3_v;

            -- ================================================================
            -- Stage 5: UV proximity calculation + Y gradient delay
            -- ================================================================
            s5_u_proximity <= calc_proximity(s4_u, s_curve_shape);
            s5_v_proximity <= calc_proximity(s4_v, s_curve_shape);
            s5_uv_amt      <= s_uv_inversion;
            s5_u_in        <= s4_u;
            s5_v_in        <= s4_v;
            s5_channel_link <= s_channel_link;

            -- Y gradient delay pipeline (need current and 2-pixel-delayed)
            s5_solar_y    <= s4_solar_y;
            s5_solar_y_d1 <= s5_solar_y;
            s5_solar_y_d2 <= s5_solar_y_d1;

            -- ================================================================
            -- Stage 6: UV proximity × amount multiply + gradient detection
            -- ================================================================
            v_u_mul     := s5_u_proximity * s5_uv_amt;
            v_v_mul     := s5_v_proximity * s5_uv_amt;
            s6_u_dip    <= v_u_mul(19 downto 10);
            s6_v_dip    <= v_v_mul(19 downto 10);
            s6_u_in     <= s5_u_in;
            s6_v_in     <= s5_v_in;
            s6_channel_link <= s5_channel_link;

            -- Gradient: |solar_y[current] - solar_y[2-pixel-delayed]|
            v_grad_diff := to_integer(s5_solar_y) - to_integer(s5_solar_y_d2);
            if v_grad_diff < 0 then
                s6_gradient <= to_unsigned(-v_grad_diff, C_VIDEO_DATA_WIDTH);
            else
                s6_gradient <= to_unsigned(v_grad_diff, C_VIDEO_DATA_WIDTH);
            end if;
            s6_solar_y <= s5_solar_y_d1;

            -- ================================================================
            -- Stage 7: UV dip subtraction + clamp + gradient threshold
            -- ================================================================
            if s6_channel_link = '1' then
                -- UV dip subtraction (no equidensity for UV)
                v_u_result := to_integer(s6_u_in) - to_integer(s6_u_dip);
                v_v_result := to_integer(s6_v_in) - to_integer(s6_v_dip);
                s7_solar_u <= fn_clamp_int_to_u(v_u_result, 10);
                s7_solar_v <= fn_clamp_int_to_u(v_v_result, 10);
            else
                s7_solar_u <= s6_u_in;
                s7_solar_v <= s6_v_in;
            end if;

            -- Threshold gate
            if s6_gradient > s_threshold then
                s7_gradient <= s6_gradient;
            else
                s7_gradient <= (others => '0');
            end if;
            s7_solar_y <= s6_solar_y;

            -- ================================================================
            -- Stage 8: Mackie gain multiply (register raw product)
            -- ================================================================
            v_mackie_raw  := s7_gradient * s_mackie_gain;
            s8_mackie_raw <= v_mackie_raw;
            s8_solar_y    <= s7_solar_y;
            s8_solar_u    <= s7_solar_u;
            s8_solar_v    <= s7_solar_v;

            -- ================================================================
            -- Stage 9: Mackie clamp + IIR width spread
            -- ================================================================
            v_mackie_val := s8_mackie_raw(2 * C_VIDEO_DATA_WIDTH - 1 downto C_VIDEO_DATA_WIDTH);
            if v_mackie_val > to_unsigned(512, C_VIDEO_DATA_WIDTH) then
                v_mackie_val := to_unsigned(512, C_VIDEO_DATA_WIDTH);
            end if;

            v_alpha     := s_mackie_width(C_VIDEO_DATA_WIDTH - 1 downto C_VIDEO_DATA_WIDTH - 4);
            v_inv_alpha := to_unsigned(16, 5) - resize(v_alpha, 5);
            v_blend_a   := v_alpha * s_mackie_prev;
            v_blend_b   := v_inv_alpha * v_mackie_val;
            v_blend_sum := resize(v_blend_a, 15) + v_blend_b;
            s9_mackie_y   <= v_blend_sum(13 downto 4);
            s_mackie_prev <= v_blend_sum(13 downto 4);
            s9_solar_y    <= s8_solar_y;
            s9_solar_u    <= s8_solar_u;
            s9_solar_v    <= s8_solar_v;

            -- ================================================================
            -- Stage 10: Additive overlay
            -- ================================================================
            v_overlay_int := to_integer(s9_solar_y) + to_integer(s9_mackie_y);
            if v_overlay_int > 1023 then
                s10_overlay_y <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                s10_overlay_y <= to_unsigned(v_overlay_int, C_VIDEO_DATA_WIDTH);
            end if;
            s10_overlay_u <= s9_solar_u;
            s10_overlay_v <= s9_solar_v;

            -- ================================================================
            -- Stage 11: Metallic tint multiply
            -- ================================================================
            if s_metallic = '1' then
                v_tint_k := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
            else
                v_tint_k := resize(shift_right(s_tint, 2), C_VIDEO_DATA_WIDTH);
            end if;
            v_tint_prod := v_tint_k * s10_overlay_y;
            s11_tint_shift <= v_tint_prod(2 * C_VIDEO_DATA_WIDTH - 1 downto C_VIDEO_DATA_WIDTH + 2);
            s11_y <= s10_overlay_y;
            s11_u <= s10_overlay_u;
            s11_v <= s10_overlay_v;

            -- ================================================================
            -- Stage 12: Tint add/subtract + clamp (proc output complete)
            -- ================================================================
            s_proc_y <= s11_y;

            v_u_int := to_integer(s11_u) + to_integer(s11_tint_shift);
            v_v_int := to_integer(s11_v) - to_integer(s11_tint_shift);
            s_proc_u <= fn_clamp_int_to_u(v_u_int, 10);
            s_proc_v <= fn_clamp_int_to_u(v_v_int, 10);
            s_proc_valid <= '1';
        end if;
    end process;

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

end sabattier;
