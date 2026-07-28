-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_sync_generator.vhd - Video Sync Generator
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
-- Description:
--   Generates bi-level and tri-level sync signals based on reference sync
--   inputs and timing configurations.
--
-- Timing Behavior:
--   Counter-based sync waveform generator with a 2-cycle timing config
--   pipeline (timing -> s_timing -> config registers). Sync outputs are
--   registered comparisons against clk/line counters.
--
--   When G_LOCK_TO_REF is true, counters snap to per-format fsync seed values
--   on ref_vsync (progressive) or ref_field_n (interlaced) edges so sync
--   output tracks the reference.
--
--   When G_LOCK_TO_REF is false, counters free-run from clk alone with no
--   external sync resets (testbench / legacy only).
--
--   When G_PHASE_ADVANCE is true, horizontal compares use v_eff_clks
--   (counter - phase_advance_clks modulo line length) and line-gated
--   compares use v_eff_lines (counter_lines - 1 on borrow) so every
--   constituent — hsync, hsync_2x, csync, csync_2x, eq_pulses,
--   csync_serration, vsync clk/line events, and AVID H/V gates — shifts
--   together across line boundaries. Register outputs hold between
--   set/clear edges as in the non-offset path.
--
--   Sync Out is intentionally DELAYED vs program *input* by
--   phase_advance_clks (firmware: processing_delay_clks + core_post) so
--   the external jack tracks the pipeline latency and coincides with
--   processed-video H at the encoder/HDMI pins under the calibrated
--   per-format fsync seeds. (The port keeps its historical name; the
--   original implementation ADVANCED the waveform, driving the jack
--   sync 2x the pipeline delay ahead of the jack video — VMT-F004.)
--   Program video ports keep H/V on the same delayed pipeline as their
--   pixels (not this generator).

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_sync_pkg.all;

entity video_sync_generator is
  generic (
    G_LOCK_TO_REF    : boolean := true;
    G_PHASE_ADVANCE  : boolean := false
  );
  port (
    clk                : in std_logic;
    ref_hsync          : in std_logic;
    ref_vsync          : in std_logic;
    ref_field_n        : in std_logic;
    timing             : in std_logic_vector(3 downto 0);
    phase_advance_clks : in unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
    trisync_p          : out std_logic;
    trisync_n          : out std_logic;
    hsync              : out std_logic;
    vsync              : out std_logic;
    avid               : out std_logic
  );
end entity;

architecture rtl of video_sync_generator is
  signal s_ref_vsync_d              : std_logic := '0';
  signal s_ref_vsync_event          : std_logic := '0';
  signal s_ref_field_n_d            : std_logic := '0';
  signal s_ref_field_event          : std_logic := '0';
  signal s_ref_fsync                : std_logic := '0';
  signal s_trisync_en               : std_logic := '0';
  signal s_timing                   : t_video_timing_id := (others => '0');
  signal s_is_interlaced            : std_logic := '0';
  signal s_fsync_clks               : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_fsync_lines              : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_hsync_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_hsync_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_hsync_clks_b_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_hsync_clks_b_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_2x_a_clks_1        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_2x_a_clks_0        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_2x_b_clks_1        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_2x_b_clks_0        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_a_clks_1       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_a_lines_1      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_a_clks_0       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_a_lines_0      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_b_clks_1       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_b_lines_1      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_b_clks_0       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_eq_pulses_b_lines_0      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_a_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_a_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_b_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_b_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_c_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_c_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_d_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_csync_serration_d_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_a_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_a_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_a_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_a_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_b_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_b_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_b_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_vsync_b_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_clocks_per_line          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_lines_per_frame          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_frame_width              : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_frame_height             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_h_active_start           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_h_active_end             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_v_active_start           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_counter_clks             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_counter_lines            : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_trisync_p                : std_logic := '0';
  signal s_trisync_n                : std_logic := '0';
  signal s_hsync                    : std_logic := '0';
  signal s_csync                    : std_logic := '0';
  signal s_csync_2x                 : std_logic := '0';
  signal s_hsync_2x                 : std_logic := '0';
  signal s_eq_pulses                : std_logic := '0';
  signal s_csync_serration          : std_logic := '0';
  signal s_vsync                    : std_logic := '0';
  signal s_avid_h                   : std_logic := '0';
  signal s_avid_v                   : std_logic := '0';
  signal s_avid                     : std_logic := '0';
  -- Timing-id change detector. When firmware switches the video standard
  -- (e.g. NTSC -> 720p60), the per-format sync-pulse register signals
  -- (s_csync, s_csync_2x, s_csync_serration, s_eq_pulses, s_vsync,
  -- s_hsync, s_hsync_2x) need to be reinitialised. Their set/clear
  -- events are configured per-format and may simply never fire in the
  -- new format, causing the registers to latch at whatever value the
  -- previous format left them at. Symptom: in 720p60 (which has all
  -- eq_pulses and csync_2x events at clk/line = 0, a position the
  -- free-running counter never revisits in steady state) s_eq_pulses
  -- and s_csync_2x would stay HIGH if NTSC left them HIGH at the
  -- moment of timing change, driving both trisync_p and trisync_n
  -- from the same stuck signal and producing zero analog output.
  signal s_timing_d                 : t_video_timing_id := (others => '0');
  signal s_timing_change            : std_logic := '0';

