-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_timing_pkg.vhd - Video Timing Package
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
--   Constant data and types for video timing configurations.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package video_timing_pkg is

  constant C_VIDEO_TIMING_ID_WIDTH          : integer := 4;
  constant C_VIDEO_TIMING_ID_COUNT          : integer := (2 ** C_VIDEO_TIMING_ID_WIDTH);

  subtype t_video_timing_id is std_logic_vector(C_VIDEO_TIMING_ID_WIDTH - 1 downto 0);

  constant C_NTSC      : t_video_timing_id := "0000"; -- 0
  constant C_PAL       : t_video_timing_id := "1000"; -- 8
  constant C_480P      : t_video_timing_id := "0100"; -- 4
  constant C_576P      : t_video_timing_id := "1100"; -- 12
  constant C_720P60    : t_video_timing_id := "1110"; -- 14
  constant C_720P5994  : t_video_timing_id := "0110"; -- 6
  constant C_720P50    : t_video_timing_id := "0101"; -- 5
  constant C_1080I60   : t_video_timing_id := "1010"; -- 10
  constant C_1080I5994 : t_video_timing_id := "0010"; -- 2
  constant C_1080I50   : t_video_timing_id := "0001"; -- 1
  constant C_1080P30   : t_video_timing_id := "0111"; -- 7
  constant C_1080P2997 : t_video_timing_id := "1101"; -- 13
  constant C_1080P25   : t_video_timing_id := "1011"; -- 11
  constant C_1080P24   : t_video_timing_id := "0011"; -- 3
  constant C_1080P2398 : t_video_timing_id := "1001"; -- 9

  type t_video_timing_port is record
    avid          : std_logic;
    hsync_n       : std_logic;
    vsync_n       : std_logic;
    field_n       : std_logic;
    vavid         : std_logic;
    hsync_start   : std_logic;
    vsync_start   : std_logic;
    avid_start    : std_logic;
    avid_end      : std_logic;
    is_interlaced : std_logic;
  end record;

  subtype t_video_timing_range is std_logic_vector(1 downto 0);

  constant C_ANIMATION  : t_video_timing_range := "00";
  constant C_VERTICAL   : t_video_timing_range := "01";
  constant C_HORIZONTAL : t_video_timing_range := "10";

  -- Dual EXT sync delay (HDMI RX → ADV7181C HS/VS): ~50 LLC for NTSC-class
  -- pipelines; +6 for PAL 576i (864 vs 858 CPL on the same LLC clock).
  -- HD progressive dual HIL measured ~33px geometry residual at 50 clks
  -- (2026-08-02 desk); trim delay until RTL phase is characterized.
  constant C_DUAL_EXT_SYNC_DELAY_DEFAULT : unsigned(6 downto 0) := to_unsigned(50, 7);
  constant C_DUAL_EXT_SYNC_DELAY_PAL     : unsigned(6 downto 0) := to_unsigned(56, 7);
  constant C_DUAL_EXT_SYNC_DELAY_HD      : unsigned(6 downto 0) := to_unsigned(17, 7);

  function dual_ext_sync_delay_clks(timing : t_video_timing_id) return unsigned;

  -- Menu H Phase In (reg 0x0B): 7-bit value centered at 64 = 0 px offset.
  function dual_ext_sync_delay_total(
    timing   : t_video_timing_id;
    h_phase  : std_logic_vector(9 downto 0)
  ) return unsigned;

  -- Sync Out phase = pipeline (reg 0x09) + centered H Phase Out (reg 0x0A).
  function sync_out_phase_advance_clks(
    pipeline_clks : std_logic_vector(9 downto 0);
    h_phase_out   : std_logic_vector(9 downto 0)
  ) return unsigned;

end package;

package body video_timing_pkg is

  function dual_ext_sync_delay_clks(timing : t_video_timing_id) return unsigned is
  begin
    if timing = C_PAL then
      return C_DUAL_EXT_SYNC_DELAY_PAL;
    elsif timing = C_720P60 or timing = C_720P5994 or timing = C_720P50
       or timing = C_1080P30 or timing = C_1080P2997 or timing = C_1080P25
       or timing = C_1080P24 or timing = C_1080P2398 then
      return C_DUAL_EXT_SYNC_DELAY_HD;
    else
      return C_DUAL_EXT_SYNC_DELAY_DEFAULT;
    end if;
  end function;

  function dual_ext_sync_delay_total(
    timing   : t_video_timing_id;
    h_phase  : std_logic_vector(9 downto 0)
  ) return unsigned is
    constant C_MAX : integer := 127;
    variable v_base : integer := to_integer(dual_ext_sync_delay_clks(timing));
    variable v_off  : integer := to_integer(unsigned(h_phase(6 downto 0))) - 64;
    variable v_tot  : integer;
  begin
    v_tot := v_base + v_off;
    if v_tot > 0 then
      v_tot := v_tot - 1; -- dual_sync_delay registered BRAM read
    end if;
    if v_tot < 0 then
      return to_unsigned(0, 7);
    elsif v_tot > C_MAX then
      return to_unsigned(C_MAX, 7);
    else
      return to_unsigned(v_tot, 7);
    end if;
  end function;

  function sync_out_phase_advance_clks(
    pipeline_clks : std_logic_vector(9 downto 0);
    h_phase_out   : std_logic_vector(9 downto 0)
  ) return unsigned is
    variable v_pipe : signed(11 downto 0) := signed(resize(unsigned(pipeline_clks), 12));
    variable v_hp   : signed(11 downto 0) := to_signed(to_integer(unsigned(h_phase_out(6 downto 0))) - 64, 12);
    variable v_sum  : signed(11 downto 0) := v_pipe + v_hp;
  begin
    if v_sum < 0 then
      return to_unsigned(0, 10);
    elsif v_sum > 1023 then
      return to_unsigned(1023, 10);
    else
      return unsigned(v_sum(9 downto 0));
    end if;
  end function;

end package body video_timing_pkg;
