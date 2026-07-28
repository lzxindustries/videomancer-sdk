-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: colorbars.vhd - Colorbars Program for Videomancer
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
--   Colorbars
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Reference color bar test pattern generator with two modes:
--   - EBU: 8 full-field vertical bars (W, Y, C, G, M, R, B, K) at 75/100%.
--   - SMPTE: 7-bar top section, castellation middle, PLUGE bottom with
--     -I, White, +Q patches and 3.5/7.5/11.5 IRE calibration bars.
--   Blue-only mode for monitor chroma calibration.  Monochrome mode
--   strips chroma.  Bypass switch for hard A/B comparison with input.
--   Resolution auto-measured from timing signals.
--
--   0 BRAM.  ~200 LUTs (estimated).
--
-- Pipeline:
--   2 clk : timing edge detection (video_timing_generator)
--   1 clk : resolution measurement + DDA bar index + section detection
--   1 clk : YUV lookup (pattern / section / level)
--   1 clk : blue-only / mono post-processing
--   1 clk : sync & data delay shift
--   3 clk : IO alignment with bypass mux
--   Total: 8 clocks
--
-- Parameters:
--   Pot 1  (registers_in(0))    : unused
--   Pot 2  (registers_in(1))    : unused
--   Pot 3  (registers_in(2))    : unused
--   Pot 4  (registers_in(3))    : unused
--   Pot 5  (registers_in(4))    : unused
--   Pot 6  (registers_in(5))    : unused
--   Tog 7  (registers_in(6)(0)) : 75% / 100% amplitude
--   Tog 8  (registers_in(6)(1)) : EBU / SMPTE pattern
--   Tog 9  (registers_in(6)(2)) : Blue Only (off / on)
--   Tog 10 (registers_in(6)(3)) : Mono (color / monochrome)
--   Tog 11 (registers_in(6)(4)) : Bypass (bars / input pass-through)
--   Fader  (registers_in(7))    : unused
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture colorbars of program_top is

    -- ========================================================================
    -- Constants
    -- ========================================================================
    constant C_CHROMA_MID : unsigned(9 downto 0) := to_unsigned(512, 10);

    -- ========================================================================
    -- Color Bar YUV LUTs — 8 entries (W, Y, C, G, M, R, B, K)
    -- ========================================================================
    type t_bar_lut is array(0 to 7) of integer range 0 to 1023;

    -- 75% amplitude (BT.601 full-range 10-bit)
    constant C_Y_75  : t_bar_lut := ( 767,  680,  538,  450,  317,  229,   88,    0);
    constant C_U_75  : t_bar_lut := ( 512,  128,  642,  258,  766,  382,  896,  512);
    constant C_V_75  : t_bar_lut := ( 512,  574,  128,  190,  834,  896,  450,  512);

    -- 100% amplitude (BT.601 full-range 10-bit)
    constant C_Y_100 : t_bar_lut := (1023,  906,  717,  601,  422,  306,  117,    0);
    constant C_U_100 : t_bar_lut := ( 512,    0,  685,  173,  851,  339, 1023,  512);
    constant C_V_100 : t_bar_lut := ( 512,  595,    0,   83,  941, 1023,  429,  512);

    -- Blue-only Y values (pre-computed: B = Y + 1.772 * (Cb - 512))
    constant C_BLUE_Y_75  : t_bar_lut := ( 767,    0,  767,    0,  767,    0,  767,    0);
    constant C_BLUE_Y_100 : t_bar_lut := (1023,    0, 1023,    0, 1023,    0, 1023,    0);

    -- ========================================================================
    -- SMPTE Castellation Index Map
    --   Top bars:  W    Y    C    G    M    R    B
    --   Mid cast:  B   Blk   M   Blk   C   Blk   W
    -- ========================================================================
    type t_cast_map is array(0 to 7) of integer range 0 to 7;
    constant C_CASTELLATION_MAP : t_cast_map := (6, 7, 4, 7, 2, 7, 0, 7);

    -- ========================================================================
    -- SMPTE PLUGE Bottom Section YUV — 8 entries (index 7 = black fallback)
    --   -I, White, +Q, Black, 3.5 IRE, 7.5 IRE, 11.5 IRE, Black
    -- ========================================================================
    constant C_PLUGE_Y      : t_bar_lut := (  77, 1023,   77,    0,   36,   77,  118,    0);
    constant C_PLUGE_U      : t_bar_lut := ( 576,  512,  448,  512,  512,  512,  512,  512);
    constant C_PLUGE_V      : t_bar_lut := ( 466,  512,  558,  512,  512,  512,  512,  512);
    constant C_PLUGE_BLUE_Y : t_bar_lut := ( 190, 1023,    0,    0,   36,   77,  118,    0);

    -- ========================================================================
    -- Parameters
    -- ========================================================================
    signal s_level_100     : std_logic;   -- '0'=75%, '1'=100%
    signal s_smpte         : std_logic;   -- '0'=EBU full-field, '1'=SMPTE+PLUGE
    signal s_blue_only     : std_logic;   -- '0'=normal, '1'=blue channel only
    signal s_mono          : std_logic;   -- '0'=color, '1'=monochrome
    signal s_bypass        : std_logic;   -- '0'=bars, '1'=input pass-through

    -- ========================================================================
    -- Timing
    -- ========================================================================
    signal s_timing : t_video_timing_port;

    -- ========================================================================
    -- Horizontal Resolution (auto-measured)
    -- ========================================================================
    signal s_h_pixel_counter : unsigned(11 downto 0) := (others => '0');
    signal s_measured_h      : unsigned(11 downto 0) := to_unsigned(960, 12);

    -- ========================================================================
    -- Vertical Resolution (auto-measured) & Section Detection
    -- ========================================================================
    signal s_v_line_counter  : unsigned(11 downto 0) := (others => '0');
    signal s_measured_v      : unsigned(11 downto 0) := to_unsigned(240, 12);
    signal s_smpte_mid_start : unsigned(11 downto 0) := to_unsigned(158, 12);
    signal s_smpte_bot_start : unsigned(11 downto 0) := to_unsigned(180, 12);
    signal s_section         : unsigned(1 downto 0) := "00";

    -- ========================================================================
    -- DDA Bar Index
    -- ========================================================================
    signal s_num_bars  : unsigned(3 downto 0);
    signal s_dda_accum : unsigned(14 downto 0) := (others => '0');
    signal s_bar_index : integer range 0 to 7 := 0;

    -- ========================================================================
    -- Render Pipeline
    -- ========================================================================
    signal s_render_y        : unsigned(9 downto 0) := (others => '0');
    signal s_render_u        : unsigned(9 downto 0) := C_CHROMA_MID;
    signal s_render_v        : unsigned(9 downto 0) := C_CHROMA_MID;
    signal s_render_is_pluge : std_logic := '0';
    signal s_render_idx      : integer range 0 to 7 := 0;
    signal s_out_y           : unsigned(9 downto 0) := (others => '0');
    signal s_out_u           : unsigned(9 downto 0) := C_CHROMA_MID;
    signal s_out_v           : unsigned(9 downto 0) := C_CHROMA_MID;

    -- ========================================================================
    -- Sync & Data Delay Pipelines
    --   5 sync + 3 IO align = 8 total (div-4)
    --   5 data delay (for bypass) + 3 IO align = 8 total
    -- ========================================================================
    constant C_DATA_DELAY : integer := 5;
    constant C_SYNC_DELAY : integer := 5;

    type t_sync_pipe is array(0 to C_SYNC_DELAY - 1) of std_logic_vector(3 downto 0);
    signal s_sync_pipe : t_sync_pipe := (others => (others => '0'));

    type t_data_delay is array(0 to C_DATA_DELAY - 1) of std_logic_vector(9 downto 0);
    signal s_y_delay : t_data_delay := (others => (others => '0'));
    signal s_u_delay : t_data_delay := (others => (others => '0'));
    signal s_v_delay : t_data_delay := (others => (others => '0'));

    -- IO alignment registers (3 stages)
    signal s_io_0 : t_video_stream_yuv444_30b;
    signal s_io_1 : t_video_stream_yuv444_30b;
    signal s_io_2 : t_video_stream_yuv444_30b;

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_level_100    <= registers_in(6)(0);
    s_smpte        <= registers_in(6)(1);
    s_blue_only    <= registers_in(6)(2);
    s_mono         <= registers_in(6)(3);
    s_bypass       <= registers_in(6)(4);

    -- Bar count: 8 for EBU, 7 for SMPTE
    s_num_bars <= to_unsigned(8, 4) when s_smpte = '0' else to_unsigned(7, 4);

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
    -- Auto-Measure Resolution & Vertical Section Detection
    -- ========================================================================
    p_measure : process(clk)
    begin
        if rising_edge(clk) then
            -- Horizontal measurement
            if s_timing.hsync_start = '1' then
                if s_h_pixel_counter > 0 then
                    s_measured_h <= s_h_pixel_counter;
                end if;
                s_h_pixel_counter <= (others => '0');
            elsif s_timing.avid = '1' then
                s_h_pixel_counter <= s_h_pixel_counter + 1;
            end if;

            -- Vertical measurement & SMPTE section thresholds
            if s_timing.vsync_start = '1' then
                if s_v_line_counter > 0 then
                    s_measured_v <= s_v_line_counter;
                    -- Mid start ~ 2/3 = (1/2 + 1/8 + 1/32) ~ 65.6%
                    s_smpte_mid_start <= resize(s_v_line_counter(11 downto 1), 12)
                                       + resize(s_v_line_counter(11 downto 3), 12)
                                       + resize(s_v_line_counter(11 downto 5), 12);
                    -- Bot start = 3/4 = (1/2 + 1/4) = 75%
                    s_smpte_bot_start <= resize(s_v_line_counter(11 downto 1), 12)
                                       + resize(s_v_line_counter(11 downto 2), 12);
                end if;
                s_v_line_counter <= (others => '0');
            elsif s_timing.avid_start = '1' then
                -- Section detection for current line
                if s_v_line_counter >= s_smpte_bot_start then
                    s_section <= "10";  -- Bottom (PLUGE)
                elsif s_v_line_counter >= s_smpte_mid_start then
                    s_section <= "01";  -- Middle (castellations)
                else
                    s_section <= "00";  -- Top (standard bars)
                end if;
                s_v_line_counter <= s_v_line_counter + 1;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- DDA Bar Index Calculation
    -- ========================================================================
    -- Divides the active line into N equal bars (8 for EBU, 7 for SMPTE)
    -- using a DDA accumulator that avoids division.
    p_bar_dda : process(clk)
        variable v_next_accum : unsigned(14 downto 0);
        variable v_max_idx    : integer range 0 to 7;
    begin
        if rising_edge(clk) then
            if s_smpte = '0' then
                v_max_idx := 7;
            else
                v_max_idx := 6;
            end if;

            if s_timing.avid_start = '1' then
                s_dda_accum <= (others => '0');
                s_bar_index <= 0;
            elsif s_timing.avid = '1' then
                v_next_accum := s_dda_accum + resize(s_num_bars, 15);
                if v_next_accum >= resize(s_measured_h, 15) then
                    v_next_accum := v_next_accum - resize(s_measured_h, 15);
                    if s_bar_index < v_max_idx then
                        s_bar_index <= s_bar_index + 1;
                    end if;
                end if;
                s_dda_accum <= v_next_accum;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Render Pipeline
    -- ========================================================================
    p_render : process(clk)
        variable v_lut_idx : integer range 0 to 7;
    begin
        if rising_edge(clk) then
            -- ==============================================================
            -- Stage 1: YUV Lookup
            -- ==============================================================
            -- Determine effective LUT index
            if s_smpte = '0' then
                -- EBU mode: direct bar index (0-7 including black)
                v_lut_idx := s_bar_index;
                s_render_is_pluge <= '0';
            else
                -- SMPTE mode: section-dependent
                case s_section is
                    when "01" =>
                        -- Middle: castellations (remapped)
                        if s_bar_index <= 6 then
                            v_lut_idx := C_CASTELLATION_MAP(s_bar_index);
                        else
                            v_lut_idx := 7;
                        end if;
                        s_render_is_pluge <= '0';
                    when "10" =>
                        -- Bottom: PLUGE
                        v_lut_idx := s_bar_index;
                        s_render_is_pluge <= '1';
                    when others =>
                        -- Top: standard 7 bars
                        v_lut_idx := s_bar_index;
                        s_render_is_pluge <= '0';
                end case;
            end if;
            s_render_idx <= v_lut_idx;

            -- Look up YUV values from appropriate LUT
            if s_smpte = '1' and s_section = "10" then
                -- PLUGE section
                s_render_y <= to_unsigned(C_PLUGE_Y(v_lut_idx), 10);
                s_render_u <= to_unsigned(C_PLUGE_U(v_lut_idx), 10);
                s_render_v <= to_unsigned(C_PLUGE_V(v_lut_idx), 10);
            else
                -- Standard bars or castellations
                if s_level_100 = '1' then
                    s_render_y <= to_unsigned(C_Y_100(v_lut_idx), 10);
                    s_render_u <= to_unsigned(C_U_100(v_lut_idx), 10);
                    s_render_v <= to_unsigned(C_V_100(v_lut_idx), 10);
                else
                    s_render_y <= to_unsigned(C_Y_75(v_lut_idx), 10);
                    s_render_u <= to_unsigned(C_U_75(v_lut_idx), 10);
                    s_render_v <= to_unsigned(C_V_75(v_lut_idx), 10);
                end if;
            end if;

            -- ==============================================================
            -- Stage 2: Blue-Only / Mono Post-Processing
            --   Reads s_render_* from previous clock (pipeline register)
            -- ==============================================================
            if s_blue_only = '1' then
                -- Blue-only: output pre-computed blue channel as grayscale
                if s_render_is_pluge = '1' then
                    s_out_y <= to_unsigned(C_PLUGE_BLUE_Y(s_render_idx), 10);
                else
                    if s_level_100 = '1' then
                        s_out_y <= to_unsigned(C_BLUE_Y_100(s_render_idx), 10);
                    else
                        s_out_y <= to_unsigned(C_BLUE_Y_75(s_render_idx), 10);
                    end if;
                end if;
                s_out_u <= C_CHROMA_MID;
                s_out_v <= C_CHROMA_MID;
            elsif s_mono = '1' then
                s_out_y <= s_render_y;
                s_out_u <= C_CHROMA_MID;
                s_out_v <= C_CHROMA_MID;
            else
                s_out_y <= s_render_y;
                s_out_u <= s_render_u;
                s_out_v <= s_render_v;
            end if;

            -- ==============================================================
            -- Sync & Data Delay Pipelines
            -- ==============================================================
            s_sync_pipe(0) <= data_in.field_n & data_in.avid &
                              data_in.vsync_n & data_in.hsync_n;
            for i in 1 to C_SYNC_DELAY - 1 loop
                s_sync_pipe(i) <= s_sync_pipe(i - 1);
            end loop;

            s_y_delay(0) <= data_in.y;
            s_u_delay(0) <= data_in.u;
            s_v_delay(0) <= data_in.v;
            for i in 1 to C_DATA_DELAY - 1 loop
                s_y_delay(i) <= s_y_delay(i - 1);
                s_u_delay(i) <= s_u_delay(i - 1);
                s_v_delay(i) <= s_v_delay(i - 1);
            end loop;
        end if;
    end process;

    -- ========================================================================
    -- IO Alignment / Bypass Mux (3 stages: total 5+3=8, divisible by 4)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 0: bypass mux
            if s_bypass = '1' then
                s_io_0.y <= s_y_delay(C_DATA_DELAY - 1);
                s_io_0.u <= s_u_delay(C_DATA_DELAY - 1);
                s_io_0.v <= s_v_delay(C_DATA_DELAY - 1);
            else
                s_io_0.y <= std_logic_vector(s_out_y);
                s_io_0.u <= std_logic_vector(s_out_u);
                s_io_0.v <= std_logic_vector(s_out_v);
            end if;
            s_io_0.hsync_n <= s_sync_pipe(C_SYNC_DELAY - 1)(0);
            s_io_0.vsync_n <= s_sync_pipe(C_SYNC_DELAY - 1)(1);
            s_io_0.avid    <= s_sync_pipe(C_SYNC_DELAY - 1)(2);
            s_io_0.field_n <= s_sync_pipe(C_SYNC_DELAY - 1)(3);
            -- Stages 1-2
            s_io_1 <= s_io_0;
            s_io_2 <= s_io_1;
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment
    -- ========================================================================
    -- Gate to studio blanking outside the (sync-pipe-delayed) AVID:
    -- the bar generator renders from its own counters.
    data_out.y       <= s_io_2.y when s_io_2.avid = '1'
                        else std_logic_vector(to_unsigned(64, s_io_2.y'length));
    data_out.u       <= s_io_2.u when s_io_2.avid = '1'
                        else std_logic_vector(to_unsigned(512, s_io_2.u'length));
    data_out.v       <= s_io_2.v when s_io_2.avid = '1'
                        else std_logic_vector(to_unsigned(512, s_io_2.v'length));
    data_out.avid    <= s_io_2.avid;
    data_out.hsync_n <= s_io_2.hsync_n;
    data_out.vsync_n <= s_io_2.vsync_n;
    data_out.field_n <= s_io_2.field_n;

end architecture colorbars;
