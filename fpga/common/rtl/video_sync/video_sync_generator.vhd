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
--   This is a counter-based sync waveform generator, not a fixed-depth
--   pipeline. The timing input has a 2-cycle configuration pipeline
--   (timing -> s_timing -> config registers). Sync outputs are registered
--   comparisons against free-running counters, so output latency relative
--   to ref_hsync/ref_vsync depends on the video standard's counter periods.
--   HSYNC output period matches the configured clocks-per-line exactly.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_sync_pkg.all;

entity video_sync_generator is
  port (
    clk           : in std_logic;
    ref_hsync     : in std_logic;
    ref_vsync     : in std_logic;
    ref_field_n   : in std_logic;
    timing        : in std_logic_vector(3 downto 0);
    trisync_p     : out std_logic;
    trisync_n     : out std_logic;
    hsync         : out std_logic;
    vsync         : out std_logic;
    avid          : out std_logic
  );
end entity;

architecture rtl of video_sync_generator is
  signal s_ref_vsync_d              : std_logic := '0';
  signal s_ref_vsync_event          : std_logic := '0';
  signal s_ref_field_n_d            : std_logic := '0';
  signal s_ref_field_event          : std_logic := '0';
  signal s_ref_fsync                : std_logic := '0';
  signal s_trisync_en               : std_logic := '0';
  signal s_timing                   : t_video_timing_id;
  signal s_is_interlaced            : std_logic := '0';
  signal s_fsync_clks               : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_fsync_lines              : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_hsync_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_hsync_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_hsync_clks_b_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_hsync_clks_b_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_2x_a_clks_1        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_2x_a_clks_0        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_2x_b_clks_1        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_2x_b_clks_0        : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_a_clks_1       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_a_lines_1      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_a_clks_0       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_a_lines_0      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_b_clks_1       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_b_lines_1      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_b_clks_0       : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_eq_pulses_b_lines_0      : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_a_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_a_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_b_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_b_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_c_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_c_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_d_clks_1 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_csync_serration_d_clks_0 : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_a_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_a_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_a_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_a_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_b_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_b_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_b_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_vsync_b_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_clocks_per_line          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_lines_per_frame          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_frame_width              : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_frame_height             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_h_active_start           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_v_active_start           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_counter_clks             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  signal s_counter_lines            : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
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

begin

  event_detectors : process (clk)
  begin
    if rising_edge(clk) then
      s_ref_vsync_d <= ref_vsync;
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
      -- Right-align the active window inside each line: blanking (hsync
      -- pulse + back porch) at the start, no front porch. Approximation is
      -- adequate for free-run mode.
      s_h_active_start           <=
        C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).clocks_per_line
        - C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).frame_width;
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
  --   * Free-runs from clk alone, wrapping at s_clocks_per_line and
  --     s_lines_per_frame -- valid programmed video timing is produced
  --     even with no external sync inputs at all.
  --   * External HSYNC/VSYNC are *optional* resets: when present, the
  --     vsync (or field) edge snaps the per-frame counters to the
  --     per-standard fsync seed values, locking output phase to the
  --     external source. Absent external edges, the counters simply
  --     keep wrapping; output remains a valid free-run signal.
  counters : process (clk)
  begin
    if rising_edge(clk) then
      if s_ref_fsync = '1' then
        s_counter_clks  <= s_fsync_clks;
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
  begin
    if rising_edge(clk) then
      if s_counter_clks = s_hsync_clks_0 then
        s_hsync    <= '0';
        s_hsync_2x <= '0';
      elsif s_counter_clks = s_hsync_clks_1 then
        s_hsync    <= '1';
        s_hsync_2x <= '1';
      elsif s_counter_clks = s_hsync_clks_b_0 then
        s_hsync_2x <= '0';
      elsif s_counter_clks = s_hsync_clks_b_1 then
        s_hsync_2x <= '1';
      end if;

      if s_counter_clks = s_csync_clks_0 then
        s_csync <= '0';
      elsif s_counter_clks = s_csync_clks_1 then
        s_csync <= '1';
      end if;

      -- Direct csync_2x comparison
      if s_counter_clks = s_csync_2x_a_clks_0 or s_counter_clks = s_csync_2x_b_clks_0 then
        s_csync_2x <= '0';
      elsif s_counter_clks = s_csync_2x_a_clks_1 or s_counter_clks = s_csync_2x_b_clks_1 then
        s_csync_2x <= '1';
      end if;

      -- Direct eq_pulses comparison
      if (s_counter_lines = s_eq_pulses_a_lines_0 and s_counter_clks = s_eq_pulses_a_clks_0) or
         (s_counter_lines = s_eq_pulses_b_lines_0 and s_counter_clks = s_eq_pulses_b_clks_0) then
        s_eq_pulses <= '0';
      elsif (s_counter_lines = s_eq_pulses_a_lines_1 and s_counter_clks = s_eq_pulses_a_clks_1) or
            (s_counter_lines = s_eq_pulses_b_lines_1 and s_counter_clks = s_eq_pulses_b_clks_1) then
        s_eq_pulses <= '1';
      end if;

      -- Direct csync_serration comparison
      if s_counter_clks = s_csync_serration_a_clks_0 or s_counter_clks = s_csync_serration_b_clks_0 or
         s_counter_clks = s_csync_serration_c_clks_0 or s_counter_clks = s_csync_serration_d_clks_0 then
        s_csync_serration <= '0';
      elsif s_counter_clks = s_csync_serration_a_clks_1 or s_counter_clks = s_csync_serration_b_clks_1 or
            s_counter_clks = s_csync_serration_c_clks_1 or s_counter_clks = s_csync_serration_d_clks_1 then
        s_csync_serration <= '1';
      end if;

      -- Direct vsync comparison
      if (s_counter_lines = s_vsync_a_lines_0 and s_counter_clks = s_vsync_a_clks_0) or
         (s_counter_lines = s_vsync_b_lines_0 and s_counter_clks = s_vsync_b_clks_0) then
        s_vsync <= '0';
      elsif (s_counter_lines = s_vsync_a_lines_1 and s_counter_clks = s_vsync_a_clks_1) or
            (s_counter_lines = s_vsync_b_lines_1 and s_counter_clks = s_vsync_b_clks_1) then
        s_vsync <= '1';
      end if;

      -- AVID (active video) gate.
      -- Horizontal: high when pixel counter is past the H back porch
      -- (active window right-aligned in the line).
      -- Vertical: high after V back porch (per-standard, accounts for
      -- interlaced fields).
      if s_counter_clks > s_h_active_start then
        s_avid_h <= '1';
      else
        s_avid_h <= '0';
      end if;

      if s_counter_lines > s_v_active_start then
        s_avid_v <= '1';
      else
        s_avid_v <= '0';
      end if;

      s_avid <= s_avid_h and s_avid_v;

    end if;
  end process;

  s_trisync_p <= (not s_hsync_2x and s_trisync_en) when s_eq_pulses = '1' else
    (not s_hsync and s_trisync_en);

  s_trisync_n <= s_csync_serration when s_vsync = '1' else
    s_csync_2x when s_eq_pulses = '1' else
    s_csync;

  trisync_p <= s_trisync_p;
  trisync_n <= s_trisync_n;

  hsync <= s_hsync;
  vsync <= s_vsync;
  avid  <= s_avid;

end architecture;
