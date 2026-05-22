-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: pong.vhd - Pong Program for Videomancer
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
--   Pong
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   Classic two-player Pong recreation.  A ball bounces between two paddles
--   on a 1920x1080 court.  Player 1 position is controlled by Pot 3;
--   Player 2 can be AI-controlled or manual (via Fader 12 when in manual
--   mode).  Scores are rendered as 5x7 dot-matrix digits at the top of
--   the screen.  A dashed center net and court border complete the retro
--   aesthetic.
--
--   The ball angle changes based on where it hits the paddle: center
--   returns a flat bounce; edges give steeper angles.
--
--   0 BRAM.  ~600 LUTs.
--
-- Pipeline:
--   1 clk : timing_gen stage 0 (register raw inputs)
--   1 clk : pixel_counter (h_count, v_count registered)
--   1 clk : Stage 1 — coordinate registration + signed boundary pre-computation
--   1 clk : Stage 2 — individual comparison flags (register-to-register)
--   1 clk : Stage 3 — combine flags + score deltas
--   1 clk : Stage 4 — score digit font lookup
--   1 clk : Stage 5 — color mux
--   4 clk : interpolator (wet/dry mix)
--   2 clk : IO alignment
--   Total: 7 render + 4 interpolator + 2 IO = 13 clocks
--
-- Parameters:
--   Pot 1  (registers_in(0))  : Ball Speed
--   Pot 2  (registers_in(1))  : Paddle Size
--   Pot 3  (registers_in(2))  : Player 1 Position
--   Pot 4  (registers_in(3))  : AI Skill (tracking speed)
--   Pot 5  (registers_in(4))  : Court Hue
--   Pot 6  (registers_in(5))  : Brightness
--   Tog 7  (registers_in(6)(0)) : P2 Mode (AI / Manual)
--   Tog 8  (registers_in(6)(1)) : Net display
--   Tog 9  (registers_in(6)(2)) : Score display
--   Tog 10 (registers_in(6)(3)) : Color mode (mono / hue)
--   Tog 11 (registers_in(6)(4)) : Wide (double paddle height)
--   Fader  (registers_in(7))  : Mix (AI mode) / P2 Position (Manual mode)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_timing_pkg.all;

