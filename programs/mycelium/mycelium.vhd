-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: mycelium.vhd - Mycelium Program for Videomancer
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
--   Mycelium
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Three-species reaction-diffusion video texture synthesizer implementing:
--
--   SPECIES U (Activator): Fast-diffusing Gray-Scott activator. Represents
--   growing hyphal tips. High U = active, hungry growth fronts.
--
--   SPECIES V (Inhibitor): Slower-diffusing Gray-Scott inhibitor. Represents
--   depleted nutrient space / chemical inhibition. High V = areas where
--   the reaction has burned through resources.
--
--   SPECIES W (Network): Persistent hyphal strand accumulator. Builds up
--   proportionally to V activity (wherever V is high, growth has occurred).
--   Decays slowly, creating a long-lived network map of all past growth.
--   This is the biological "memory" of the mycelium colony: the established
--   hyphal strand network that persists long after the reaction front moves on.
--
--   Gray-Scott equations for U and V:
--     du/dt = Du * lap(u)  -  u*v^2  +  F*(1-u)
--     dv/dt = Dv * lap(v)  +  u*v^2  -  (F+k)*v
--
--   Network accumulator equation:
--     dw/dt = Dw * lap(w)  +  (v >> growth_shift)  -  (w >> gamma_shift)
--
--   Where growth_shift derives from Net Growth (Pot 4): high pot = small shift
--   = fast W accumulation wherever V inhibitor concentration is high.
--   gamma_shift derives from Net Decay (Pot 6): high pot = small shift = fast
--   W fadeout (short-persistence network). No multiplier needed for W; growth
--   and decay are shift-based, and Dw diffusion is two stops slower than Du.
--
--   Spatial coupling uses a 3-neighbor approximate Laplacian (left, north,
--   north-west) for all three species simultaneously. North neighbors come
--   from three dual-bank BRAM line buffers (video_line_buffer SDK IP).
--   NW is derived by pre-registering the previous clock's north value.
--
--   Full-precision multiplier_s (Radix-4 Booth) computes v^2 and u*v^2.
--   W needs no multiplier: its update is computed with variables entirely
--   within the fast Stage 2 pipeline stage.
--
--   Color output: 16-zone triplex palette where three species map to YUV.
--   Net Layer toggle selects display mode: UV-Tips (V dominates luma, shows
--   active reaction fronts) or Web (W dominates luma, shows strand network).
--   Zones 14-15 encode all three species simultaneuosly in triplex mode.
--   Saturation is modulated by a composite of all three species.
--
--   Temporal IIR on luma (variable_filter_s) with cutoff from Net Decay.
--   Chroma uses lightweight inline first-order IIR.
--   Three interpolator_u instances implement wet/dry crossfade with input.
--
--   Seeding: Input video luminance seeds V when luma exceeds a threshold
--   derived from Net Growth (high growth = low threshold = aggressive seeding).
--   LFSR-driven sparse background seeding ensures autonomous operation.
--
--   Resources:
--     3 video_line_buffer (10 BRAMs each) = 30/32 BRAMs total
--     2 multiplier_s for v^2 and u*v^2
--     3 interpolator_u for wet/dry mix
--     1 lfsr16 for autonomous seeding noise
--
-- Pipeline (C_PROCESSING_DELAY_CLKS = 29):
--   2 clk : video_line_buffer read latency (all three species simultaneously)
--   1 clk : LB output registration (breaks BRAM-to-logic critical path)
--   1 clk : Stage 1 - state load from registered LB outputs + NW capture
--   1 clk : Stage 2 - UV Laplacian + W update + feed/kill
--             + multiplier v^2 launch + companion pipe(0) load
--   8 clk : multiplier_s v^2 running + companion pipe propagation
--   8 clk : multiplier_s u*v^2 running + companion pipe2 propagation
--   1 clk : UV assembly + clamp (pre-seed register)
--   1 clk : seed injection + UV writeback register
--   1 clk : color mapping (3-species 16-zone + Net Layer + Invert)
--   1 clk : luma + chroma 1-clock delay registers
--   4 clk : interpolator_u wet/dry mix
--   Total: 29 clocks
--
--   W write-back uses C_WR_PIPE_W_LEN=2 (2-clock delay pipe) since s_wnet_next
--   is computed at Stage 2 without multiplier dependency.
--
-- Parameters:
--   Pot 1  (registers_in(0))    : Feed Rate  -- F: activator source strength
--   Pot 2  (registers_in(1))    : Kill Rate  -- k: inhibitor drain rate
--   Pot 3  (registers_in(2))    : Diffusion  -- Du/Dv spatial spread
--   Pot 4  (registers_in(3))    : Net Growth -- alpha: W accumulation speed
--   Pot 5  (registers_in(4))    : Color Map  -- 8-zone triplex palette
--   Pot 6  (registers_in(5))    : Net Decay  -- gamma: W persistence/fade rate
--   Tog 7  (registers_in(6)(0)) : Freeze     -- hold evolution state
--   Tog 8  (registers_in(6)(1)) : Seed Mode  -- Cont. vs One-Shot seeding
--   Tog 9  (registers_in(6)(2)) : Pattern    -- Spots (Du>Dv) vs Stripes
--   Tog 10 (registers_in(6)(3)) : Net Layer  -- UV Tips vs Web display mode
--   Tog 11 (registers_in(6)(4)) : Invert     -- invert all three species
--   Fader  (registers_in(7))    : Mix        -- dry/wet crossfade
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture mycelium of program_top is

    -- interpolator_u wet/dry mix pipeline depth (dsp/interpolator.vhd)
    constant C_MIX_LATENCY_CLKS : integer := 4;
    -- Total program_top data latency: 32-deep dry chain + 4-clk mix.
    -- (Was 29 with sync tapped at the same depth as dry data — the mix
    -- latency skewed video +4 px against the program's own delayed
    -- sync. Padded to 36 to satisfy the vmprog %4 rule.)
    constant C_PROCESSING_DELAY_CLKS : integer := 36;
    constant C_DRY_TAP : integer := C_PROCESSING_DELAY_CLKS - C_MIX_LATENCY_CLKS;
    constant C_LINE_DEPTH            : integer := 11;  -- log2(2048) = 11

    -- Radix-4 Booth multiplier data latency for G_WIDTH=10: (10+1)/2 + 3 = 8
    constant C_MULT_LATENCY : integer := 8;

    -- UV write address pipe: 22 clocks from Stage 2 to BRAM write
    constant C_WR_PIPE_LEN : integer := 23;

    -- W write address pipe: 2 clocks (W result ready at Stage 2, +1 for LB reg)
    constant C_WR_PIPE_W_LEN : integer := 2;

    -- ========================================================================
    -- Parameter signals
    -- ========================================================================
    signal s_feed_rate  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_kill_rate  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_diffusion  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_net_growth : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_color_map  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_net_decay  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_freeze     : std_logic;
    signal s_seed_mode  : std_logic;
    signal s_pattern    : std_logic;
    signal s_net_layer  : std_logic;
    signal s_invert     : std_logic;
    signal s_mix_amount : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- ========================================================================
    -- LFSR noise source (16-bit, autonomous sparse seeding)
    -- ========================================================================
    signal s_lfsr_out : std_logic_vector(15 downto 0);

    -- ========================================================================
    -- Video timing
    -- ========================================================================
    signal s_timing      : t_video_timing_port;
    signal s_pixel_count : unsigned(C_LINE_DEPTH - 1 downto 0) := (others => '0');
    signal s_ab          : std_logic := '0';

    -- Decoded shift amounts (from combinatorial decode process)
    signal s_diff_shift_u : integer range 2 to 8;
    signal s_diff_shift_v : integer range 3 to 9;
    signal s_growth_shift : integer range 3 to 10;
    signal s_gamma_shift  : integer range 3 to 11;

    -- ========================================================================
    -- Three-species reaction-diffusion state (10-bit fixed point [0,1023])
    --   U = activator, V = inhibitor, W = network strand accumulator
    -- ========================================================================
    signal s_act_cur   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_cur   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_wnet_cur  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    signal s_act_left  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_left  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_wnet_left : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    signal s_act_nw    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_nw    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_wnet_nw   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- North neighbors from line buffers (combinatorial LB outputs)
    signal s_act_north  : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_inh_north  : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_wnet_north : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Registered LB outputs (breaks BRAM-to-logic critical path, +1 pipeline clock)
    signal s_act_north_r  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_north_r  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_wnet_north_r : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- ========================================================================
    -- Line buffer addressing
    -- ========================================================================
    signal s_rd_addr : unsigned(C_LINE_DEPTH - 1 downto 0);

    -- UV write address pipeline (21 stages)
    type t_addr_pipe is array(0 to C_WR_PIPE_LEN - 1)
        of unsigned(C_LINE_DEPTH - 1 downto 0);
    signal s_wr_addr_pipe : t_addr_pipe := (others => (others => '0'));
    signal s_wr_addr      : unsigned(C_LINE_DEPTH - 1 downto 0);

    -- W write address pipeline (1 stage)
    type t_addr_w_pipe is array(0 to C_WR_PIPE_W_LEN - 1)
        of unsigned(C_LINE_DEPTH - 1 downto 0);
    signal s_wr_addr_w_pipe : t_addr_w_pipe := (others => (others => '0'));
    signal s_wr_addr_w      : unsigned(C_LINE_DEPTH - 1 downto 0);

    -- ========================================================================
    -- Pipeline stage intermediate signals
    -- ========================================================================
    signal s_y_in     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_seeded   : std_logic := '0';

    signal s_diff_act  : signed(C_VIDEO_DATA_WIDTH + 1 downto 0) := (others => '0');
    signal s_diff_inh  : signed(C_VIDEO_DATA_WIDTH + 1 downto 0) := (others => '0');
    signal s_feed_base : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_kill_base : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Pre-registered Laplacian partial sums (registered terms only, no BRAM path)
    --   Computed in Stage 1 = left + nw - 3*cur (registered sources → fast carry chain)
    --   Stage 2 adds the BRAM north term → single 2-operand 13-bit adder on critical path
    signal s_lap_partial_act : signed(C_VIDEO_DATA_WIDTH + 2 downto 0) := (others => '0');
    signal s_lap_partial_inh : signed(C_VIDEO_DATA_WIDTH + 2 downto 0) := (others => '0');

    -- Next-frame species values written to line buffers
    signal s_act_preseed  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_preseed  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_seed_y_hold  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_preseed_valid: std_logic := '0';

    signal s_act_next  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_inh_next  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_wnet_next : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- ========================================================================
    -- Multiplier v^2 ports
    -- ========================================================================
    signal s_mult_vsq_x      : signed(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_mult_vsq_y      : signed(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_mult_vsq_en     : std_logic := '0';
    signal s_mult_vsq_result : signed(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mult_vsq_valid  : std_logic;

    -- ========================================================================
    -- Multiplier u*v^2 ports
    -- ========================================================================
    signal s_mult_uvs_x      : signed(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_mult_uvs_y      : signed(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_mult_uvs_en     : std_logic := '0';
    signal s_mult_uvs_result : signed(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mult_uvs_valid  : std_logic;

    -- ========================================================================
    -- Companion pipeline arrays through v^2 and u*v^2 multiplier stages
    --   0..C_MULT_LATENCY = 9 elements, carrying context from Stage 2
    --   through both 8-cycle multiplier pipelines to the assembly stage.
    -- ========================================================================
    type t_u_pipe is array(0 to C_MULT_LATENCY)
        of unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    type t_s_pipe is array(0 to C_MULT_LATENCY)
        of signed(C_VIDEO_DATA_WIDTH + 1 downto 0);

    -- Through v^2 latency
    signal s_pipe_act_cur   : t_u_pipe := (others => (others => '0'));
    signal s_pipe_inh_cur   : t_u_pipe := (others => (others => '0'));
    signal s_pipe_diff_act  : t_s_pipe := (others => (others => '0'));
    signal s_pipe_diff_inh  : t_s_pipe := (others => (others => '0'));
    signal s_pipe_feed      : t_u_pipe := (others => (others => '0'));
    signal s_pipe_kill      : t_u_pipe := (others => (others => '0'));
    signal s_pipe_y_in      : t_u_pipe := (others => (others => '0'));

    -- Through u*v^2 latency
    signal s_pipe2_act_cur  : t_u_pipe := (others => (others => '0'));
    signal s_pipe2_inh_cur  : t_u_pipe := (others => (others => '0'));
    signal s_pipe2_diff_act : t_s_pipe := (others => (others => '0'));
    signal s_pipe2_diff_inh : t_s_pipe := (others => (others => '0'));
    signal s_pipe2_feed     : t_u_pipe := (others => (others => '0'));
    signal s_pipe2_kill     : t_u_pipe := (others => (others => '0'));
    signal s_pipe2_y_in     : t_u_pipe := (others => (others => '0'));

    -- W display: dedicated 18-element delay (replaces two 9-element companion chunks)
    --   Loaded at Stage 1 from s_wnet_cur (north LB output for current pixel).
    --   At color mapping (18 clocks later) provides W for display.
    type t_wnet_disp is array(0 to 17) of unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_wnet_disp_pipe : t_wnet_disp := (others => (others => '0'));

    -- W pre-registered growth and decay terms (computed in Stage 1, used in Stage 2)
    signal s_w_growth_term : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_w_decay_term  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- ========================================================================
    -- Color mapping stage outputs
    -- ========================================================================
    signal s_comp_y     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_comp_u     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0)
        := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_comp_v     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0)
        := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_comp_valid : std_logic := '0';

    -- ========================================================================
    -- Smoothing (1-clock delay registers for luma + chroma)
    -- ========================================================================
    signal s_smooth_y      : signed(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_smooth_u      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0)
        := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_smooth_v      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0)
        := to_unsigned(512, C_VIDEO_DATA_WIDTH);
    signal s_smooth_valid  : std_logic;

    -- ========================================================================
    -- Interpolator outputs (wet/dry mix, 4-clock latency each)
    -- ========================================================================
    signal s_mix_y_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_y_valid  : std_logic;
    signal s_mix_u_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_u_valid  : std_logic;
    signal s_mix_v_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_mix_v_valid  : std_logic;

    -- ========================================================================
    -- Sync and data delay (matches C_PROCESSING_DELAY_CLKS)
    -- ========================================================================
    signal s_hsync_n_d : std_logic;
    signal s_vsync_n_d : std_logic;
    signal s_field_n_d : std_logic;
    signal s_avid_d    : std_logic := '0';
    signal s_y_d       : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_d       : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_d       : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

    -- Convenience constants
    constant C_CHROMA_MID : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        to_unsigned(512, C_VIDEO_DATA_WIDTH);
    constant C_MAX_VAL    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0) :=
        to_unsigned(1023, C_VIDEO_DATA_WIDTH);

begin

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_feed_rate  <= unsigned(registers_in(0));
    s_kill_rate  <= unsigned(registers_in(1));
    s_diffusion  <= unsigned(registers_in(2));
    s_net_growth <= unsigned(registers_in(3));
    s_color_map  <= unsigned(registers_in(4));
    s_net_decay  <= unsigned(registers_in(5));
    s_freeze     <= registers_in(6)(0);
    s_seed_mode  <= registers_in(6)(1);
    s_pattern    <= registers_in(6)(2);
    s_net_layer  <= registers_in(6)(3);
    s_invert     <= registers_in(6)(4);
    s_mix_amount <= unsigned(registers_in(7));

    -- ========================================================================
    -- Diffusion, Growth, and Decay Decode (combinatorial)
    -- ========================================================================
    process(s_diffusion, s_pattern, s_net_growth, s_net_decay)
        -- Range covers the pre-clamp intermediate (base 8 + extra 2):
        -- the old upper bound of 9 tripped a bound check (sim-fatal,
        -- silently truncated in synthesis) whenever Diffusion sat in
        -- its lowest octave with Spots pattern selected.
        variable v_base  : integer range 2 to 11;
        variable v_extra : integer range 1 to 2;
        variable v_gs    : integer range 3 to 10;
        variable v_gams  : integer range 3 to 11;
    begin
        -- Du shift: higher pot = stronger diffusion = smaller shift
        case to_integer(s_diffusion(9 downto 7)) is
            when 0      => v_base := 8;
            when 1      => v_base := 7;
            when 2      => v_base := 6;
            when 3      => v_base := 5;
            when 4      => v_base := 4;
            when 5      => v_base := 3;
            when others => v_base := 3;
        end case;
        s_diff_shift_u <= v_base;

        -- Dv shift: V always diffuses slower than U
        --   Spots: Du >> Dv (+2 stops) -> distinct spots
        --   Stripes: Du ~ Dv (+1 stop) -> labyrinthine stripes
        if s_pattern = '0' then
            v_extra := 2;
        else
            v_extra := 1;
        end if;
        v_base := v_base + v_extra;
        if v_base > 9 then v_base := 9; end if;
        s_diff_shift_v <= v_base;

        -- W growth shift: high net_growth -> small shift -> fast W accumulation
        --   Range [3, 10]: net_growth(9:7)=7 -> shift=3, net_growth(9:7)=0 -> shift=10
        v_gs := 10 - to_integer(s_net_growth(9 downto 7));
        if v_gs < 3 then v_gs := 3; end if;
        s_growth_shift <= v_gs;

        -- W gamma (decay) shift: high net_decay -> small shift -> fast W fade
        --   Range [3, 11]: net_decay(9:7)=7 -> shift=4, net_decay(9:7)=0 -> shift=11
        v_gams := 11 - to_integer(s_net_decay(9 downto 7));
        if v_gams < 3 then v_gams := 3; end if;
        s_gamma_shift <= v_gams;
    end process;

    -- ========================================================================
    -- LFSR Noise (16-bit self-seeded, always running)
    -- ========================================================================
    lfsr_inst : entity work.lfsr16
        port map(
            clk    => clk,
            enable => '1',
            seed   => x"CAFE",
            load   => '0',
            q      => s_lfsr_out
        );

    -- ========================================================================
    -- Video Timing Generator (field-aware local version)
    -- ========================================================================
    timing_gen_inst : entity work.video_timing_generator_fielded
        port map(
            clk     => clk,
            avid    => data_in.avid,
            hsync_n => data_in.hsync_n,
            vsync_n => data_in.vsync_n,
            field_n => data_in.field_n,
            timing  => s_timing
        );

    -- ========================================================================
    -- Pixel Counter and AB Bank Select
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if s_timing.avid_start = '1' then
                s_pixel_count <= (others => '0');
                s_ab <= not s_ab;
            elsif s_timing.avid = '1' then
                s_pixel_count <= s_pixel_count + 1;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Three Line Buffers (dual-bank BRAM ping-pong, 10 BRAMs each = 30 total)
    --   All share the same bank-select (s_ab) and read-address (s_rd_addr).
    --   UV buffers share UV write address (s_wr_addr, long 21-stage pipe).
    --   W buffer uses its own short write address (s_wr_addr_w, 1-stage pipe).
    -- ========================================================================
    s_rd_addr <= s_pixel_count;

    north_act_lb : entity work.video_line_buffer
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_DEPTH => C_LINE_DEPTH)
        port map(
            clk       => clk,
            i_ab      => s_ab,
            i_wr_addr => s_wr_addr,
            i_rd_addr => s_rd_addr,
            i_data    => std_logic_vector(s_act_next),
            o_data    => s_act_north
        );

    north_inh_lb : entity work.video_line_buffer
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_DEPTH => C_LINE_DEPTH)
        port map(
            clk       => clk,
            i_ab      => s_ab,
            i_wr_addr => s_wr_addr,
            i_rd_addr => s_rd_addr,
            i_data    => std_logic_vector(s_inh_next),
            o_data    => s_inh_north
        );

    north_wnet_lb : entity work.video_line_buffer
        generic map(G_WIDTH => C_VIDEO_DATA_WIDTH, G_DEPTH => C_LINE_DEPTH)
        port map(
            clk       => clk,
            i_ab      => s_ab,
            i_wr_addr => s_wr_addr_w,
            i_rd_addr => s_rd_addr,
            i_data    => std_logic_vector(s_wnet_next),
            o_data    => s_wnet_north
        );

    -- ========================================================================
    -- LB Output Registration (adds 1 pipeline clock, breaks BRAM critical path)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_act_north_r  <= unsigned(s_act_north);
            s_inh_north_r  <= unsigned(s_inh_north);
            s_wnet_north_r <= unsigned(s_wnet_north);
        end if;
    end process;

    -- Concurrent write-address outputs from delay pipelines
    s_wr_addr   <= s_wr_addr_pipe(C_WR_PIPE_LEN - 1);
    s_wr_addr_w <= s_wr_addr_w_pipe(C_WR_PIPE_W_LEN - 1);

    -- ========================================================================
    -- Multiplier Instances (SDK multiplier_s, Radix-4 Booth signed)
    --   G_WIDTH=10, G_FRAC_BITS=9: result = (x * y) / 512
    --   G_OUTPUT_MAX=511: clamp result to [0, 511]
    --   Data latency: C_MULT_LATENCY = 8 clock cycles
    -- ========================================================================
    mult_vsq_inst : entity work.multiplier_s
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH - 1,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 511
        )
        port map(
            clk    => clk,
            enable => s_mult_vsq_en,
            x      => s_mult_vsq_x,
            y      => s_mult_vsq_y,
            z      => (others => '0'),
            result => s_mult_vsq_result,
            valid  => s_mult_vsq_valid
        );

    mult_uvs_inst : entity work.multiplier_s
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH - 1,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 511
        )
        port map(
            clk    => clk,
            enable => s_mult_uvs_en,
            x      => s_mult_uvs_x,
            y      => s_mult_uvs_y,
            z      => (others => '0'),
            result => s_mult_uvs_result,
            valid  => s_mult_uvs_valid
        );

    -- ========================================================================
    -- Main Processing Pipeline
    -- ========================================================================
    process(clk)
        variable v_speed_gate   : boolean;

        -- Three-species Laplacian (used for UV; W uses pre-registered terms)
        variable v_lap_act  : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_lap_inh  : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);

        -- W update scratch (growth/decay pre-registered in Stage 1)
        variable v_wnet_wide   : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_wnet_clamped: unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

        -- Feed/kill approximation
        variable v_fu : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

        -- UV assembly scratch
        variable v_reaction_u  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_sum_a       : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_sum_b       : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_act_wide    : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_inh_wide    : signed(C_VIDEO_DATA_WIDTH + 2 downto 0);
        variable v_act_clamped : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_inh_clamped : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_seed_thresh : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

        -- Color mapping scratch
        variable v_ui  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_vi  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_wi  : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_y   : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_sat : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_cha : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
        variable v_chb : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    begin
        if rising_edge(clk) then

            v_speed_gate := (s_freeze = '0');

            -- ================================================================
            -- Stage 1: State load from line buffer outputs + NW neighbor capture
            --   All signal assignments are SCHEDULED. Reads within this process
            --   see OLD signal values. This implicit register stage separates
            --   Stage 1 (capturing LB data) from Stage 2 (using it).
            -- ================================================================
            s_y_in <= unsigned(data_in.y);

            -- Left neighbors = previous pixel's computed output (VHDL old value)
            s_act_left  <= s_act_next;
            s_inh_left  <= s_inh_next;
            s_wnet_left <= s_wnet_next;

            -- NW neighbors = previous clock's north value (pre-snapshot)
            s_act_nw   <= s_act_cur;
            s_inh_nw   <= s_inh_cur;
            s_wnet_nw  <= s_wnet_cur;

            -- Load current north from registered LB outputs
            s_act_cur  <= s_act_north_r;
            s_inh_cur  <= s_inh_north_r;
            s_wnet_cur <= s_wnet_north_r;

            -- Write address pipes
            s_wr_addr_pipe(0) <= s_rd_addr;          -- UV (21-stage)
            s_wr_addr_w_pipe(0) <= s_rd_addr;        -- W  (1-stage)
            for i in 1 to C_WR_PIPE_LEN - 1 loop
                s_wr_addr_pipe(i) <= s_wr_addr_pipe(i - 1);
            end loop;

            -- W display delay: load north W, propagate 18 stages to color mapping
            s_wnet_disp_pipe(0) <= s_wnet_north_r;
            for i in 1 to 17 loop
                s_wnet_disp_pipe(i) <= s_wnet_disp_pipe(i - 1);
            end loop;

            -- Laplacian partial sums: registered terms only (no BRAM path in carry chain)
            --   Partial = left + nw - 3*cur  (all registered FFs → clean carry chain)
            --   Stage 2 adds north (BRAM) as 2-operand finish: total = partial + north
            --   This removes 3 carry-chain stages from Stage 2's critical path.
            s_lap_partial_act <= resize(signed('0' & s_act_left), C_VIDEO_DATA_WIDTH + 3)
                               + resize(signed('0' & s_act_nw), C_VIDEO_DATA_WIDTH + 3)
                               - resize(signed('0' & s_act_cur), C_VIDEO_DATA_WIDTH + 3)
                               - shift_left(resize(signed('0' & s_act_cur),
                                                   C_VIDEO_DATA_WIDTH + 3), 1);

            s_lap_partial_inh <= resize(signed('0' & s_inh_left), C_VIDEO_DATA_WIDTH + 3)
                               + resize(signed('0' & s_inh_nw), C_VIDEO_DATA_WIDTH + 3)
                               - resize(signed('0' & s_inh_cur), C_VIDEO_DATA_WIDTH + 3)
                               - shift_left(resize(signed('0' & s_inh_cur),
                                                   C_VIDEO_DATA_WIDTH + 3), 1);

            -- Pre-register W growth and decay terms (breaks Stage 2 critical path)
            --   Growth uses V north (registered LB output) at Stage 1 time
            --   Decay uses W north (registered LB output) at Stage 1 time
            if v_speed_gate then
                case s_growth_shift is
                    when 3      => s_w_growth_term <= shift_right(s_inh_north_r, 3);
                    when 4      => s_w_growth_term <= shift_right(s_inh_north_r, 4);
                    when 5      => s_w_growth_term <= shift_right(s_inh_north_r, 5);
                    when 6      => s_w_growth_term <= shift_right(s_inh_north_r, 6);
                    when 7      => s_w_growth_term <= shift_right(s_inh_north_r, 7);
                    when 8      => s_w_growth_term <= shift_right(s_inh_north_r, 8);
                    when 9      => s_w_growth_term <= shift_right(s_inh_north_r, 9);
                    when others => s_w_growth_term <= (others => '0');
                end case;
                case s_gamma_shift is
                    when 3      => s_w_decay_term <= shift_right(s_wnet_north_r, 3);
                    when 4      => s_w_decay_term <= shift_right(s_wnet_north_r, 4);
                    when 5      => s_w_decay_term <= shift_right(s_wnet_north_r, 5);
                    when 6      => s_w_decay_term <= shift_right(s_wnet_north_r, 6);
                    when 7      => s_w_decay_term <= shift_right(s_wnet_north_r, 7);
                    when 8      => s_w_decay_term <= shift_right(s_wnet_north_r, 8);
                    when 9      => s_w_decay_term <= shift_right(s_wnet_north_r, 9);
                    when others => s_w_decay_term <= (others => '0');
                end case;
            else
                s_w_growth_term <= (others => '0');
                s_w_decay_term  <= (others => '0');
            end if;

            -- ================================================================
            -- Stage 2: Three-species Laplacian + UV feed/kill + W update
            --   Reads OLD signal values (from Stage 1 of the PREVIOUS clock).
            --   Variables are used for the W update chain to avoid adding an
            --   extra pipeline register for W (keeping total delay at 27 clks).
            --
            --   Laplacian approx: left + north_LB_output + NW - 3 * center
            --   where LB output reads OLD s_*_north (fresh from LB),
            --   NW reads OLD s_*_nw, and center reads OLD s_*_cur.
            -- ================================================================

            -- Laplacians for all three species
            -- Laplacian: registered partial + registered north (both FF inputs)
            v_lap_act := s_lap_partial_act
                       + resize(signed('0' & s_act_north_r), C_VIDEO_DATA_WIDTH + 3);

            v_lap_inh := s_lap_partial_inh
                       + resize(signed('0' & s_inh_north_r), C_VIDEO_DATA_WIDTH + 3);

            if v_speed_gate then

                -- UV diffusion scaling (shift-based)
                case s_diff_shift_u is
                    when 2 => s_diff_act <= resize(shift_right(v_lap_act, 2), C_VIDEO_DATA_WIDTH + 2);
                    when 3 => s_diff_act <= resize(shift_right(v_lap_act, 3), C_VIDEO_DATA_WIDTH + 2);
                    when 4 => s_diff_act <= resize(shift_right(v_lap_act, 4), C_VIDEO_DATA_WIDTH + 2);
                    when 5 => s_diff_act <= resize(shift_right(v_lap_act, 5), C_VIDEO_DATA_WIDTH + 2);
                    when 6 => s_diff_act <= resize(shift_right(v_lap_act, 6), C_VIDEO_DATA_WIDTH + 2);
                    when 7 => s_diff_act <= resize(shift_right(v_lap_act, 7), C_VIDEO_DATA_WIDTH + 2);
                    when others => s_diff_act <= (others => '0');
                end case;
                case s_diff_shift_v is
                    when 3 => s_diff_inh <= resize(shift_right(v_lap_inh, 3), C_VIDEO_DATA_WIDTH + 2);
                    when 4 => s_diff_inh <= resize(shift_right(v_lap_inh, 4), C_VIDEO_DATA_WIDTH + 2);
                    when 5 => s_diff_inh <= resize(shift_right(v_lap_inh, 5), C_VIDEO_DATA_WIDTH + 2);
                    when 6 => s_diff_inh <= resize(shift_right(v_lap_inh, 6), C_VIDEO_DATA_WIDTH + 2);
                    when 7 => s_diff_inh <= resize(shift_right(v_lap_inh, 7), C_VIDEO_DATA_WIDTH + 2);
                    when 8 => s_diff_inh <= resize(shift_right(v_lap_inh, 8), C_VIDEO_DATA_WIDTH + 2);
                    when others => s_diff_inh <= (others => '0');
                end case;

                -- Feed term: F*(1-U) approximated via two MSB bit-test of U
                --   F*(1-U) ~= F/8 - F*U[9]/16 - F*U[8]/32  (bit-weighted)
                --   Plus luma modulation: brighter input = stronger feed bonus
                v_fu := (others => '0');
                if s_act_cur(9) = '1' then v_fu := v_fu + shift_right(s_feed_rate, 4); end if;
                if s_act_cur(8) = '1' then v_fu := v_fu + shift_right(s_feed_rate, 5); end if;
                if s_act_cur >= C_MAX_VAL then
                    s_feed_base <= shift_right(s_y_in, 5);
                elsif shift_right(s_feed_rate, 3) + shift_right(s_y_in, 5) >= v_fu then
                    s_feed_base <= shift_right(s_feed_rate, 3)
                                 + shift_right(s_y_in, 5) - v_fu;
                else
                    s_feed_base <= (others => '0');
                end if;

                -- Kill term: k*V approximated via two MSB bit-test of V
                v_fu := (others => '0');
                if s_inh_cur(9) = '1' then v_fu := v_fu + shift_right(s_kill_rate, 4); end if;
                if s_inh_cur(8) = '1' then v_fu := v_fu + shift_right(s_kill_rate, 5); end if;
                s_kill_base <= v_fu;

                -- W Network Update (uses pre-registered Stage 1 growth/decay terms)
                --   All three inputs are registered FFs: minimal Stage 2 critical path.
                v_wnet_wide := resize(signed('0' & s_wnet_cur), C_VIDEO_DATA_WIDTH + 3)
                             + resize(signed('0' & s_w_growth_term), C_VIDEO_DATA_WIDTH + 3)
                             - resize(signed('0' & s_w_decay_term),  C_VIDEO_DATA_WIDTH + 3);

                -- Clamp W to [0, 1023]
                if v_wnet_wide < 0 then
                    v_wnet_clamped := (others => '0');
                elsif v_wnet_wide > 1023 then
                    v_wnet_clamped := C_MAX_VAL;
                else
                    v_wnet_clamped := unsigned(v_wnet_wide(C_VIDEO_DATA_WIDTH - 1 downto 0));
                end if;
                s_wnet_next <= v_wnet_clamped;

            else
                -- Frozen: hold all outputs, no Laplacian computation
                s_diff_act  <= (others => '0');
                s_diff_inh  <= (others => '0');
                s_feed_base <= (others => '0');
                s_kill_base <= (others => '0');
                s_wnet_next <= s_wnet_cur;
            end if;

            -- ================================================================
            -- Launch v^2 multiplier (always enabled regardless of freeze)
            --   Convert V[0,1023] -> signed [0,+511] by right-shifting 1.
            --   Result range: [0,511] (G_OUTPUT_MAX=511)
            -- ================================================================
            s_mult_vsq_x  <= signed('0' & std_logic_vector(
                s_inh_cur(C_VIDEO_DATA_WIDTH - 1 downto 1)));
            s_mult_vsq_y  <= signed('0' & std_logic_vector(
                s_inh_cur(C_VIDEO_DATA_WIDTH - 1 downto 1)));
            s_mult_vsq_en <= '1';

            -- ================================================================
            -- Companion pipe: old state values through v^2 latency (8 clocks)
            --   Reads OLD signal values to match the multiplier's input data.
            -- ================================================================
            s_pipe_act_cur(0)  <= s_act_cur;
            s_pipe_inh_cur(0)  <= s_inh_cur;
            s_pipe_diff_act(0) <= s_diff_act;
            s_pipe_diff_inh(0) <= s_diff_inh;
            s_pipe_feed(0)     <= s_feed_base;
            s_pipe_kill(0)     <= s_kill_base;
            s_pipe_y_in(0)     <= s_y_in;
            for i in 1 to C_MULT_LATENCY loop
                s_pipe_act_cur(i)  <= s_pipe_act_cur(i - 1);
                s_pipe_inh_cur(i)  <= s_pipe_inh_cur(i - 1);
                s_pipe_diff_act(i) <= s_pipe_diff_act(i - 1);
                s_pipe_diff_inh(i) <= s_pipe_diff_inh(i - 1);
                s_pipe_feed(i)     <= s_pipe_feed(i - 1);
                s_pipe_kill(i)     <= s_pipe_kill(i - 1);
                s_pipe_y_in(i)     <= s_pipe_y_in(i - 1);
            end loop;

            -- ================================================================
            -- Launch u*v^2 multiplier (when v^2 result valid)
            --   U input: pipe_act_cur(8) >> 1 (sign-extended to [0,+511])
            --   v_sq input: v^2 result [0,511]
            -- ================================================================
            s_mult_uvs_x  <= signed('0' & std_logic_vector(
                s_pipe_act_cur(C_MULT_LATENCY)(C_VIDEO_DATA_WIDTH - 1 downto 1)));
            s_mult_uvs_y  <= s_mult_vsq_result;
            s_mult_uvs_en <= s_mult_vsq_valid;

            -- Companion pipe2: through u*v^2 latency (8 more clocks)
            s_pipe2_act_cur(0)  <= s_pipe_act_cur(C_MULT_LATENCY);
            s_pipe2_inh_cur(0)  <= s_pipe_inh_cur(C_MULT_LATENCY);
            s_pipe2_diff_act(0) <= s_pipe_diff_act(C_MULT_LATENCY);
            s_pipe2_diff_inh(0) <= s_pipe_diff_inh(C_MULT_LATENCY);
            s_pipe2_feed(0)     <= s_pipe_feed(C_MULT_LATENCY);
            s_pipe2_kill(0)     <= s_pipe_kill(C_MULT_LATENCY);
            s_pipe2_y_in(0)     <= s_pipe_y_in(C_MULT_LATENCY);
            for i in 1 to C_MULT_LATENCY loop
                s_pipe2_act_cur(i)  <= s_pipe2_act_cur(i - 1);
                s_pipe2_inh_cur(i)  <= s_pipe2_inh_cur(i - 1);
                s_pipe2_diff_act(i) <= s_pipe2_diff_act(i - 1);
                s_pipe2_diff_inh(i) <= s_pipe2_diff_inh(i - 1);
                s_pipe2_feed(i)     <= s_pipe2_feed(i - 1);
                s_pipe2_kill(i)     <= s_pipe2_kill(i - 1);
                s_pipe2_y_in(i)     <= s_pipe2_y_in(i - 1);
            end loop;

            -- ================================================================
            -- UV Assembly + Clamp (pre-seed)
            --   Reaction term: u*v^2 result [0,511], scaled to [0,1023] via <<1
            --
            --   U_new = U + Du*lap(U) - u*v^2 + F*(1-U)
            --   V_new = V + Dv*lap(V) + u*v^2 - (F+k)*V
            --
            --   Results are registered into pre-seed signals for a separate
            --   seed-injection stage on the next clock.
            -- ================================================================
            v_reaction_u := unsigned(
                s_mult_uvs_result(C_VIDEO_DATA_WIDTH - 2 downto 0)) & '0';

            if v_speed_gate then

                -- U update
                v_sum_a := resize(signed('0' & s_pipe2_act_cur(C_MULT_LATENCY)), C_VIDEO_DATA_WIDTH + 3)
                         + resize(s_pipe2_diff_act(C_MULT_LATENCY), C_VIDEO_DATA_WIDTH + 3);
                v_sum_b := resize(signed('0' & s_pipe2_feed(C_MULT_LATENCY)), C_VIDEO_DATA_WIDTH + 3)
                         - resize(signed('0' & v_reaction_u), C_VIDEO_DATA_WIDTH + 3);
                v_act_wide := v_sum_a + v_sum_b;

                if v_act_wide < 0 then
                    v_act_clamped := (others => '0');
                elsif v_act_wide > 1023 then
                    v_act_clamped := C_MAX_VAL;
                else
                    v_act_clamped := unsigned(v_act_wide(C_VIDEO_DATA_WIDTH - 1 downto 0));
                end if;

                -- V update
                v_sum_a := resize(signed('0' & s_pipe2_inh_cur(C_MULT_LATENCY)), C_VIDEO_DATA_WIDTH + 3)
                         + resize(s_pipe2_diff_inh(C_MULT_LATENCY), C_VIDEO_DATA_WIDTH + 3);
                v_sum_b := resize(signed('0' & v_reaction_u), C_VIDEO_DATA_WIDTH + 3)
                         - resize(signed('0' & s_pipe2_kill(C_MULT_LATENCY)), C_VIDEO_DATA_WIDTH + 3);
                v_inh_wide := v_sum_a + v_sum_b;

                if v_inh_wide < 0 then
                    v_inh_clamped := (others => '0');
                elsif v_inh_wide > 1023 then
                    v_inh_clamped := C_MAX_VAL;
                else
                    v_inh_clamped := unsigned(v_inh_wide(C_VIDEO_DATA_WIDTH - 1 downto 0));
                end if;

                s_act_preseed   <= v_act_clamped;
                s_inh_preseed   <= v_inh_clamped;
                s_seed_y_hold   <= s_pipe2_y_in(C_MULT_LATENCY);
                s_preseed_valid <= '1';
            else
                s_act_preseed   <= s_pipe2_act_cur(C_MULT_LATENCY);
                s_inh_preseed   <= s_pipe2_inh_cur(C_MULT_LATENCY);
                s_seed_y_hold   <= s_pipe2_y_in(C_MULT_LATENCY);
                s_preseed_valid <= '0';
            end if;

            -- ================================================================
            -- Seed injection + UV writeback register
            --   Reads OLD pre-seed values from previous clock.
            -- ================================================================
            v_inh_clamped := s_inh_preseed;

            if s_preseed_valid = '1' then
                -- Seed threshold = 1023 - net_growth via bitwise NOT
                v_seed_thresh := not s_net_growth;

                if s_seed_y_hold >= v_seed_thresh then
                    -- Video-driven seed: luma above threshold injects V
                    if s_seed_mode = '0' or s_seeded = '0' then
                        v_inh_clamped := s_seed_y_hold;
                        if s_seed_mode = '1' then
                            s_seeded <= '1';
                        end if;
                    end if;
                elsif s_seed_mode = '0' or s_seeded = '0' then
                    -- Autonomous LFSR seed: sparse background seeding
                    if unsigned(s_lfsr_out(15 downto 11)) < shift_right(not s_net_growth, 5) then
                        v_inh_clamped := unsigned(s_lfsr_out(9 downto 0));
                        if s_seed_mode = '1' then
                            s_seeded <= '1';
                        end if;
                    end if;
                end if;
            end if;

            s_act_next <= s_act_preseed;
            s_inh_next <= v_inh_clamped;

            -- ================================================================
            -- Color Mapping: 16-zone triplex palette (3-species)
            --
            --   Reads OLD s_act_next, OLD s_inh_next: these are from the
            --   PREVIOUS clock's assembly stage (VHDL implicit register).
            --   W is taken from pipe2(8) aligned with assembly output.
            --
            --   Net Layer (Tog 10):
            --     '0' UV Tips: V dominates luma (active fronts bright)
            --     '1' Web:     W dominates luma (strand network bright)
            --
            --   Saturation: composite (V>>1 + W>>2 + U>>3), clamped to 1023.
            --   Zones 14-15: triplex encoding of all three species in YUV.
            -- ================================================================

            -- Fetch display values (OLD signals from previous clock's assembly)
            v_ui := s_act_next;
            v_vi := s_inh_next;
            v_wi := s_wnet_disp_pipe(17);

            -- Apply invert to all three species if enabled
            if s_invert = '1' then
                v_ui := C_MAX_VAL - s_act_next;
                v_vi := C_MAX_VAL - s_inh_next;
                v_wi := C_MAX_VAL - s_wnet_disp_pipe(17);
            end if;

            -- Luma: V or W dominant, other at quarter weight
            if s_net_layer = '0' then
                -- UV Tips: V (reaction front concentration) drives luma
                if v_vi >= shift_right(v_wi, 2) then
                    v_y := v_vi;
                else
                    v_y := shift_right(v_wi, 2);
                end if;
            else
                -- Web: W (strand network density) drives luma
                if v_wi >= shift_right(v_vi, 2) then
                    v_y := v_wi;
                else
                    v_y := shift_right(v_vi, 2);
                end if;
            end if;

            -- Saturation composite (clamped to 1023)
            v_sat := shift_right(v_vi, 1) + shift_right(v_wi, 2) + shift_right(v_ui, 3);
            if v_sat > C_MAX_VAL then
                v_sat := C_MAX_VAL;
            end if;

            -- Chroma per zone (color_map bits 9:7 = zone index 0..7)
            case to_integer(s_color_map(9 downto 7)) is

                when 0 =>   -- Monochrome: neutral chroma
                    v_cha := C_CHROMA_MID;
                    v_chb := C_CHROMA_MID;

                when 1 =>   -- Amber: bioluminescent orange
                    v_cha := C_CHROMA_MID - shift_right(v_sat, 3);
                    v_chb := C_CHROMA_MID + shift_right(v_sat, 2);

                when 2 =>   -- Magenta: warm pink-purple
                    v_cha := C_CHROMA_MID + shift_right(v_sat, 2);
                    v_chb := C_CHROMA_MID + shift_right(v_sat, 2);

                when 3 =>   -- Indigo: deep blue-violet
                    v_cha := C_CHROMA_MID + shift_right(v_sat, 1);
                    v_chb := C_CHROMA_MID + shift_right(v_sat, 3);

                when 4 =>   -- Cyan: bioluminescent aqua
                    v_cha := C_CHROMA_MID + shift_right(v_sat, 1);
                    v_chb := C_CHROMA_MID - shift_right(v_sat, 2);

                when 5 =>   -- Green: forest moss growth
                    v_cha := C_CHROMA_MID - shift_right(v_sat, 3);
                    v_chb := C_CHROMA_MID - shift_right(v_sat, 2);

                when 6 =>   -- Gold: warm ochre glow
                    v_cha := C_CHROMA_MID - shift_right(v_sat, 2);
                    v_chb := C_CHROMA_MID + shift_right(v_sat, 3);

                when others =>  -- Triplex: W->Cb, U->Cr, V->luma
                    v_cha := C_CHROMA_MID + shift_right(v_wi, 2) - shift_right(v_ui, 3);
                    v_chb := C_CHROMA_MID + shift_right(v_ui, 2) - shift_right(v_wi, 3);

            end case;

            s_comp_y     <= v_y;
            s_comp_u     <= v_cha;
            s_comp_v     <= v_chb;
            s_comp_valid <= '1';

            -- Reset one-shot seed latch on new frame
            if s_timing.vsync_start = '1' then
                s_seeded <= '0';
            end if;

        end if;
    end process;

    -- ========================================================================
    -- Chroma 1-clock delay register (align with s_smooth_valid from luma IIR)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if s_comp_valid = '1' then
                s_smooth_u <= s_comp_u;
                s_smooth_v <= s_comp_v;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Luma 1-clock delay register (replaces variable_filter_s IIR)
    --   Eliminates the IIR accumulator carry chain from the critical path.
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if s_comp_valid = '1' then
                s_smooth_y <= signed(s_comp_y);
            end if;
            s_smooth_valid <= s_comp_valid;
        end if;
    end process;

    -- ========================================================================
    -- Wet/Dry Mix (interpolator_u, 4 clock latency per channel)
    -- ========================================================================
    mix_y_inst : entity work.interpolator_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(
            clk    => clk, enable => s_smooth_valid,
            a      => unsigned(s_y_d), b => unsigned(s_smooth_y),
            t      => s_mix_amount,
            result => s_mix_y_result, valid => s_mix_y_valid);

    mix_u_inst : entity work.interpolator_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(
            clk    => clk, enable => s_smooth_valid,
            a      => unsigned(s_u_d), b => s_smooth_u,
            t      => s_mix_amount,
            result => s_mix_u_result, valid => s_mix_u_valid);

    mix_v_inst : entity work.interpolator_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH, G_FRAC_BITS => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(
            clk    => clk, enable => s_smooth_valid,
            a      => unsigned(s_v_d), b => s_smooth_v,
            t      => s_mix_amount,
            result => s_mix_v_result, valid => s_mix_v_valid);

    -- ========================================================================
    -- Sync and Data Delay (27-clock shift register, matches processing depth)
    -- ========================================================================
    process(clk)
        type t_sync_delay is array(0 to C_PROCESSING_DELAY_CLKS - 1) of std_logic;
        type t_data_delay is array(0 to C_PROCESSING_DELAY_CLKS - 1)
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
            -- Dry data taps mix-latency short of the sync taps so
            -- data-through-mix and sync reach data_out co-timed.
            s_y_d       <= v_y_delay(C_DRY_TAP - 1);
            s_u_d       <= v_u_delay(C_DRY_TAP - 1);
            s_v_d       <= v_v_delay(C_DRY_TAP - 1);
        end if;
    end process;

    -- ========================================================================
    -- Output Assignment
    -- ========================================================================
    -- Gate to studio blanking outside the delay-matched input AVID (the
    -- mix free-runs during blanking), and drive AVID from the same
    -- chain as H/V/field so all output timing is co-phased.
    data_out.y       <= std_logic_vector(s_mix_y_result) when s_avid_d = '1'
                        else std_logic_vector(to_unsigned(64, C_VIDEO_DATA_WIDTH));
    data_out.u       <= std_logic_vector(s_mix_u_result) when s_avid_d = '1'
                        else std_logic_vector(C_CHROMA_MID);
    data_out.v       <= std_logic_vector(s_mix_v_result) when s_avid_d = '1'
                        else std_logic_vector(C_CHROMA_MID);
    data_out.avid    <= s_avid_d;
    data_out.hsync_n <= s_hsync_n_d;
    data_out.vsync_n <= s_vsync_n_d;
    data_out.field_n <= s_field_n_d;

end mycelium;