begin

  event_detectors : process (clk)
  begin
    if rising_edge(clk) then
      s_ref_vsync_d   <= ref_vsync;
      s_ref_field_n_d <= ref_field_n;
    end if;
  end process;

  s_ref_field_event <= '1' when ref_field_n = '0' and s_ref_field_n_d = '1' else
    '0';

  s_ref_vsync_event <= '1' when ref_vsync = '0' and s_ref_vsync_d = '1' else
    '0';

  s_ref_fsync <= s_ref_field_event when s_is_interlaced = '1' else
    s_ref_vsync_event;

  timing_config_regs : process (clk)
  begin
    if rising_edge(clk) then
      s_timing                   <= t_video_timing_id(timing);
      s_is_interlaced            <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).is_interlaced;
      s_clocks_per_line          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).clocks_per_line;
      s_lines_per_frame          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).lines_per_frame;
      s_frame_width              <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_width;
      s_frame_height             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_height;
      -- Right-align the active window inside each line at the SMPTE-
      -- correct sample position: subtract the per-format H front porch
      -- so the active region ends front_porch clocks before the next
      -- HSYNC pulse, leaving (clocks_per_line - frame_width -
      -- front_porch) = (sync_width + back_porch) of blanking before
      -- active. Without this the active window slid right by
      -- exactly front_porch clocks, varying per video standard.
      s_h_active_start           <=
        C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).clocks_per_line
        - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_width
        - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).h_front_porch;
      -- Active window ends front_porch clocks before line wrap, giving
      -- AVID a width of exactly frame_width clocks.  Without this upper
      -- bound AVID would stay high until the line wraps, widening the
      -- active region by front_porch clocks (e.g. 1280 -> 1390 for
      -- 720p60), which downstream auto-measuring programs would treat
      -- as a wider resolution and stretch their content off-screen.
      s_h_active_end             <=
        C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).clocks_per_line
        - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).h_front_porch;
      -- Vertical back-porch threshold: active video starts after this many
      -- lines from the per-field (interlaced) or per-frame (progressive)
      -- counter reset. Approximation collapses all V blanking to the start
      -- of the field/frame, which blanks a few extra lines of the front
      -- porch (already at blanking level in the source) but never crops
      -- real active video from the top of the picture.
      if C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).is_interlaced = '1' then
        s_v_active_start <= shift_right(
          C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).lines_per_frame
          - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_height, 1);
      else
        s_v_active_start <=
          C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).lines_per_frame
          - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_height;
      end if;
      s_fsync_clks               <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).fsync_clks;
      s_fsync_lines              <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).fsync_lines;
      s_hsync_clks_0             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_0;
      s_hsync_clks_1             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_1;
      s_hsync_clks_b_1           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_b_1;
      s_hsync_clks_b_0           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_b_0;
      s_csync_clks_1             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_clks_1;
      s_csync_clks_0             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_clks_0;
      s_csync_2x_a_clks_1        <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_2x_a_clks_1;
      s_csync_2x_a_clks_0        <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_2x_a_clks_0;
      s_csync_2x_b_clks_1        <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_2x_b_clks_1;
      s_csync_2x_b_clks_0        <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_2x_b_clks_0;
      s_eq_pulses_a_clks_1       <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_a_clks_1;
      s_eq_pulses_a_lines_1      <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_a_lines_1;
      s_eq_pulses_a_clks_0       <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_a_clks_0;
      s_eq_pulses_a_lines_0      <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_a_lines_0;
      s_eq_pulses_b_clks_1       <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_b_clks_1;
      s_eq_pulses_b_lines_1      <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_b_lines_1;
      s_eq_pulses_b_clks_0       <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_b_clks_0;
      s_eq_pulses_b_lines_0      <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).eq_pulses_b_lines_0;
      s_csync_serration_a_clks_1 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_a_clks_1;
      s_csync_serration_a_clks_0 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_a_clks_0;
      s_csync_serration_b_clks_1 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_b_clks_1;
      s_csync_serration_b_clks_0 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_b_clks_0;
      s_csync_serration_c_clks_1 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_c_clks_1;
      s_csync_serration_c_clks_0 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_c_clks_0;
      s_csync_serration_d_clks_1 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_d_clks_1;
      s_csync_serration_d_clks_0 <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).csync_serration_d_clks_0;
      s_vsync_a_clks_1           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_a_clks_1;
      s_vsync_a_lines_1          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_a_lines_1;
      s_vsync_a_clks_0           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_a_clks_0;
      s_vsync_a_lines_0          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_a_lines_0;
      s_vsync_b_clks_1           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_b_clks_1;
      s_vsync_b_lines_1          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_b_lines_1;
      s_vsync_b_clks_0           <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_b_clks_0;
      s_vsync_b_lines_0          <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).vsync_b_lines_0;
      s_trisync_en               <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).trisync_en;
    end if;
  end process;

  -- Counter behavior:
  --   * G_LOCK_TO_REF true: snap to fsync seed on ref_vsync/field edge,
  --     then wrap at s_clocks_per_line / s_lines_per_frame.
  --   * G_LOCK_TO_REF false: pure free-run (standalone only).
  counters : process (clk)
  begin
    if rising_edge(clk) then
      if G_LOCK_TO_REF and s_ref_fsync = '1' then
        s_counter_clks <= s_fsync_clks;
        s_counter_lines <= s_fsync_lines;
      elsif s_counter_clks = s_clocks_per_line then
        s_counter_clks <= to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH);
        if s_counter_lines = s_lines_per_frame then
          s_counter_lines <= to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH);
        else
          s_counter_lines <= s_counter_lines + to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH);
        end if;
      else
        s_counter_clks <= s_counter_clks + to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH);
      end if;
    end if;
  end process;

  sync_gen : process (clk)
    variable v_eff_clks  : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
    variable v_eff_lines : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  begin
    if rising_edge(clk) then
      s_timing_d <= s_timing;
      if s_timing /= s_timing_d then
        s_timing_change <= '1';
      else
        s_timing_change <= '0';
      end if;

      v_eff_clks  := s_counter_clks;
      v_eff_lines := s_counter_lines;
      if G_PHASE_ADVANCE then
        -- Positive register values DELAY the jack waveform by that many
        -- clocks so Sync Out tracks the processed video, which emerges
        -- prog_delay + core_post clocks after the program input this
        -- generator locks to. (The register was historically applied as
        -- an ADVANCE — subtracted here as an effective-counter offset —
        -- which moved the jack waveform AWAY from the delayed output:
        -- jack sync led jack video by 2x the pipeline delay, found by
        -- the vmtest processing-delay validation, VMT-F004.)
        if s_counter_clks <= phase_advance_clks then
          v_eff_clks := s_counter_clks + s_clocks_per_line - phase_advance_clks;
          -- Horizontal borrow retreats the *effective* line so eq/vsync
          -- line gates stay coupled to v_eff_clks (mirror of the
          -- Fix C / rc.37 wrap).
          if s_counter_lines = to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH) then
            v_eff_lines := s_lines_per_frame;
          else
            v_eff_lines := s_counter_lines - to_unsigned(1, C_VIDEO_SYNC_DATA_WIDTH);
          end if;
        else
          v_eff_clks := s_counter_clks - phase_advance_clks;
        end if;
      end if;

      -- On any timing-id change, force all derived sync-pulse signals
      -- to a known LOW state. The per-format set events resume
      -- driving them on subsequent cycles.
      if s_timing_change = '1' then
        s_hsync           <= '0';
        s_hsync_2x        <= '0';
        s_csync           <= '0';
        s_csync_2x        <= '0';
        s_eq_pulses       <= '0';
        s_csync_serration <= '0';
        s_vsync           <= '0';
      else
        if v_eff_clks = s_hsync_clks_0 then
          s_hsync    <= '0';
          s_hsync_2x <= '0';
        elsif v_eff_clks = s_hsync_clks_1 then
          s_hsync    <= '1';
          s_hsync_2x <= '1';
        end if;

        if v_eff_clks = s_csync_clks_0 then
          s_csync <= '0';
        elsif v_eff_clks = s_csync_clks_1 then
          s_csync <= '1';
        end if;

        if v_eff_clks = s_hsync_clks_b_0 then
          s_hsync_2x <= '0';
        elsif v_eff_clks = s_hsync_clks_b_1 then
          s_hsync_2x <= '1';
        end if;

        if v_eff_clks = s_csync_2x_a_clks_0 or v_eff_clks = s_csync_2x_b_clks_0 then
          s_csync_2x <= '0';
        elsif v_eff_clks = s_csync_2x_a_clks_1 or v_eff_clks = s_csync_2x_b_clks_1 then
          s_csync_2x <= '1';
        end if;

        if (v_eff_lines = s_eq_pulses_a_lines_0 and v_eff_clks = s_eq_pulses_a_clks_0) or
           (v_eff_lines = s_eq_pulses_b_lines_0 and v_eff_clks = s_eq_pulses_b_clks_0) then
          s_eq_pulses <= '0';
        elsif (v_eff_lines = s_eq_pulses_a_lines_1 and v_eff_clks = s_eq_pulses_a_clks_1) or
              (v_eff_lines = s_eq_pulses_b_lines_1 and v_eff_clks = s_eq_pulses_b_clks_1) then
          s_eq_pulses <= '1';
        end if;

        if v_eff_clks = s_csync_serration_a_clks_0 or v_eff_clks = s_csync_serration_b_clks_0 or
           v_eff_clks = s_csync_serration_c_clks_0 or v_eff_clks = s_csync_serration_d_clks_0 then
          s_csync_serration <= '0';
        elsif v_eff_clks = s_csync_serration_a_clks_1 or v_eff_clks = s_csync_serration_b_clks_1 or
              v_eff_clks = s_csync_serration_c_clks_1 or v_eff_clks = s_csync_serration_d_clks_1 then
          s_csync_serration <= '1';
        end if;

        if (v_eff_lines = s_vsync_a_lines_0 and v_eff_clks = s_vsync_a_clks_0) or
           (v_eff_lines = s_vsync_b_lines_0 and v_eff_clks = s_vsync_b_clks_0) then
          s_vsync <= '0';
        elsif (v_eff_lines = s_vsync_a_lines_1 and v_eff_clks = s_vsync_a_clks_1) or
              (v_eff_lines = s_vsync_b_lines_1 and v_eff_clks = s_vsync_b_clks_1) then
          s_vsync <= '1';
        end if;
      end if;

      -- AVID (active video) gate.
      -- Horizontal: high when pixel counter is inside the active
      -- window [h_active_start+1 .. h_active_end].  Bounded on both
      -- ends so AVID width equals frame_width regardless of the
      -- per-format front porch.
      -- Vertical: high after V back porch (per-standard, accounts for
      -- interlaced fields). Uses v_eff_lines under phase advance.
      if v_eff_clks > s_h_active_start and v_eff_clks <= s_h_active_end then
        s_avid_h <= '1';
      else
        s_avid_h <= '0';
      end if;

      if v_eff_lines > s_v_active_start then
        s_avid_v <= '1';
      else
        s_avid_v <= '0';
      end if;

      s_avid <= s_avid_h and s_avid_v;

    end if;
  end process;

  -- Tri-level sync output mapping.
  --
  -- Analog summing convention (confirmed by staircase truth-table test):
  --   analog ~= trisync_n - trisync_p
  --   (n HIGH -> positive analog excursion;
  --    p HIGH -> negative analog excursion).
  --
  -- IMPORTANT: the Rev B analog summing network is not a pure
  -- differential amplifier. It contains DC-blocking / RC elements that
  -- attenuate narrow pulses heavily. Driving narrow active-HIGH pulses
  -- on both pins (e.g. p HIGH for 40 clks at end of line, n HIGH for
  -- 40 clks at start of next line, both LOW the rest of the time)
  -- produces a near-zero analog output in progressive HD modes, even
  -- though it is differentially equivalent to the SMPTE waveform.
  --
  -- The robust approach is to keep BOTH pins HIGH for the majority of
  -- each line and drop them LOW only inside the sync-tip windows. This
  -- gives the summer a stable common-mode level and ensures the brief
  -- LOW excursions translate cleanly into bipolar analog tips:
  --
  --   p = NOT s_hsync  -> LOW  for clks 1..40   (start-of-line window)
  --                       HIGH for clks 41..end (rest of line)
  --   n = s_csync      -> HIGH for clks 1..1610 (most of line)
  --                       LOW  for clks 1611..end (end-of-line window)
  --
  -- analog = n - p:
  --   clks 1..40        : HIGH - LOW  = +1  (positive tip, start of line)
  --   clks 41..1610     : HIGH - HIGH =  0  (mid-line bias)
  --   clks 1611..end    : LOW  - HIGH = -1  (negative tip, end of line)
  --
  -- That is the SMPTE bipolar tri-level shape (negative excursion at
  -- end of line followed by positive excursion at start of next),
  -- correctly straddling the line wrap.
  --
  -- During VSYNC and equalization regions the broader serration / 2x
  -- patterns dominate; those branches are unchanged.
  --
  -- SD modes (trisync_en = 0) gate trisync_p to '0' so the analog sync
  -- output reduces to plain active-low CSYNC on trisync_n.
  s_trisync_p <= ((not s_hsync_2x) and s_trisync_en) when s_eq_pulses = '1' else
    ((not s_hsync) and s_trisync_en);

  s_trisync_n <= s_csync_serration when s_vsync = '1' else
    s_csync_2x when s_eq_pulses = '1' else
    s_csync;

  trisync_p <= s_trisync_p;
  trisync_n <= s_trisync_n;

  hsync <= s_hsync;
  vsync <= s_vsync;
  avid  <= s_avid;

end architecture;