architecture pong of program_top is

    -- ========================================================================
    -- Constants
    -- ========================================================================
    constant C_CHROMA_MID  : unsigned(9 downto 0) := to_unsigned(512, 10);
    constant C_MAX_VAL     : unsigned(9 downto 0) := to_unsigned(1023, 10);
    constant C_PROCESSING_DELAY_CLKS : integer := 7;  -- rendering pipeline depth (timing_gen + pixel_counter + 5 stages)

    -- Court geometry
    constant C_BORDER_W    : integer := 4;       -- border thickness
    constant C_PADDLE_X_P1 : integer := 80;      -- left paddle X (left edge)
    constant C_PADDLE_W    : integer := 16;      -- paddle width in pixels
    constant C_BALL_SIZE   : integer := 16;      -- ball is 16x16 square
    constant C_NET_W       : integer := 4;       -- center net width
    constant C_NET_DASH_H  : integer := 20;      -- net dash height
    constant C_NET_GAP_H   : integer := 12;      -- net gap height

    -- Score digit geometry (5x7 rendered at 4x scale = 20x28 pixels)
    constant C_DIGIT_W     : integer := 5;
    constant C_DIGIT_H     : integer := 7;
    constant C_DIGIT_SCALE : integer := 4;

    -- Serve direction constants
    constant C_SERVE_LEFT  : std_logic := '0';
    constant C_SERVE_RIGHT : std_logic := '1';

    -- ========================================================================
    -- Score Digit Font (5x7 bitmapped, digits 0-9)
    -- Each row is 5 bits wide, 7 rows per digit
    -- ========================================================================
    type t_digit_row is array (0 to 4) of std_logic;

    -- 5-wide bitmaps stored as 7 rows of 5 bits = 35 bits per digit
    -- Packed into a constant array for LUT-based lookup
    type t_font_rom is array (0 to 79) of std_logic_vector(4 downto 0);
    constant C_FONT : t_font_rom := (
        -- 0
        "01110", "10001", "10011", "10101", "11001", "10001", "01110", "00000",
        -- 1
        "00100", "01100", "00100", "00100", "00100", "00100", "01110", "00000",
        -- 2
        "01110", "10001", "00001", "00010", "00100", "01000", "11111", "00000",
        -- 3
        "11111", "00010", "00100", "00010", "00001", "10001", "01110", "00000",
        -- 4
        "00010", "00110", "01010", "10010", "11111", "00010", "00010", "00000",
        -- 5
        "11111", "10000", "11110", "00001", "00001", "10001", "01110", "00000",
        -- 6
        "00110", "01000", "10000", "11110", "10001", "10001", "01110", "00000",
        -- 7
        "11111", "00001", "00010", "00100", "01000", "01000", "01000", "00000",
        -- 8
        "01110", "10001", "10001", "01110", "10001", "10001", "01110", "00000",
        -- 9
        "01110", "10001", "10001", "01111", "00001", "00010", "01100", "00000"
    );

    -- ========================================================================
    -- Parameters
    -- ========================================================================
    signal s_speed_pot     : unsigned(9 downto 0);
    signal s_padsize_pot   : unsigned(9 downto 0);
    signal s_p1_pos_pot    : unsigned(9 downto 0);
    signal s_ai_skill_pot  : unsigned(9 downto 0);
    signal s_hue_pot       : unsigned(9 downto 0);
    signal s_bright_pot    : unsigned(9 downto 0);
    signal s_p2_manual     : std_logic;
    signal s_net_en        : std_logic;
    signal s_score_en      : std_logic;
    signal s_color_mode    : std_logic;
    signal s_wide         : std_logic;
    signal s_mix_amount    : unsigned(9 downto 0);

    -- Derived paddle size (40..295 pixels tall) — registered for timing
    signal s_paddle_h      : unsigned(8 downto 0) := to_unsigned(80, 9);

    -- ========================================================================
    -- Timing
    -- ========================================================================
    signal s_timing        : t_video_timing_port;
    signal s_h_count       : unsigned(11 downto 0);
    signal s_v_count       : unsigned(11 downto 0);

    -- ========================================================================
    -- Resolution (auto-measured from actual pixel/line counts)
    -- ========================================================================
    -- These are measured from the incoming timing signals rather than looked
    -- up from resolution_pkg. Values stabilise after the first complete frame.
    signal s_h_active      : integer range 0 to 4095;
    signal s_v_active      : integer range 0 to 4095;
    signal s_h_center      : integer range 0 to 4095;
    signal s_v_center      : integer range 0 to 4095;
    signal s_paddle_x_p2   : integer range 0 to 4095;
    signal s_score_p1_x    : integer range 0 to 4095;
    signal s_score_p2_x    : integer range 0 to 4095;
    signal s_score_y       : integer range 0 to 4095;

    -- Auto-measurement counters
    signal s_h_pixel_counter : unsigned(11 downto 0) := (others => '0');
    signal s_v_line_counter  : unsigned(11 downto 0) := (others => '0');
    signal s_measured_h      : unsigned(11 downto 0) := to_unsigned(960, 12);
    signal s_measured_v      : unsigned(11 downto 0) := to_unsigned(1080, 12);

    -- ========================================================================
    -- Paddle state
    -- ========================================================================
    signal s_p1_y          : signed(11 downto 0) := to_signed(440, 12);
    signal s_p2_y          : signed(11 downto 0) := to_signed(440, 12);
    signal s_p2_target     : signed(11 downto 0) := to_signed(440, 12);

    -- ========================================================================
    -- Ball state
    -- ========================================================================
    signal s_ball_x        : signed(11 downto 0) := to_signed(952, 12);
    signal s_ball_y        : signed(11 downto 0) := to_signed(532, 12);
    signal s_ball_vx       : signed(4 downto 0)  := to_signed(4, 5);
    signal s_ball_vy       : signed(4 downto 0)  := to_signed(2, 5);
    signal s_serve_dir     : std_logic := C_SERVE_RIGHT;
    signal s_ball_active   : std_logic := '1';
    signal s_serve_timer   : unsigned(5 downto 0) := (others => '0');
    signal s_rally_count   : unsigned(7 downto 0) := (others => '0');

    -- Physics pipeline intermediate registers (8-phase FSM)
    signal s_ph_phase      : unsigned(2 downto 0) := (others => '0');
    signal s_ph_new_x      : signed(11 downto 0) := (others => '0');
    signal s_ph_new_y      : signed(11 downto 0) := (others => '0');
    signal s_ph_speed      : signed(4 downto 0)  := (others => '0');
    signal s_ph_half_pad   : signed(11 downto 0) := (others => '0');
    signal s_ph_ball_vx    : signed(4 downto 0)  := (others => '0');
    signal s_ph_ball_vy    : signed(4 downto 0)  := (others => '0');
    signal s_ph_active     : std_logic := '1';
    signal s_ph_scored     : std_logic := '0';
    signal s_ph_hit_rel    : signed(11 downto 0) := (others => '0');
    signal s_ph_hit_flag   : std_logic := '0';  -- registered paddle hit result
    -- Pre-computed paddle boundaries for physics (avoid addition in hit-detect phase)
    signal s_ph_p1_bottom  : signed(11 downto 0) := (others => '0');
    signal s_ph_p2_bottom  : signed(11 downto 0) := (others => '0');
    signal s_ph_ball_bottom : signed(11 downto 0) := (others => '0');

    -- ========================================================================
    -- Score state
    -- ========================================================================
    signal s_p1_score      : unsigned(3 downto 0) := (others => '0');
    signal s_p2_score      : unsigned(3 downto 0) := (others => '0');

    -- ========================================================================
    -- Rendering Pipeline Stage Signals
    -- ========================================================================

    -- Stage 1: registered coordinates + pre-registered boundary values (signed)
    signal s_stg1_hx           : signed(11 downto 0) := (others => '0');
    signal s_stg1_vy           : signed(11 downto 0) := (others => '0');
    -- Pre-registered signed boundary values (avoid integer→signed in comparisons)
    signal s_bnd_border_left   : signed(11 downto 0) := to_signed(C_BORDER_W, 12);
    signal s_bnd_border_right  : signed(11 downto 0) := (others => '0');
    signal s_bnd_border_top    : signed(11 downto 0) := to_signed(C_BORDER_W, 12);
    signal s_bnd_border_bottom : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad1_left     : signed(11 downto 0) := to_signed(C_PADDLE_X_P1, 12);
    signal s_bnd_pad1_right    : signed(11 downto 0) := to_signed(C_PADDLE_X_P1 + C_PADDLE_W, 12);
    signal s_bnd_pad1_top      : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad1_bottom   : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad2_left     : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad2_right    : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad2_top      : signed(11 downto 0) := (others => '0');
    signal s_bnd_pad2_bottom   : signed(11 downto 0) := (others => '0');
    signal s_bnd_ball_left     : signed(11 downto 0) := (others => '0');
    signal s_bnd_ball_right    : signed(11 downto 0) := (others => '0');
    signal s_bnd_ball_top      : signed(11 downto 0) := (others => '0');
    signal s_bnd_ball_bottom   : signed(11 downto 0) := (others => '0');
    signal s_bnd_net_left      : signed(11 downto 0) := (others => '0');
    signal s_bnd_net_right     : signed(11 downto 0) := (others => '0');
    signal s_bnd_ball_active_r : std_logic := '0';
    signal s_bnd_net_en_r      : std_logic := '0';

    -- Stage 2: individual comparison flags (registered)
    signal s_stg2_h_ge_border_left  : std_logic := '0';
    signal s_stg2_h_lt_border_right : std_logic := '0';
    signal s_stg2_v_ge_border_top   : std_logic := '0';
    signal s_stg2_v_lt_border_bot   : std_logic := '0';
    signal s_stg2_h_ge_pad1_left    : std_logic := '0';
    signal s_stg2_h_lt_pad1_right   : std_logic := '0';
    signal s_stg2_v_ge_pad1_top     : std_logic := '0';
    signal s_stg2_v_lt_pad1_bot     : std_logic := '0';
    signal s_stg2_h_ge_pad2_left    : std_logic := '0';
    signal s_stg2_h_lt_pad2_right   : std_logic := '0';
    signal s_stg2_v_ge_pad2_top     : std_logic := '0';
    signal s_stg2_v_lt_pad2_bot     : std_logic := '0';
    signal s_stg2_h_ge_ball_left    : std_logic := '0';
    signal s_stg2_h_lt_ball_right   : std_logic := '0';
    signal s_stg2_v_ge_ball_top     : std_logic := '0';
    signal s_stg2_v_lt_ball_bot     : std_logic := '0';
    signal s_stg2_h_ge_net_left     : std_logic := '0';
    signal s_stg2_h_lt_net_right    : std_logic := '0';
    signal s_stg2_net_dash          : std_logic := '0';
    signal s_stg2_ball_active_r     : std_logic := '0';
    signal s_stg2_net_en_r          : std_logic := '0';
    -- Pass-through for score in stage 2
    signal s_stg2_hx               : signed(11 downto 0) := (others => '0');
    signal s_stg2_vy               : signed(11 downto 0) := (others => '0');

    -- Stage 3: combined hit-test results (registered)
    signal s_stg3_on_ball    : std_logic := '0';
    signal s_stg3_on_pad1    : std_logic := '0';
    signal s_stg3_on_pad2    : std_logic := '0';
    signal s_stg3_on_net     : std_logic := '0';
    signal s_stg3_on_border  : std_logic := '0';
    -- Pre-computed score coordinate deltas for stage 4
    signal s_stg3_dx_p1      : signed(11 downto 0) := (others => '0');
    signal s_stg3_dy_p1      : signed(11 downto 0) := (others => '0');
    signal s_stg3_dx_p2      : signed(11 downto 0) := (others => '0');
    signal s_stg3_dy_p2      : signed(11 downto 0) := (others => '0');

    -- Stage 4: score digit lookup result + pipeline pass-through (registered)
    signal s_stg4_on_ball    : std_logic := '0';
    signal s_stg4_on_pad1    : std_logic := '0';
    signal s_stg4_on_pad2    : std_logic := '0';
    signal s_stg4_on_net     : std_logic := '0';
    signal s_stg4_on_border  : std_logic := '0';
    signal s_stg4_on_score   : std_logic := '0';

    -- Stage 5: color mux output (registered)
    signal s_out_y         : unsigned(9 downto 0) := (others => '0');
    signal s_out_u         : unsigned(9 downto 0) := C_CHROMA_MID;
    signal s_out_v         : unsigned(9 downto 0) := C_CHROMA_MID;

    -- Sync pipeline (11 entries: 7 render + 4 interpolator = 11 clocks)
    type t_sync_pipe is array (0 to 10) of std_logic_vector(3 downto 0);
    signal s_sync_pipe     : t_sync_pipe := (others => (others => '0'));

    -- Data delay for pass-through / mix (matches 7-clock render pipeline)
    constant C_DELAY : integer := 7;
    type t_data_delay is array (0 to C_DELAY - 1) of std_logic_vector(9 downto 0);
    signal s_y_delay : t_data_delay := (others => (others => '0'));
    signal s_u_delay : t_data_delay := (others => (others => '0'));
    signal s_v_delay : t_data_delay := (others => (others => '0'));

    -- Effective mix amount (fader in AI mode; fully wet in manual P2 mode)
    signal s_eff_mix      : unsigned(9 downto 0) := C_MAX_VAL;

    -- Mix outputs
    signal s_mix_y_result : unsigned(9 downto 0);
    signal s_mix_y_valid  : std_logic;
    signal s_mix_u_result : unsigned(9 downto 0);
    signal s_mix_u_valid  : std_logic;
    signal s_mix_v_result : unsigned(9 downto 0);
    signal s_mix_v_valid  : std_logic;

    -- Pre-computed paddle target positions (continuously registered, 2-stage pipeline)
    -- Stage A: multiply  (10-bit pot × 11-bit resolution = 21-bit product)
    -- Stage B: shift + clamp  (registered result ready for physics FSM)
    signal s_p1_target_mul   : unsigned(20 downto 0) := (others => '0');
    signal s_p2_target_mul   : unsigned(20 downto 0) := (others => '0');
    signal s_p1_target_pos   : signed(11 downto 0) := (others => '0');
    signal s_p2_target_pos   : signed(11 downto 0) := (others => '0');
    signal s_paddle_max_y    : signed(11 downto 0) := (others => '0');

    -- Ball speed base (2..9 pixels/frame)
    signal s_ball_speed    : unsigned(3 downto 0);

    -- Flash effect on score
    signal s_score_flash   : unsigned(3 downto 0) := (others => '0');
    -- IO alignment registers (2 stages for div-4 total delay)
    signal s_io_0 : t_video_stream_yuv444_30b;
    signal s_io_1 : t_video_stream_yuv444_30b;

