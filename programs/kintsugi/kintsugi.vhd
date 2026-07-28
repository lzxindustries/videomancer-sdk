-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: kintsugi.vhd - Kintsugi Program for Videomancer
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
--   Kintsugi
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Gold crack-repair lines along detected edges, inspired by the
--   Japanese art of kintsugi (gold repair of broken pottery).
--
--   Multi-dimensional edge detection:
--     Horizontal: abs(Y[n] - Y[n-1]) for vertical cracks
--     Vertical:   abs(Y[x,line] - Y[x,prev_line]) via BRAM line buffer
--     Lookback:   abs(Y[n] - Y[n-8]) for diagonal/textural edges
--     Chroma:     max(abs(U[n]-U[n-1]), abs(V[n]-V[n-1])) for color edges
--   Toggle 7 selects horizontal-only (Off) or full multi-dimensional (On).
--
--   Where edge delta > threshold, a "gold" line is drawn: bright Y
--   with warm UV (orange/gold tint).  Configurable gold vs platinum mode,
--   line brightness, and Halo (graduated glow) vs Shatter (solid fill).
--
--   Non-edge pixels ("shards") can be darkened via Balance
--   and/or replaced with a 2D emboss relief texture (using both horizontal
--   and vertical deltas) via the Emboss toggle.  Patina mode applies
--   luma-dependent green oxidation tint (darker areas receive stronger
--   green shift for a realistic aged-metal effect).
--
--   Edge persistence: previous-line edge map stored in BRAM enables
--   vertical fill thickness, producing uniform 2D crack width.
--
--   Gold brightness receives per-pixel LFSR dither for organic texture.
--   Warmth values oscillate on a per-frame triangle wave via a phase
--   accumulator, with asymmetric U/V offsets (V ~1.5x U) for authentic
--   gold chromaticity.
--
--   Gold color: Y~900, U~450 (below neutral), V~620 (warm amber)
--   Platinum color: Y~900, U~650 (above neutral), V~370 (cool blue/silver)
--
-- Resources:
--   2 BRAM (video_line_buffer for previous-line Y, dual-bank)
--   1-2 BRAM (video_line_buffer for previous-line edge persistence)
--   ~5000 LUTs (edge detection, threshold compare, gold tint,
--               sync delay, pipelined proc amp darken, 2D emboss,
--               chroma edge detect, vertical edge detect, patina,
--               LFSR dither, frame phase animation, compose delay chain)
--   3x interpolator_u (wet/dry mix per channel)
--   1x proc_amp_u (pipelined non-edge Y darkening via Radix-4 Booth multiplier)
--   1x video_line_buffer (previous-line Y for vertical edge detection)
--   1x video_line_buffer (previous-line edge for vertical fill persistence)
--   1x video_timing_generator
--   1x lfsr (gold brightness dither)
--   1x frame_phase_accumulator (warmth animation)
--
-- Pipeline:
--   1 clk  : input register + delay tap latch
--   1 clk  : horizontal + lookback abs delta compute
--   1 clk  : vertical delta + threshold comparisons + soft edge threshold
--   1 clk  : edge combine + fill counter + fade shift + vertical persistence
--   1 clk  : pre-compose (2D emboss, dithered gold target, patina amount)
--   1 clk  : apply compose (Y blend, chroma blend, patina)
--   9 clk  : proc amp alignment delay (matches pipelined multiplier latency)
--   1 clk  : final select (proc amp Y vs edge Y) + output register
--   4 clk  : interpolator_u (wet/dry mix)
--   4 clk  : crack centering offset (sync delay only)
--   Total: 24 clocks (sync delay); 20 clocks (wet path)
--
-- Parameters:
--   Texture controls (P1-P3):
--   Pot 1  (registers_in(0))  : Sensitivity      -- edge detection threshold
--   Pot 2  (registers_in(1))  : Crack Density     -- vertical/lookback/chroma edge sensitivity
--   Pot 3  (registers_in(2))  : Line Thickness    -- glow width (Halo) or fill width (Shatter)
--   Color controls (P4-P6):
--   Pot 4  (registers_in(3))  : Tone              -- gold: warm amber tint; platinum: cool blue tint
--   Pot 5  (registers_in(4))  : Gold Brightness   -- intensity of gold/platinum line
--   Pot 6  (registers_in(5))  : Balance           -- shadow depth on non-edge shards
--   Tog 7  (registers_in(6)(0)) : Glow (0=H-only, 1=H+V+chroma multi-dimensional)
--   Tog 8  (registers_in(6)(1)) : Cracks (0=Halo/graduated glow, 1=Shatter/solid fill)
--   Tog 9  (registers_in(6)(2)) : Metal (0=gold, 1=platinum)
--   Tog 10 (registers_in(6)(3)) : Emboss (0=normal source, 1=relief texture on shards)
--   Tog 11 (registers_in(6)(4)) : Patina (0=off, 1=luma-dependent green oxidation)
--   Fader  (registers_in(7))  : Mix (dry/wet crossfade)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture kintsugi of program_top is

    -- 16 processing stages + 4 interpolator + 4 crack centering = 24 total
    -- The extra 4 clocks shift the sync/dry path rightward so that
    -- cracks appear centered on the detected edge rather than starting
    -- entirely to the right of it.
    constant C_CRACK_CENTERING   : integer := 4;
    -- interpolator_u pipeline depth (see dsp/interpolator.vhd): the dry
    -- video passes through the mix interpolators after the delay chain,
    -- so sync must be delayed by this much extra to stay co-timed.
    constant C_MIX_LATENCY_CLKS  : integer := 4;
    -- Total program_top data latency: dry chain + crack centering + mix.
    constant C_PROCESSING_DELAY_CLKS : integer := 24 + C_CRACK_CENTERING;
    -- Dry-data tap: mix latency shorter than the sync tap, so that
    -- data-through-mix and sync arrive at data_out together.
    constant C_DRY_TAP : integer := C_PROCESSING_DELAY_CLKS - C_MIX_LATENCY_CLKS;

    -- Line buffer depth (2^11 = 2048 pixels per line)
    constant C_LINE_DEPTH : integer := 11;

    -- Lookback depth for diagonal/textural edge detection
    constant C_LOOKBACK_DEPTH : integer := 8;

    -- Chroma midpoint
    constant C_CHROMA_MID : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        to_unsigned(512, C_VIDEO_DATA_WIDTH);

    -- ========================================================================
    -- Parameter signals
    -- ========================================================================
    signal s_edge_thresh    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_gold_bright    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_line_width     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_color_warmth   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_sensitivity    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_balance        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_edge_mode      : std_logic;
    signal s_fill_style     : std_logic;
    signal s_color_sel      : std_logic;  -- 0=gold, 1=platinum
    signal s_emboss_en      : std_logic;
    signal s_patina         : std_logic;
    signal s_mix_amount     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Timing
    -- ========================================================================
    signal s_timing         : t_video_timing_port;

    -- ========================================================================
    -- LFSR and phase accumulator
    -- ========================================================================
    signal s_lfsr_out       : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_phase          : unsigned(15 downto 0);

    -- ========================================================================
    -- Derived parameters (pre-registered)
    -- ========================================================================
    signal s_h_thresh       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_lb_thresh      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_bright_val     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_width_thresh   : unsigned(5 downto 0);
    signal s_warmth_u       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_warmth_v       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Line buffer signals
    -- ========================================================================
    signal s_prev_avid      : std_logic := '0';
    signal s_prev_hsync_n   : std_logic := '1';
    signal s_prev_vsync_n   : std_logic := '1';
    signal s_lb_wr_addr     : unsigned(C_LINE_DEPTH - 1 downto 0) := (others => '0');
    signal s_lb_ab          : std_logic := '0';
    signal s_lb_y_out       : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_edge_wr_data   : std_logic_vector(0 downto 0) := "0";
    signal s_edge_rd_data   : std_logic_vector(0 downto 0);
    signal s_prev_line_edge_d1 : std_logic := '0';
    signal s_prev_line_edge : std_logic := '0';

    -- ========================================================================
    -- Edge detection delay registers
    -- ========================================================================
    signal s_y_prev         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_u_prev         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_v_prev         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    type t_luma_sr is array (0 to C_LOOKBACK_DEPTH - 1)
        of unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_y_lookback     : t_luma_sr := (others => (others => '0'));

    -- ========================================================================
    -- Pipeline Stage 1: Input register + delay tap latch
    -- ========================================================================
    signal s_y_s1           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_s1           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_s1           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_y_prev_s1      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_prev_s1      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_prev_s1      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_y_lb_s1        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_avid_s1        : std_logic := '0';

    -- ========================================================================
    -- Pipeline Stage 2: Horizontal + lookback absolute deltas
    -- ========================================================================
    signal s_y_s2           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_s2           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_s2           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_h_delta_y      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_h_delta_u      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_h_delta_v      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_lb_delta       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_avid_s2        : std_logic := '0';

    -- ========================================================================
    -- Pipeline Stage 3: Vertical delta + pairwise max + threshold comparisons
    -- ========================================================================
    signal s_y_s3           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_s3           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_s3           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_h_delta_y_s3   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_is_h_edge      : std_logic;
    signal s_is_lb_edge     : std_logic;
    signal s_is_v_edge      : std_logic;
    signal s_is_chroma_edge : std_logic;
    signal s_is_soft_edge   : std_logic;
    signal s_v_delta_s3     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_avid_s3        : std_logic := '0';

    -- ========================================================================
    -- Pipeline Stage 4: Edge combine + fill counter + fade shift
    -- ========================================================================
    signal s_y_s4           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_s4           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_s4           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_h_delta_y_s4   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_is_edge        : std_logic;
    signal s_fade_shift     : natural range 0 to 5 := 0;
    signal s_fill_counter   : unsigned(5 downto 0) := (others => '0');
    signal s_emboss_max_s4  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_edge_trigger   : std_logic := '0';

    -- ========================================================================
    -- Pipeline Stage 5: Pre-compose (intermediates for compose stage)
    -- ========================================================================
    -- Common
    signal s_is_edge_s5     : std_logic;
    signal s_fade_shift_s5  : natural range 0 to 5 := 0;
    signal s_y_s5           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_s5           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_s5           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    -- Edge path: gold target and Y difference
    signal s_gold_u_s5      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_gold_v_s5      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_y_diff_s5      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_y_diff_pos_s5  : std_logic;  -- '1' if gold > source Y
    -- Non-edge path: proc amp + patina
    signal s_base_y_s5      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_patina_amt_s5  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- Pipeline Stage 6: Apply compose
    -- ========================================================================
    signal s_comp_y_s6      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_comp_u_s6      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_comp_v_s6      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_is_edge_s6     : std_logic;

    -- ========================================================================
    -- Proc Amp — pipelined balance for non-edge ceramic shards
    -- ========================================================================
    constant C_PROC_AMP_DELAY : integer := 9;  -- Alignment delay stages
    signal s_proc_contrast    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_amp_result  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_amp_valid   : std_logic;

    -- ========================================================================
    -- Pipeline Stages 7-15: Compose alignment delay chain
    -- ========================================================================
    type t_compose_delay is array (0 to C_PROC_AMP_DELAY - 1)
        of unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_delay_comp_y   : t_compose_delay;
    signal s_delay_comp_u   : t_compose_delay;
    signal s_delay_comp_v   : t_compose_delay;
    signal s_delay_is_edge  : std_logic_vector(C_PROC_AMP_DELAY - 1 downto 0);

    -- ========================================================================
    -- Pipeline Stage 16: Output register (final select)
    -- ========================================================================
    signal s_comp_y         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_comp_u         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_comp_v         : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_comp_valid     : std_logic;

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
    signal s_hsync_n_d      : std_logic;
    signal s_vsync_n_d      : std_logic;
    signal s_field_n_d      : std_logic;
    signal s_avid_d         : std_logic := '0';
    signal s_y_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_d            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    -- Texture controls: P1-P3 (registers_in 0-2)
    -- Color controls:   P4-P6 (registers_in 3-5)
    s_edge_thresh    <= unsigned(registers_in(0));
    s_sensitivity    <= unsigned(registers_in(1));
    s_line_width     <= unsigned(registers_in(2));
    s_color_warmth   <= unsigned(registers_in(3));
    s_gold_bright    <= unsigned(registers_in(4));
    s_balance        <= unsigned(registers_in(5));
    s_edge_mode      <= registers_in(6)(0);
    s_fill_style     <= registers_in(6)(1);
    s_color_sel      <= registers_in(6)(2);
    s_emboss_en      <= registers_in(6)(3);
    s_patina         <= registers_in(6)(4);
    s_mix_amount     <= unsigned(registers_in(7));

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
    -- Parameter Pre-Registration
    -- ========================================================================
    p_param_derive : process(clk)
        variable v_anim_offset : unsigned(3 downto 0);
    begin
        if rising_edge(clk) then
            -- Horizontal edge threshold: map 0-1023 to 8-264
            -- Invert: high pot value = low threshold = more edges
            s_h_thresh <= to_unsigned(264, C_VIDEO_DATA_WIDTH)
                        - shift_right(s_edge_thresh, 2);

            -- Secondary threshold for lookback/vertical/chroma edges
            s_lb_thresh <= to_unsigned(264, C_VIDEO_DATA_WIDTH)
                         - shift_right(s_sensitivity, 2);

            -- Gold brightness target
            s_bright_val <= s_gold_bright;

            -- Width threshold for fill mode (0..63)
            -- Pot 0 = 0 extra fill pixels (1px edge only)
            -- Pot 1023 = 63 extra fill pixels (super thick)
            s_width_thresh <= resize(shift_right(s_line_width, 4), 6);

            -- Warmth animation: triangle wave from frame phase accumulator
            if s_phase(15) = '0' then
                v_anim_offset := s_phase(14 downto 11);
            else
                v_anim_offset := not s_phase(14 downto 11);
            end if;

            -- Asymmetric warmth offsets (V ~1.5x U for authentic gold)
            -- with per-frame phase animation (subtle cyclic oscillation)
            s_warmth_u <= shift_right(s_color_warmth, 3)
                        + resize(v_anim_offset, C_VIDEO_DATA_WIDTH);
            s_warmth_v <= shift_right(s_color_warmth, 3)
                        + shift_right(s_color_warmth, 4)
                        + resize(v_anim_offset, C_VIDEO_DATA_WIDTH);

            -- Proc amp contrast: balance=0 → unity (512), balance=1023 → near-zero (1)
            s_proc_contrast <= to_unsigned(512, C_VIDEO_DATA_WIDTH)
                             - shift_right(s_balance, 1);
        end if;
    end process;

    -- ========================================================================
    -- Position Counters (for line buffer addressing)
    -- ========================================================================
    p_position_counters : process(clk)
    begin
        if rising_edge(clk) then
            s_prev_avid    <= data_in.avid;
            s_prev_hsync_n <= data_in.hsync_n;
            s_prev_vsync_n <= data_in.vsync_n;

            -- Pixel counter: increments during active video
            if data_in.avid = '1' then
                if s_prev_avid = '0' then
                    s_lb_wr_addr <= (others => '0');
                else
                    s_lb_wr_addr <= s_lb_wr_addr + 1;
                end if;
            end if;

            -- Line toggle: alternates each scanline, resets each field
            if data_in.vsync_n = '0' and s_prev_vsync_n = '1' then
                s_lb_ab <= '0';
            elsif data_in.hsync_n = '0' and s_prev_hsync_n = '1' then
                s_lb_ab <= not s_lb_ab;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Line Buffer — previous line Y for vertical edge detection
    -- ========================================================================
    lb_y_inst : entity work.video_line_buffer
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_DEPTH => C_LINE_DEPTH)
        port map(
            clk       => clk,
            i_ab      => s_lb_ab,
            i_wr_addr => s_lb_wr_addr,
            i_rd_addr => s_lb_wr_addr,
            i_data    => data_in.y,
            o_data    => s_lb_y_out
        );

    -- ========================================================================
    -- Edge Line Buffer — previous-line edge for vertical fill persistence
    -- ========================================================================
    s_edge_wr_data(0) <= s_edge_trigger;

    lb_edge_inst : entity work.video_line_buffer
        generic map(G_WIDTH => 1, G_DEPTH => C_LINE_DEPTH)
        port map(
            clk       => clk,
            i_ab      => s_lb_ab,
            i_wr_addr => s_lb_wr_addr,
            i_rd_addr => s_lb_wr_addr,
            i_data    => s_edge_wr_data,
            o_data    => s_edge_rd_data
        );

    -- ========================================================================
    -- LFSR — gold brightness dither for organic texture
    -- ========================================================================
    lfsr_inst : entity work.lfsr
        generic map(G_DATA_WIDTH => C_VIDEO_DATA_WIDTH)
        port map(
            clk      => clk,
            reset    => '0',
            enable   => '1',
            seed     => std_logic_vector(to_unsigned(683, C_VIDEO_DATA_WIDTH)),
            poly     => std_logic_vector(to_unsigned(129, C_VIDEO_DATA_WIDTH)),
            lfsr_out => s_lfsr_out
        );

    -- ========================================================================
    -- Frame Phase Accumulator — warmth animation
    -- ========================================================================
    phase_inst : entity work.frame_phase_accumulator
        generic map(G_PHASE_WIDTH => 16, G_SPEED_WIDTH => C_VIDEO_DATA_WIDTH)
        port map(
            clk     => clk,
            vsync_n => data_in.vsync_n,
            enable  => '1',
            speed   => s_color_warmth,
            phase   => s_phase
        );

    -- ========================================================================
    -- Proc Amp — pipelined contrast/brightness on non-edge (darken) Y
    -- Latency: 10 data cycles (matches (G_WIDTH+3)/2 + 4 for G_WIDTH=10)
    -- ========================================================================
    proc_amp_inst : entity work.proc_amp_u
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH)
        port map(
            clk        => clk,
            enable     => '1',
            a          => s_base_y_s5,
            contrast   => s_proc_contrast,
            brightness => C_CHROMA_MID,
            result     => s_proc_amp_result,
            valid      => s_proc_amp_valid
        );

    -- ========================================================================
    -- Edge Detection Delay Registers
    -- ========================================================================
    p_edge_delay : process(clk)
    begin
        if rising_edge(clk) then
            -- 1-clock delay for horizontal edge detection
            s_y_prev <= unsigned(data_in.y);
            s_u_prev <= unsigned(data_in.u);
            s_v_prev <= unsigned(data_in.v);

            -- Lookback shift register (luma only)
            s_y_lookback(0) <= unsigned(data_in.y);
            for i in 1 to C_LOOKBACK_DEPTH - 1 loop
                s_y_lookback(i) <= s_y_lookback(i - 1);
            end loop;
        end if;
    end process;

    -- ========================================================================
    -- Processing Pipeline
    -- ========================================================================
    p_pipeline : process(clk)
        variable v_v_delta      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_max_chroma   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_edge_on      : std_logic;
        variable v_gold_u       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_gold_v       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_base_y       : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_patina_amt   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_y_shifted    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_blend_y      : unsigned(C_VIDEO_DATA_WIDTH downto 0);
        variable v_patina_v     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_bright_dithered : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    begin
        if rising_edge(clk) then

            -- ================================================================
            -- Stage 1: Input register + delay tap latch
            -- ================================================================
            s_y_s1 <= unsigned(data_in.y);
            s_u_s1 <= unsigned(data_in.u);
            s_v_s1 <= unsigned(data_in.v);
            s_y_prev_s1 <= s_y_prev;
            s_u_prev_s1 <= s_u_prev;
            s_v_prev_s1 <= s_v_prev;
            s_y_lb_s1   <= s_y_lookback(C_LOOKBACK_DEPTH - 1);
            s_avid_s1   <= data_in.avid;

            -- ================================================================
            -- Stage 2: Horizontal + lookback absolute deltas
            -- ================================================================
            s_y_s2 <= s_y_s1;
            s_u_s2 <= s_u_s1;
            s_v_s2 <= s_v_s1;
            s_avid_s2 <= s_avid_s1;

            -- |dY horizontal|
            if s_y_s1 >= s_y_prev_s1 then
                s_h_delta_y <= s_y_s1 - s_y_prev_s1;
            else
                s_h_delta_y <= s_y_prev_s1 - s_y_s1;
            end if;

            -- |dU horizontal|
            if s_u_s1 >= s_u_prev_s1 then
                s_h_delta_u <= s_u_s1 - s_u_prev_s1;
            else
                s_h_delta_u <= s_u_prev_s1 - s_u_s1;
            end if;

            -- |dV horizontal|
            if s_v_s1 >= s_v_prev_s1 then
                s_h_delta_v <= s_v_s1 - s_v_prev_s1;
            else
                s_h_delta_v <= s_v_prev_s1 - s_v_s1;
            end if;

            -- |dY lookback|
            if s_y_s1 >= s_y_lb_s1 then
                s_lb_delta <= s_y_s1 - s_y_lb_s1;
            else
                s_lb_delta <= s_y_lb_s1 - s_y_s1;
            end if;

            -- ================================================================
            -- Stage 3: Vertical delta + threshold comparisons
            -- ================================================================
            s_y_s3 <= s_y_s2;
            s_u_s3 <= s_u_s2;
            s_v_s3 <= s_v_s2;
            s_avid_s3 <= s_avid_s2;
            s_h_delta_y_s3 <= s_h_delta_y;

            -- Vertical delta from line buffer
            -- Line buffer output aligns with s_y_s2 (both 2 clocks behind data_in)
            if s_y_s2 >= unsigned(s_lb_y_out) then
                v_v_delta := s_y_s2 - unsigned(s_lb_y_out);
            else
                v_v_delta := unsigned(s_lb_y_out) - s_y_s2;
            end if;

            -- Chroma max for threshold comparison
            if s_h_delta_u >= s_h_delta_v then
                v_max_chroma := s_h_delta_u;
            else
                v_max_chroma := s_h_delta_v;
            end if;

            -- Threshold comparisons (all in parallel from registered values)
            if s_h_delta_y > s_h_thresh then
                s_is_h_edge <= '1';
            else
                s_is_h_edge <= '0';
            end if;

            if s_lb_delta > s_lb_thresh then
                s_is_lb_edge <= '1';
            else
                s_is_lb_edge <= '0';
            end if;

            if v_v_delta > s_lb_thresh then
                s_is_v_edge <= '1';
            else
                s_is_v_edge <= '0';
            end if;

            if v_max_chroma > s_lb_thresh then
                s_is_chroma_edge <= '1';
            else
                s_is_chroma_edge <= '0';
            end if;

            -- Soft edge threshold (half primary — organic glow fringe)
            if s_h_delta_y > shift_right(s_h_thresh, 1) then
                s_is_soft_edge <= '1';
            else
                s_is_soft_edge <= '0';
            end if;

            -- Register vertical delta for 2D emboss
            s_v_delta_s3 <= v_v_delta;

            -- Edge buffer read delay (first stage)
            s_prev_line_edge_d1 <= s_edge_rd_data(0);

            -- ================================================================
            -- Stage 4: Edge combine + fill counter + fade shift
            -- ================================================================
            s_y_s4 <= s_y_s3;
            s_u_s4 <= s_u_s3;
            s_v_s4 <= s_v_s3;
            s_h_delta_y_s4 <= s_h_delta_y_s3;
            s_prev_line_edge <= s_prev_line_edge_d1;

            -- Pre-compute emboss max delta (avoids comparator in Stage 5)
            if s_h_delta_y_s3 >= s_v_delta_s3 then
                s_emboss_max_s4 <= s_h_delta_y_s3;
            else
                s_emboss_max_s4 <= s_v_delta_s3;
            end if;

            -- Combined edge detection
            v_edge_on := s_is_h_edge or s_is_lb_edge or s_is_soft_edge;
            if s_edge_mode = '1' then
                v_edge_on := v_edge_on or s_is_v_edge or s_is_chroma_edge;
            end if;

            -- Raw edge for line buffer (excludes prev-line feedback)
            s_edge_trigger <= v_edge_on;

            -- Vertical fill persistence from previous line
            v_edge_on := v_edge_on or s_prev_line_edge;

            -- Fill counter with blanking reset
            if s_avid_s3 = '0' then
                s_fill_counter <= (others => '0');
            elsif v_edge_on = '1' then
                s_fill_counter <= s_width_thresh;
            elsif s_fill_counter > 0 then
                s_fill_counter <= s_fill_counter - 1;
            end if;

            -- Final edge decision
            if v_edge_on = '1' then
                s_is_edge <= '1';
            elsif s_fill_counter > 0 then
                s_is_edge <= '1';
            else
                s_is_edge <= '0';
            end if;

            -- Fade shift: controls gold intensity for fill pixels
            if v_edge_on = '1' then
                s_fade_shift <= 1;
            elsif s_fill_style = '1' then
                s_fade_shift <= 1;
            else
                if s_fill_counter >= 36 then
                    s_fade_shift <= 2;
                elsif s_fill_counter >= 24 then
                    s_fade_shift <= 3;
                elsif s_fill_counter >= 12 then
                    s_fade_shift <= 4;
                elsif s_fill_counter >= 1 then
                    s_fade_shift <= 5;
                else
                    s_fade_shift <= 1;
                end if;
            end if;

            -- ================================================================
            -- Stage 5: Pre-compose — prepare intermediates
            -- ================================================================
            s_is_edge_s5    <= s_is_edge;
            s_fade_shift_s5 <= s_fade_shift;
            s_y_s5 <= s_y_s4;
            s_u_s5 <= s_u_s4;
            s_v_s5 <= s_v_s4;

            -- Edge path: gold/platinum target chroma
            if s_color_sel = '0' then
                -- Gold: warm amber tint
                if C_CHROMA_MID > s_warmth_u then
                    v_gold_u := C_CHROMA_MID - s_warmth_u;
                else
                    v_gold_u := (others => '0');
                end if;
                v_gold_v := C_CHROMA_MID + s_warmth_v;
                if v_gold_v > to_unsigned(1023, C_VIDEO_DATA_WIDTH) then
                    v_gold_v := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
                end if;
            else
                -- Platinum: cool blue/silver tint
                v_gold_u := C_CHROMA_MID + s_warmth_u;
                if v_gold_u > to_unsigned(1023, C_VIDEO_DATA_WIDTH) then
                    v_gold_u := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
                end if;
                if C_CHROMA_MID > s_warmth_v then
                    v_gold_v := C_CHROMA_MID - s_warmth_v;
                else
                    v_gold_v := (others => '0');
                end if;
            end if;
            s_gold_u_s5 <= v_gold_u;
            s_gold_v_s5 <= v_gold_v;

            -- Edge path: Y difference for blend with LFSR dither
            v_bright_dithered(C_VIDEO_DATA_WIDTH - 1 downto 3) :=
                s_bright_val(C_VIDEO_DATA_WIDTH - 1 downto 3);
            v_bright_dithered(2 downto 0) :=
                s_bright_val(2 downto 0) xor unsigned(s_lfsr_out(2 downto 0));
            if v_bright_dithered > s_y_s4 then
                s_y_diff_s5 <= v_bright_dithered - s_y_s4;
                s_y_diff_pos_s5 <= '1';
            else
                s_y_diff_s5 <= (others => '0');
                s_y_diff_pos_s5 <= '0';
            end if;

            -- Non-edge path: 2D emboss base Y (max pre-registered in Stage 4)
            if s_emboss_en = '1' then
                if s_emboss_max_s4 > to_unsigned(255, C_VIDEO_DATA_WIDTH) then
                    v_base_y := to_unsigned(1023, C_VIDEO_DATA_WIDTH);
                else
                    v_base_y := shift_left(s_emboss_max_s4, 2);
                end if;
            else
                v_base_y := s_y_s4;
            end if;
            s_base_y_s5 <= v_base_y;

            -- Non-edge path: luma-dependent patina amount
            -- Darker areas get more green oxidation
            v_patina_amt := shift_right(
                to_unsigned(1023, C_VIDEO_DATA_WIDTH) - v_base_y, 3);
            s_patina_amt_s5 <= v_patina_amt;

            -- ================================================================
            -- Stage 6: Apply compose
            -- ================================================================
            if s_is_edge_s5 = '1' then
                -- ============================================================
                -- EDGE PIXEL: Gold/platinum line
                -- ============================================================

                -- Y blend: source + shifted difference (case avoids barrel shifter)
                if s_y_diff_pos_s5 = '1' then
                    case s_fade_shift_s5 is
                        when 1     => v_y_shifted := shift_right(s_y_diff_s5, 1);
                        when 2     => v_y_shifted := shift_right(s_y_diff_s5, 2);
                        when 3     => v_y_shifted := shift_right(s_y_diff_s5, 3);
                        when 4     => v_y_shifted := shift_right(s_y_diff_s5, 4);
                        when 5     => v_y_shifted := shift_right(s_y_diff_s5, 5);
                        when others => v_y_shifted := shift_right(s_y_diff_s5, 1);
                    end case;
                    v_blend_y := ('0' & s_y_s5) + ('0' & v_y_shifted);
                    if v_blend_y > to_unsigned(1023, C_VIDEO_DATA_WIDTH + 1) then
                        s_comp_y_s6 <= to_unsigned(1023, C_VIDEO_DATA_WIDTH);
                    else
                        s_comp_y_s6 <= v_blend_y(C_VIDEO_DATA_WIDTH - 1 downto 0);
                    end if;
                else
                    s_comp_y_s6 <= s_y_s5;
                end if;

                -- Chroma blend: full gold on direct/Shatter, 50% blend on Halo fill
                if s_fade_shift_s5 <= 1 then
                    s_comp_u_s6 <= s_gold_u_s5;
                    s_comp_v_s6 <= s_gold_v_s5;
                else
                    s_comp_u_s6 <= shift_right(s_u_s5, 1)
                                 + shift_right(s_gold_u_s5, 1);
                    s_comp_v_s6 <= shift_right(s_v_s5, 1)
                                 + shift_right(s_gold_v_s5, 1);
                end if;
            else
                -- ============================================================
                -- NON-EDGE PIXEL: Patina on ceramic shards (Y via proc amp)
                -- ============================================================

                -- Y handled by pipelined proc amp — store passthrough
                s_comp_y_s6 <= s_base_y_s5;

                -- Patina: luma-dependent green oxidation tint
                if s_patina = '1' then
                    -- U shifts down (toward green), proportional to darkness
                    if s_u_s5 > s_patina_amt_s5 then
                        s_comp_u_s6 <= s_u_s5 - s_patina_amt_s5;
                    else
                        s_comp_u_s6 <= (others => '0');
                    end if;
                    -- V shifts down slightly (cooling), half the U effect
                    v_patina_v := shift_right(s_patina_amt_s5, 1);
                    if s_v_s5 > v_patina_v then
                        s_comp_v_s6 <= s_v_s5 - v_patina_v;
                    else
                        s_comp_v_s6 <= (others => '0');
                    end if;
                else
                    s_comp_u_s6 <= s_u_s5;
                    s_comp_v_s6 <= s_v_s5;
                end if;
            end if;

            -- Register edge flag for delay chain
            s_is_edge_s6 <= s_is_edge_s5;

            -- ================================================================
            -- Stages 7-15: Compose alignment delay chain
            -- Delays Stage 6 compose results to align with proc amp output
            -- ================================================================
            s_delay_comp_y(0) <= s_comp_y_s6;
            s_delay_comp_u(0) <= s_comp_u_s6;
            s_delay_comp_v(0) <= s_comp_v_s6;
            s_delay_is_edge(0) <= s_is_edge_s6;

            for i in 1 to C_PROC_AMP_DELAY - 1 loop
                s_delay_comp_y(i) <= s_delay_comp_y(i - 1);
                s_delay_comp_u(i) <= s_delay_comp_u(i - 1);
                s_delay_comp_v(i) <= s_delay_comp_v(i - 1);
                s_delay_is_edge(i) <= s_delay_is_edge(i - 1);
            end loop;

            -- ================================================================
            -- Stage 16: Final select + output register
            -- Edge pixels use delayed compose Y; non-edge uses proc amp Y
            -- U/V always from delayed compose (correct for both paths)
            -- ================================================================
            if s_delay_is_edge(C_PROC_AMP_DELAY - 1) = '1' then
                s_comp_y <= s_delay_comp_y(C_PROC_AMP_DELAY - 1);
            else
                s_comp_y <= s_proc_amp_result;
            end if;
            s_comp_u <= s_delay_comp_u(C_PROC_AMP_DELAY - 1);
            s_comp_v <= s_delay_comp_v(C_PROC_AMP_DELAY - 1);
            s_comp_valid <= '1';

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
            enable => s_comp_valid,
            a      => unsigned(s_y_d),
            b      => s_comp_y,
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
            enable => s_comp_valid,
            a      => unsigned(s_u_d),
            b      => s_comp_u,
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
            enable => s_comp_valid,
            a      => unsigned(s_v_d),
            b      => s_comp_v,
            t      => s_mix_amount,
            result => s_mix_v_result,
            valid  => s_mix_v_valid
        );

    -- ========================================================================
    -- Sync and Data Delay Pipeline
    -- ========================================================================
    p_sync_delay : process(clk)
        type t_sync_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1) of std_logic;
        type t_data_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1)
            of std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_hsync_delay : t_sync_delay := (others => '1');
        variable v_vsync_delay : t_sync_delay := (others => '1');
        variable v_field_delay : t_sync_delay := (others => '1');
        variable v_avid_delay  : t_sync_delay := (others => '0');
        variable v_y_delay     : t_data_delay := (others => (others => '0'));
        variable v_u_delay     : t_data_delay := (others => (others => '0'));
        variable v_v_delay     : t_data_delay := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            v_hsync_delay := data_in.hsync_n & v_hsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_vsync_delay := data_in.vsync_n & v_vsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_field_delay := data_in.field_n & v_field_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_avid_delay  := data_in.avid    & v_avid_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_y_delay     := data_in.y       & v_y_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_u_delay     := data_in.u       & v_u_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_v_delay     := data_in.v       & v_v_delay(0 to C_PROCESSING_DELAY_CLKS - 2);

            s_hsync_n_d <= v_hsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_vsync_n_d <= v_vsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_field_n_d <= v_field_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_avid_d    <= v_avid_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_y_d       <= v_y_delay(C_DRY_TAP - 1);
            s_u_d       <= v_u_delay(C_DRY_TAP - 1);
            s_v_d       <= v_v_delay(C_DRY_TAP - 1);
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment
    -- ========================================================================
    -- Gate to studio blanking outside the (delay-matched) input AVID:
    -- the mix interpolators free-run during blanking and would emit
    -- video-level junk into H/V blank otherwise. AVID itself comes from
    -- the same delay chain as H/V so all output timing is co-phased
    -- with the data-through-mix path.
    data_out.y <= std_logic_vector(s_mix_y_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(64, C_VIDEO_DATA_WIDTH));
    data_out.u <= std_logic_vector(s_mix_u_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(512, C_VIDEO_DATA_WIDTH));
    data_out.v <= std_logic_vector(s_mix_v_result) when s_avid_d = '1'
                  else std_logic_vector(to_unsigned(512, C_VIDEO_DATA_WIDTH));

    data_out.avid    <= s_avid_d;
    data_out.hsync_n <= s_hsync_n_d;
    data_out.vsync_n <= s_vsync_n_d;
    data_out.field_n <= s_field_n_d;

end architecture kintsugi;
