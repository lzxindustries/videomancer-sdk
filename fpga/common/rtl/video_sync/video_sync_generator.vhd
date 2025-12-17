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
    vsync         : out std_logic
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
  -- signal s_havid_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_havid_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_a_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_a_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_a_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_a_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_b_clks_1           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_b_lines_1          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_b_clks_0           : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_vavid_b_lines_0          : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_field_clks_1             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_field_lines_1            : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_field_clks_0             : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
  -- signal s_field_lines_0            : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0);
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
  signal s_havid                    : std_logic := '0';
  signal s_vavid                    : std_logic := '0';
  signal s_avid                     : std_logic := '0';
  signal s_field                    : std_logic := '0';

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
      s_fsync_clks               <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).fsync_clks;
      s_fsync_lines              <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).fsync_lines;
      s_hsync_clks_0             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_0;
      s_hsync_clks_1             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_1;
      s_hsync_clks_0             <= C_VIDEO_SYNC_CONFIG_ARRAY(to_integer(unsigned(s_timing))).hsync_clks_0;
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

      -- -- Horizontal active video generation
      -- if s_counter_clks = s_havid_clks_0 then
      --   s_havid <= '0';
      -- elsif s_counter_clks = s_havid_clks_1 then
      --   s_havid <= '1';
      -- end if;

      -- -- Vertical active video generation
      -- if (s_counter_lines = s_vavid_a_lines_0 and s_counter_clks = s_vavid_a_clks_0) or
      --    (s_counter_lines = s_vavid_b_lines_0 and s_counter_clks = s_vavid_b_clks_0) then
      --   s_vavid <= '0';
      -- elsif (s_counter_lines = s_vavid_a_lines_1 and s_counter_clks = s_vavid_a_clks_1) or
      --       (s_counter_lines = s_vavid_b_lines_1 and s_counter_clks = s_vavid_b_clks_1) then
      --   s_vavid <= '1';
      -- end if;

      -- -- Field generation
      -- if (s_counter_lines = s_field_lines_0 and s_counter_clks = s_field_clks_0) then
      --   s_field <= '0';
      -- elsif (s_counter_lines = s_field_lines_1 and s_counter_clks = s_field_clks_1) then
      --   s_field <= '1';
      -- end if;

    end if;
  end process;

  s_trisync_p <= (not s_hsync_2x and s_trisync_en) when s_eq_pulses = '1' else
    (not s_hsync and s_trisync_en);

  s_trisync_n <= s_csync_serration when s_vsync = '1' else
    s_csync_2x when s_eq_pulses = '1' else
    s_csync;

  -- s_avid <= s_vavid and s_havid;

  trisync_p <= s_trisync_p;
  trisync_n <= s_trisync_n;

  hsync <= s_hsync;
  vsync <= s_vsync;

end architecture;