begin

    -- ========================================================================
    -- Auto-Measure Active Resolution
    -- ========================================================================
    -- Counts actual active pixels per line and active lines per frame from
    -- the timing signals.  This replaces resolution_pkg lookups and works
    -- correctly with any clock division factor or simulation decimation.
    p_measure_resolution : process(clk)
    begin
        if rising_edge(clk) then
            -- Horizontal: count active pixels per line, latch on hsync
            if s_timing.hsync_start = '1' then
                if s_h_pixel_counter > 0 then
                    s_measured_h <= s_h_pixel_counter;
                end if;
                s_h_pixel_counter <= (others => '0');
            elsif s_timing.avid = '1' then
                s_h_pixel_counter <= s_h_pixel_counter + 1;
            end if;

            -- Vertical: count active lines per frame, latch on vsync
            if s_timing.vsync_start = '1' then
                if s_v_line_counter > 0 then
                    s_measured_v <= s_v_line_counter;
                end if;
                s_v_line_counter <= (others => '0');
            elsif s_timing.avid_start = '1' then
                s_v_line_counter <= s_v_line_counter + 1;
            end if;
        end if;
    end process;

    -- Derive geometry from measured resolution (registered for timing)
    p_resolution : process(clk)
    begin
        if rising_edge(clk) then
            s_h_active    <= to_integer(s_measured_h);
            s_v_active    <= to_integer(s_measured_v);
            s_h_center    <= to_integer(s_measured_h(11 downto 1));
            s_v_center    <= to_integer(s_measured_v(11 downto 1));
            s_paddle_x_p2 <= to_integer(s_measured_h) - 80 - 16;
            -- Score positions: centered ±h_active/8 horizontally,
            -- v_active/27 from top (≈40px at 1080, ≈10px at 270)
            s_score_p1_x  <= to_integer(s_measured_h(11 downto 1))
                           - to_integer(s_measured_h(11 downto 3));
            s_score_p2_x  <= to_integer(s_measured_h(11 downto 1))
                           + to_integer(s_measured_h(11 downto 3))
                           - C_DIGIT_W * C_DIGIT_SCALE;
            s_score_y     <= to_integer(s_measured_v(11 downto 4))
                           + to_integer(s_measured_v(11 downto 5));
        end if;
    end process;

    -- ========================================================================
    -- Register Mapping
    -- ========================================================================
    s_speed_pot    <= unsigned(registers_in(0));
    s_padsize_pot  <= unsigned(registers_in(1));
    s_p1_pos_pot   <= unsigned(registers_in(2));
    s_ai_skill_pot <= unsigned(registers_in(3));
    s_hue_pot      <= unsigned(registers_in(4));
    s_bright_pot   <= unsigned(registers_in(5));
    s_p2_manual    <= registers_in(6)(0);
    s_net_en       <= registers_in(6)(1);
    s_score_en     <= registers_in(6)(2);
    s_color_mode   <= registers_in(6)(3);
    s_wide         <= registers_in(6)(4);
    s_mix_amount   <= unsigned(registers_in(7));

    -- Effective mix: fader controls mix in AI mode; fully wet in manual P2 mode
    p_eff_mix : process(clk)
    begin
        if rising_edge(clk) then
            if s_p2_manual = '1' then
                s_eff_mix <= C_MAX_VAL;
            else
                s_eff_mix <= s_mix_amount;
            end if;
        end if;
    end process;

    -- Paddle height: 40 + pot/4 ~ 40..295 (wide: 80 + pot/2 ~ 80..590)
    -- Registered to break combinational path from registers_in → carry chains
    p_paddle_h : process(clk)
    begin
        if rising_edge(clk) then
            if s_wide = '1' then
                s_paddle_h <= to_unsigned(80, 9) +
                              resize(shift_right(s_padsize_pot, 1), 9);
            else
                s_paddle_h <= to_unsigned(40, 9) +
                              resize(shift_right(s_padsize_pot, 2), 9);
            end if;
        end if;
    end process;

    -- Ball speed: 2 + pot/128 ~ 2..9 (registered)
    p_ball_speed : process(clk)
    begin
        if rising_edge(clk) then
            s_ball_speed <= resize(shift_right(s_speed_pot, 7), 4) + to_unsigned(2, 4);
        end if;
    end process;

    -- ========================================================================
    -- Paddle Target Pre-computation (2-stage pipeline, runs every clock)
    --   Stage A: register multiply result
    --   Stage B: shift, clamp, and register final target
    -- ========================================================================
    p_paddle_target_a : process(clk)
    begin
        if rising_edge(clk) then
            s_p1_target_mul <= s_p1_pos_pot * to_unsigned(s_v_active, 11);
            s_p2_target_mul <= s_mix_amount * to_unsigned(s_v_active, 11);
            s_paddle_max_y  <= to_signed(s_v_active, 12) -
                               signed(resize(s_paddle_h, 12));
        end if;
    end process;

    p_paddle_target_b : process(clk)
        variable v_p1_raw : signed(11 downto 0);
        variable v_p2_raw : signed(11 downto 0);
    begin
        if rising_edge(clk) then
            v_p1_raw := signed(resize(shift_right(s_p1_target_mul, 10), 12));
            if v_p1_raw > s_paddle_max_y then
                s_p1_target_pos <= s_paddle_max_y;
            else
                s_p1_target_pos <= v_p1_raw;
            end if;

            v_p2_raw := signed(resize(shift_right(s_p2_target_mul, 10), 12));
            if v_p2_raw > s_paddle_max_y then
                s_p2_target_pos <= s_paddle_max_y;
            else
                s_p2_target_pos <= v_p2_raw;
            end if;
        end if;
    end process;

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
    -- Position Counters
    -- ========================================================================
    pixel_counter_inst : entity work.pixel_counter
        port map (
            clk     => clk,
            timing  => s_timing,
            h_count => s_h_count,
            v_count => s_v_count
        );

    -- ========================================================================
    -- Paddle Positioning + Ball Physics (8-phase pipelined FSM)
    --   Spreads the vsync-triggered physics update over 8 clock cycles
    --   to avoid long combinational carry chains in a single cycle.
    --
    --   Phase 0: Register inputs, compute new position, paddle targets
    --   Phase 1: Wall bounce check
    --   Phase 2: P1 paddle hit detection (register flags + hit_rel)
    --   Phase 3: P1 angle response (use registered hit_rel)
    --   Phase 4: P2 paddle hit detection (register flags + hit_rel)
    --   Phase 5: P2 angle response (use registered hit_rel)
    --   Phase 6: Score check (ball exits court)
    --   Phase 7: Commit results to game state
    -- ========================================================================
    p_physics : process(clk)
        variable v_ai_step       : signed(4 downto 0);
        variable v_diff          : signed(11 downto 0);
        variable v_new_vy        : signed(4 downto 0);
    begin
        if rising_edge(clk) then

            -- ----------------------------------------------------------------
            -- Phase 0: Triggered by vsync_start — register inputs
            -- ----------------------------------------------------------------
            if s_timing.vsync_start = '1' then

                -- === Paddle update (uses pre-computed targets) ===
                -- Player 1: direct pot control (target already clamped)
                s_p1_y <= s_p1_target_pos;

                -- Player 2: AI or manual
                if s_p2_manual = '1' then
                    -- Manual: use pre-computed target (already clamped)
                    s_p2_y <= s_p2_target_pos;
                else
                    v_ai_step := signed(resize(
                        shift_right(s_ai_skill_pot, 7), 5)) + to_signed(1, 5);
                    s_p2_target <= s_ball_y -
                                   signed(resize(shift_right(s_paddle_h, 1), 12));
                    v_diff := s_p2_target - s_p2_y;
                    if v_diff > resize(v_ai_step, 12) then
                        s_p2_y <= s_p2_y + resize(v_ai_step, 12);
                    elsif v_diff < -resize(v_ai_step, 12) then
                        s_p2_y <= s_p2_y - resize(v_ai_step, 12);
                    else
                        s_p2_y <= s_p2_target;
                    end if;
                    if s_p2_y < to_signed(C_BORDER_W, 12) then
                        s_p2_y <= to_signed(C_BORDER_W, 12);
                    elsif s_p2_y > s_paddle_max_y - to_signed(C_BORDER_W, 12) then
                        s_p2_y <= s_paddle_max_y - to_signed(C_BORDER_W, 12);
                    end if;
                end if;

                -- === Ball physics phase 0 ===
                -- Decay score flash
                if s_score_flash > 0 then
                    s_score_flash <= s_score_flash - 1;
                end if;

                if s_ball_active = '0' then
                    -- Serve delay
                    if s_serve_timer > 0 then
                        s_serve_timer <= s_serve_timer - 1;
                    else
                        s_ball_active <= '1';
                        s_ball_x <= to_signed(s_h_center - C_BALL_SIZE / 2, 12);
                        s_ball_y <= to_signed(s_v_center - C_BALL_SIZE / 2, 12);
                        s_rally_count <= (others => '0');
                        if s_serve_dir = C_SERVE_RIGHT then
                            s_ball_vx <= signed(resize(s_ball_speed, 5));
                        else
                            s_ball_vx <= -signed(resize(s_ball_speed, 5));
                        end if;
                        s_ball_vy <= to_signed(2, 5);
                    end if;
                else
                    -- Compute new position + register intermediates
                    s_ph_new_x    <= s_ball_x + resize(s_ball_vx, 12);
                    s_ph_new_y    <= s_ball_y + resize(s_ball_vy, 12);
                    s_ph_speed    <= signed(resize(s_ball_speed, 5));
                    s_ph_half_pad <= signed(resize(shift_right(s_paddle_h, 1), 12));
                    -- Apply current speed pot immediately while preserving direction.
                    if s_ball_vx < to_signed(0, 5) then
                        s_ph_ball_vx <= -signed(resize(s_ball_speed, 5));
                    else
                        s_ph_ball_vx <= signed(resize(s_ball_speed, 5));
                    end if;
                    s_ph_ball_vy  <= s_ball_vy;
                    s_ph_active   <= '1';
                    s_ph_scored   <= '0';
                    -- Pre-compute paddle bottom bounds (avoid addition during hit-detect)
                    s_ph_p1_bottom  <= s_p1_y + signed(resize(s_paddle_h, 12));
                    s_ph_p2_bottom  <= s_p2_y + signed(resize(s_paddle_h, 12));
                    s_ph_ball_bottom <= s_ball_y + resize(s_ball_vy, 12) + to_signed(C_BALL_SIZE, 12);
                    s_ph_phase    <= to_unsigned(1, 3);  -- advance to phase 1
                end if;

            -- ----------------------------------------------------------------
            -- Phase 1: Wall bounce check
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(1, 3) then
                if s_ph_new_y <= to_signed(C_BORDER_W, 12) then
                    s_ph_new_y   <= to_signed(C_BORDER_W + 1, 12);
                    s_ph_ball_vy <= -s_ph_ball_vy;
                    s_ph_ball_bottom <= to_signed(C_BORDER_W + 1 + C_BALL_SIZE, 12);
                elsif s_ph_new_y >= to_signed(s_v_active - C_BORDER_W - C_BALL_SIZE, 12) then
                    s_ph_new_y   <= to_signed(s_v_active - C_BORDER_W - C_BALL_SIZE - 1, 12);
                    s_ph_ball_vy <= -s_ph_ball_vy;
                    s_ph_ball_bottom <= to_signed(s_v_active - C_BORDER_W - 1, 12);
                end if;
                s_ph_phase <= to_unsigned(2, 3);

            -- ----------------------------------------------------------------
            -- Phase 2: P1 paddle hit detection (register flags + hit_rel)
            --   Uses pre-computed s_ph_p1_bottom and s_ph_ball_bottom
            --   to avoid carry chains in this phase.
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(2, 3) then
                if s_ph_new_x <= to_signed(C_PADDLE_X_P1 + C_PADDLE_W, 12) and
                   s_ph_new_x >= to_signed(C_PADDLE_X_P1, 12) and
                   s_ph_ball_bottom >= s_p1_y and
                   s_ph_new_y <= s_ph_p1_bottom then
                    s_ph_hit_flag <= '1';
                    s_ph_new_x    <= to_signed(C_PADDLE_X_P1 + C_PADDLE_W + 1, 12);
                    s_ph_ball_vx  <= s_ph_speed;
                    if s_rally_count < to_unsigned(255, 8) then
                        s_rally_count <= s_rally_count + 1;
                    end if;
                else
                    s_ph_hit_flag <= '0';
                end if;
                -- Pre-compute hit_rel for angle lookup in phase 3
                s_ph_hit_rel <= (s_ph_new_y + to_signed(C_BALL_SIZE / 2, 12))
                              - (s_p1_y + s_ph_half_pad);
                s_ph_phase <= to_unsigned(3, 3);

            -- ----------------------------------------------------------------
            -- Phase 3: P1 angle response (use registered hit_flag + hit_rel)
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(3, 3) then
                if s_ph_hit_flag = '1' then
                    v_new_vy := to_signed(4, 5);  -- default: steep
                    if s_ph_hit_rel < -s_ph_half_pad + to_signed(4, 12) then
                        v_new_vy := to_signed(-4, 5);
                    elsif s_ph_hit_rel < to_signed(-8, 12) then
                        v_new_vy := to_signed(-3, 5);
                    elsif s_ph_hit_rel < to_signed(-2, 12) then
                        v_new_vy := to_signed(-1, 5);
                    elsif s_ph_hit_rel < to_signed(2, 12) then
                        v_new_vy := to_signed(0, 5);
                    elsif s_ph_hit_rel < to_signed(8, 12) then
                        v_new_vy := to_signed(1, 5);
                    elsif s_ph_hit_rel < s_ph_half_pad - to_signed(4, 12) then
                        v_new_vy := to_signed(3, 5);
                    end if;
                    s_ph_ball_vy <= v_new_vy;
                end if;
                s_ph_phase <= to_unsigned(4, 3);

            -- ----------------------------------------------------------------
            -- Phase 4: P2 paddle hit detection (register flags + hit_rel)
            --   Uses pre-computed s_ph_p2_bottom and s_ph_ball_bottom.
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(4, 3) then
                if s_ph_new_x + to_signed(C_BALL_SIZE, 12) >= to_signed(s_paddle_x_p2, 12) and
                   s_ph_new_x <= to_signed(s_paddle_x_p2 + C_PADDLE_W, 12) and
                   s_ph_ball_bottom >= s_p2_y and
                   s_ph_new_y <= s_ph_p2_bottom then
                    s_ph_hit_flag <= '1';
                    s_ph_new_x    <= to_signed(s_paddle_x_p2 - C_BALL_SIZE - 1, 12);
                    s_ph_ball_vx  <= -s_ph_speed;
                    if s_rally_count < to_unsigned(255, 8) then
                        s_rally_count <= s_rally_count + 1;
                    end if;
                else
                    s_ph_hit_flag <= '0';
                end if;
                -- Pre-compute hit_rel for angle lookup in phase 5
                s_ph_hit_rel <= (s_ph_new_y + to_signed(C_BALL_SIZE / 2, 12))
                              - (s_p2_y + s_ph_half_pad);
                s_ph_phase <= to_unsigned(5, 3);

            -- ----------------------------------------------------------------
            -- Phase 5: P2 angle response (use registered hit_flag + hit_rel)
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(5, 3) then
                if s_ph_hit_flag = '1' then
                    v_new_vy := to_signed(4, 5);  -- default: steep
                    if s_ph_hit_rel < -s_ph_half_pad + to_signed(4, 12) then
                        v_new_vy := to_signed(-4, 5);
                    elsif s_ph_hit_rel < to_signed(-8, 12) then
                        v_new_vy := to_signed(-3, 5);
                    elsif s_ph_hit_rel < to_signed(-2, 12) then
                        v_new_vy := to_signed(-1, 5);
                    elsif s_ph_hit_rel < to_signed(2, 12) then
                        v_new_vy := to_signed(0, 5);
                    elsif s_ph_hit_rel < to_signed(8, 12) then
                        v_new_vy := to_signed(1, 5);
                    elsif s_ph_hit_rel < s_ph_half_pad - to_signed(4, 12) then
                        v_new_vy := to_signed(3, 5);
                    end if;
                    s_ph_ball_vy <= v_new_vy;
                end if;
                s_ph_phase <= to_unsigned(6, 3);

            -- ----------------------------------------------------------------
            -- Phase 6: Score check
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(6, 3) then
                -- Ball exits left (P2 scores)
                if s_ph_new_x < to_signed(0, 12) then
                    s_ph_active <= '0';
                    s_ph_scored <= '1';
                    s_serve_timer <= to_unsigned(30, 6);
                    s_serve_dir <= C_SERVE_LEFT;
                    s_score_flash <= to_unsigned(8, 4);
                    if s_p2_score < to_unsigned(9, 4) then
                        s_p2_score <= s_p2_score + 1;
                    else
                        s_p1_score <= (others => '0');
                        s_p2_score <= (others => '0');
                    end if;
                end if;
                -- Ball exits right (P1 scores)
                if s_ph_new_x > to_signed(s_h_active, 12) then
                    s_ph_active <= '0';
                    s_ph_scored <= '1';
                    s_serve_timer <= to_unsigned(30, 6);
                    s_serve_dir <= C_SERVE_RIGHT;
                    s_score_flash <= to_unsigned(8, 4);
                    if s_p1_score < to_unsigned(9, 4) then
                        s_p1_score <= s_p1_score + 1;
                    else
                        s_p1_score <= (others => '0');
                        s_p2_score <= (others => '0');
                    end if;
                end if;
                s_ph_phase <= to_unsigned(7, 3);

            -- ----------------------------------------------------------------
            -- Phase 7: Commit results
            -- ----------------------------------------------------------------
            elsif s_ph_phase = to_unsigned(7, 3) then
                s_ball_x  <= s_ph_new_x;
                s_ball_y  <= s_ph_new_y;
                s_ball_vx <= s_ph_ball_vx;
                s_ball_vy <= s_ph_ball_vy;
                if s_ph_active = '0' then
                    s_ball_active <= '0';
                end if;
                s_ph_phase <= to_unsigned(0, 3);  -- idle
            end if;

        end if;
    end process;

    -- ========================================================================
    -- Rendering Pipeline — Stage 1: Register Coordinates + Boundary Values
    --   Converts all integer game-state positions to signed registers so
    --   downstream comparisons are pure register-to-register (no
    --   integer→signed conversion in the comparison path).
    -- ========================================================================
    p_stage1_coords : process(clk)
    begin
        if rising_edge(clk) then
            -- Register pixel coordinates as signed
            s_stg1_hx <= signed(resize(s_h_count, 12));
            s_stg1_vy <= signed(resize(s_v_count, 12));

            -- Pre-register all boundary values as signed
            s_bnd_border_right  <= to_signed(s_h_active - C_BORDER_W, 12);
            s_bnd_border_bottom <= to_signed(s_v_active - C_BORDER_W, 12);

            s_bnd_pad1_top    <= s_p1_y;
            s_bnd_pad1_bottom <= s_p1_y + signed(resize(s_paddle_h, 12));

            s_bnd_pad2_left   <= to_signed(s_paddle_x_p2, 12);
            s_bnd_pad2_right  <= to_signed(s_paddle_x_p2 + C_PADDLE_W, 12);
            s_bnd_pad2_top    <= s_p2_y;
            s_bnd_pad2_bottom <= s_p2_y + signed(resize(s_paddle_h, 12));

            s_bnd_ball_left   <= s_ball_x;
            s_bnd_ball_right  <= s_ball_x + to_signed(C_BALL_SIZE, 12);
            s_bnd_ball_top    <= s_ball_y;
            s_bnd_ball_bottom <= s_ball_y + to_signed(C_BALL_SIZE, 12);

            s_bnd_net_left    <= to_signed(s_h_center - C_NET_W / 2, 12);
            s_bnd_net_right   <= to_signed(s_h_center + C_NET_W / 2, 12);

            s_bnd_ball_active_r <= s_ball_active;
            s_bnd_net_en_r      <= s_net_en;
        end if;
    end process;

    -- ========================================================================
    -- Rendering Pipeline — Stage 2: Individual Comparison Flags
    --   Each comparison is a simple signed register vs signed register.
    --   No arithmetic or type conversions — just magnitude comparison.
    -- ========================================================================
    p_stage2_compare : process(clk)
    begin
        if rising_edge(clk) then
            -- Border region flags (border = NOT inside active area)
            if s_stg1_hx < s_bnd_border_left then
                s_stg2_h_ge_border_left <= '0';
            else
                s_stg2_h_ge_border_left <= '1';
            end if;

            if s_stg1_hx < s_bnd_border_right then
                s_stg2_h_lt_border_right <= '1';
            else
                s_stg2_h_lt_border_right <= '0';
            end if;

            if s_stg1_vy < s_bnd_border_top then
                s_stg2_v_ge_border_top <= '0';
            else
                s_stg2_v_ge_border_top <= '1';
            end if;

            if s_stg1_vy < s_bnd_border_bottom then
                s_stg2_v_lt_border_bot <= '1';
            else
                s_stg2_v_lt_border_bot <= '0';
            end if;

            -- Paddle 1 comparison flags
            if s_stg1_hx >= s_bnd_pad1_left then
                s_stg2_h_ge_pad1_left <= '1';
            else
                s_stg2_h_ge_pad1_left <= '0';
            end if;

            if s_stg1_hx < s_bnd_pad1_right then
                s_stg2_h_lt_pad1_right <= '1';
            else
                s_stg2_h_lt_pad1_right <= '0';
            end if;

            if s_stg1_vy >= s_bnd_pad1_top then
                s_stg2_v_ge_pad1_top <= '1';
            else
                s_stg2_v_ge_pad1_top <= '0';
            end if;

            if s_stg1_vy < s_bnd_pad1_bottom then
                s_stg2_v_lt_pad1_bot <= '1';
            else
                s_stg2_v_lt_pad1_bot <= '0';
            end if;

            -- Paddle 2 comparison flags
            if s_stg1_hx >= s_bnd_pad2_left then
                s_stg2_h_ge_pad2_left <= '1';
            else
                s_stg2_h_ge_pad2_left <= '0';
            end if;

            if s_stg1_hx < s_bnd_pad2_right then
                s_stg2_h_lt_pad2_right <= '1';
            else
                s_stg2_h_lt_pad2_right <= '0';
            end if;

            if s_stg1_vy >= s_bnd_pad2_top then
                s_stg2_v_ge_pad2_top <= '1';
            else
                s_stg2_v_ge_pad2_top <= '0';
            end if;

            if s_stg1_vy < s_bnd_pad2_bottom then
                s_stg2_v_lt_pad2_bot <= '1';
            else
                s_stg2_v_lt_pad2_bot <= '0';
            end if;

            -- Ball comparison flags
            if s_stg1_hx >= s_bnd_ball_left then
                s_stg2_h_ge_ball_left <= '1';
            else
                s_stg2_h_ge_ball_left <= '0';
            end if;

            if s_stg1_hx < s_bnd_ball_right then
                s_stg2_h_lt_ball_right <= '1';
            else
                s_stg2_h_lt_ball_right <= '0';
            end if;

            if s_stg1_vy >= s_bnd_ball_top then
                s_stg2_v_ge_ball_top <= '1';
            else
                s_stg2_v_ge_ball_top <= '0';
            end if;

            if s_stg1_vy < s_bnd_ball_bottom then
                s_stg2_v_lt_ball_bot <= '1';
            else
                s_stg2_v_lt_ball_bot <= '0';
            end if;

            -- Net comparison flags
            if s_stg1_hx >= s_bnd_net_left then
                s_stg2_h_ge_net_left <= '1';
            else
                s_stg2_h_ge_net_left <= '0';
            end if;

            if s_stg1_hx < s_bnd_net_right then
                s_stg2_h_lt_net_right <= '1';
            else
                s_stg2_h_lt_net_right <= '0';
            end if;

            -- Net dash pattern flag
            if unsigned(s_stg1_vy(4 downto 0)) < to_unsigned(C_NET_DASH_H, 5) then
                s_stg2_net_dash <= '1';
            else
                s_stg2_net_dash <= '0';
            end if;

            -- Pass-through state
            s_stg2_ball_active_r <= s_bnd_ball_active_r;
            s_stg2_net_en_r      <= s_bnd_net_en_r;

            -- Pass hx/vy for score coordinate deltas in stage 3
            s_stg2_hx <= s_stg1_hx;
            s_stg2_vy <= s_stg1_vy;
        end if;
    end process;

    -- ========================================================================
    -- Rendering Pipeline — Stage 3: Combine Comparison Flags
    --   Pure AND/OR of single-bit registered flags — very shallow logic.
    --   Also pre-compute score coordinate deltas for stage 4.
    -- ========================================================================
    p_stage3_combine : process(clk)
    begin
        if rising_edge(clk) then
            -- Ball: all four bounds + active
            if s_stg2_ball_active_r = '1' and
               s_stg2_h_ge_ball_left = '1' and s_stg2_h_lt_ball_right = '1' and
               s_stg2_v_ge_ball_top = '1' and s_stg2_v_lt_ball_bot = '1' then
                s_stg3_on_ball <= '1';
            else
                s_stg3_on_ball <= '0';
            end if;

            -- Paddle 1
            if s_stg2_h_ge_pad1_left = '1' and s_stg2_h_lt_pad1_right = '1' and
               s_stg2_v_ge_pad1_top = '1' and s_stg2_v_lt_pad1_bot = '1' then
                s_stg3_on_pad1 <= '1';
            else
                s_stg3_on_pad1 <= '0';
            end if;

            -- Paddle 2
            if s_stg2_h_ge_pad2_left = '1' and s_stg2_h_lt_pad2_right = '1' and
               s_stg2_v_ge_pad2_top = '1' and s_stg2_v_lt_pad2_bot = '1' then
                s_stg3_on_pad2 <= '1';
            else
                s_stg3_on_pad2 <= '0';
            end if;

            -- Net: horizontal bounds + dash pattern + net enable
            if s_stg2_net_en_r = '1' and
               s_stg2_h_ge_net_left = '1' and s_stg2_h_lt_net_right = '1' and
               s_stg2_net_dash = '1' then
                s_stg3_on_net <= '1';
            else
                s_stg3_on_net <= '0';
            end if;

            -- Border: NOT (inside all four bounds)
            if s_stg2_h_ge_border_left = '1' and s_stg2_h_lt_border_right = '1' and
               s_stg2_v_ge_border_top = '1' and s_stg2_v_lt_border_bot = '1' then
                s_stg3_on_border <= '0';  -- inside active area = not on border
            else
                s_stg3_on_border <= '1';
            end if;

            -- Pre-compute score coordinate deltas (integer subtraction)
            s_stg3_dx_p1 <= s_stg2_hx - to_signed(s_score_p1_x, 12);
            s_stg3_dy_p1 <= s_stg2_vy - to_signed(s_score_y, 12);
            s_stg3_dx_p2 <= s_stg2_hx - to_signed(s_score_p2_x, 12);
            s_stg3_dy_p2 <= s_stg2_vy - to_signed(s_score_y, 12);
        end if;
    end process;

    -- ========================================================================
    -- Rendering Pipeline — Stage 4: Score Digit Font Lookup
    --   Uses pre-computed deltas from stage 3.
    --   Division by C_DIGIT_SCALE (4) is a right-shift by 2.
    -- ========================================================================
    p_stage4_score : process(clk)
        variable v_dx_p1     : integer range -2048 to 2047;
        variable v_dy_p1     : integer range -2048 to 2047;
        variable v_dx_p2     : integer range -2048 to 2047;
        variable v_dy_p2     : integer range -2048 to 2047;
        variable v_font_col  : integer range 0 to 7;
        variable v_font_row  : integer range 0 to 7;
        variable v_digit_val : integer range 0 to 9;
        variable v_font_bit  : std_logic;
        variable v_on_score  : std_logic;
    begin
        if rising_edge(clk) then
            v_on_score := '0';

            if s_score_en = '1' then
                v_dx_p1 := to_integer(s_stg3_dx_p1);
                v_dy_p1 := to_integer(s_stg3_dy_p1);

                -- P1 digit bounding box
                if v_dx_p1 >= 0 and v_dx_p1 < C_DIGIT_W * C_DIGIT_SCALE and
                   v_dy_p1 >= 0 and v_dy_p1 < C_DIGIT_H * C_DIGIT_SCALE then
                    v_font_col := to_integer(shift_right(to_unsigned(v_dx_p1, 6), 2));
                    v_font_row := to_integer(shift_right(to_unsigned(v_dy_p1, 6), 2));
                    v_digit_val := to_integer(s_p1_score);
                    v_font_bit := C_FONT(v_digit_val * 8 + v_font_row)(4 - v_font_col);
                    if v_font_bit = '1' then
                        v_on_score := '1';
                    end if;
                end if;

                v_dx_p2 := to_integer(s_stg3_dx_p2);
                v_dy_p2 := to_integer(s_stg3_dy_p2);

                -- P2 digit bounding box
                if v_dx_p2 >= 0 and v_dx_p2 < C_DIGIT_W * C_DIGIT_SCALE and
                   v_dy_p2 >= 0 and v_dy_p2 < C_DIGIT_H * C_DIGIT_SCALE then
                    v_font_col := to_integer(shift_right(to_unsigned(v_dx_p2, 6), 2));
                    v_font_row := to_integer(shift_right(to_unsigned(v_dy_p2, 6), 2));
                    v_digit_val := to_integer(s_p2_score);
                    v_font_bit := C_FONT(v_digit_val * 8 + v_font_row)(4 - v_font_col);
                    if v_font_bit = '1' then
                        v_on_score := '1';
                    end if;
                end if;
            end if;

            -- Pass through hit-test results (pipeline delay match)
            s_stg4_on_ball   <= s_stg3_on_ball;
            s_stg4_on_pad1   <= s_stg3_on_pad1;
            s_stg4_on_pad2   <= s_stg3_on_pad2;
            s_stg4_on_net    <= s_stg3_on_net;
            s_stg4_on_border <= s_stg3_on_border;
            s_stg4_on_score  <= v_on_score;
        end if;
    end process;

    -- ========================================================================
    -- Rendering Pipeline — Stage 5: Color Mux
    -- ========================================================================
    p_stage5_colormux : process(clk)
        variable v_bright : unsigned(9 downto 0);
        variable v_obj_y  : unsigned(9 downto 0);
        variable v_obj_u  : unsigned(9 downto 0);
        variable v_obj_v  : unsigned(9 downto 0);
    begin
        if rising_edge(clk) then
            v_bright := s_bright_pot;

            if s_stg4_on_ball = '1' or s_stg4_on_pad1 = '1' or
               s_stg4_on_pad2 = '1' or s_stg4_on_score = '1' then
                -- Foreground objects: bright white (or colored)
                v_obj_y := v_bright;
                if s_color_mode = '1' then
                    v_obj_u := s_hue_pot;
                    v_obj_v := C_MAX_VAL - s_hue_pot;
                else
                    v_obj_u := C_CHROMA_MID;
                    v_obj_v := C_CHROMA_MID;
                end if;
                s_out_y <= v_obj_y;
                s_out_u <= v_obj_u;
                s_out_v <= v_obj_v;
            elsif s_stg4_on_net = '1' then
                -- Net: dimmer white
                s_out_y <= shift_right(v_bright, 1);
                s_out_u <= C_CHROMA_MID;
                s_out_v <= C_CHROMA_MID;
            elsif s_stg4_on_border = '1' then
                -- Border: dim white
                s_out_y <= shift_right(v_bright, 2);
                s_out_u <= C_CHROMA_MID;
                s_out_v <= C_CHROMA_MID;
            else
                -- Background: black (or dim flash on score)
                if s_score_flash > 0 then
                    s_out_y <= resize(shift_left(s_score_flash, 4), 10);
                else
                    s_out_y <= (others => '0');
                end if;
                s_out_u <= C_CHROMA_MID;
                s_out_v <= C_CHROMA_MID;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Sync & Data Delay Pipelines (16 clocks)
    -- ========================================================================
    p_delay_pipes : process(clk)
    begin
        if rising_edge(clk) then
            s_sync_pipe(0) <= data_in.field_n & data_in.avid &
                              data_in.vsync_n & data_in.hsync_n;
            for i in 1 to 10 loop
                s_sync_pipe(i) <= s_sync_pipe(i - 1);
            end loop;

            s_y_delay(0) <= data_in.y;
            s_u_delay(0) <= data_in.u;
            s_v_delay(0) <= data_in.v;
            for i in 1 to C_DELAY - 1 loop
                s_y_delay(i) <= s_y_delay(i - 1);
                s_u_delay(i) <= s_u_delay(i - 1);
                s_v_delay(i) <= s_v_delay(i - 1);
            end loop;
        end if;
    end process;

    -- ========================================================================
    -- Interpolator Stage -- wet/dry mix
    -- ========================================================================
    mix_y_inst : entity work.interpolator_u
        generic map(G_WIDTH => 10, G_FRAC_BITS => 10,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_y_delay(C_DELAY - 1)), b => s_out_y,
                 t => s_eff_mix,
                 result => s_mix_y_result, valid => s_mix_y_valid);

    mix_u_inst : entity work.interpolator_u
        generic map(G_WIDTH => 10, G_FRAC_BITS => 10,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_u_delay(C_DELAY - 1)), b => s_out_u,
                 t => s_eff_mix,
                 result => s_mix_u_result, valid => s_mix_u_valid);

    mix_v_inst : entity work.interpolator_u
        generic map(G_WIDTH => 10, G_FRAC_BITS => 10,
                    G_OUTPUT_MIN => 0, G_OUTPUT_MAX => 1023)
        port map(clk => clk, enable => '1',
                 a => unsigned(s_v_delay(C_DELAY - 1)), b => s_out_v,
                 t => s_eff_mix,
                 result => s_mix_v_result, valid => s_mix_v_valid);

    -- ========================================================================
    -- ========================================================================
    -- IO Alignment Registers (2 stages: 7 render + 4 interp + 2 IO = 13 total)
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            s_io_0.y       <= std_logic_vector(s_mix_y_result);
            s_io_0.u       <= std_logic_vector(s_mix_u_result);
            s_io_0.v       <= std_logic_vector(s_mix_v_result);
            s_io_0.hsync_n <= s_sync_pipe(10)(0);
            s_io_0.vsync_n <= s_sync_pipe(10)(1);
            s_io_0.avid    <= s_mix_y_valid and s_mix_u_valid and s_mix_v_valid;
            s_io_0.field_n <= s_sync_pipe(10)(3);
            s_io_1 <= s_io_0;
        end if;
    end process;

    -- Output Assignment
    -- ========================================================================
    data_out.y       <= s_io_1.y;
    data_out.u       <= s_io_1.u;
    data_out.v       <= s_io_1.v;
    data_out.hsync_n <= s_io_1.hsync_n;
    data_out.vsync_n <= s_io_1.vsync_n;
    data_out.avid    <= s_io_1.avid;
    data_out.field_n <= s_io_1.field_n;

end architecture pong;
