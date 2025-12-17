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

library work;
use work.video_stream_pkg.all;

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

  -- type t_video_timing_port is record
  --   avid          : std_logic;
  --   hsync_n       : std_logic;
  --   vsync_n       : std_logic;
  --   field_n       : std_logic;
  --   vavid         : std_logic;
  --   hsync_start   : std_logic;
  --   vsync_start   : std_logic;
  --   avid_start    : std_logic;
  --   avid_end      : std_logic;
  --   is_interlaced : std_logic;
  -- end record;

  -- subtype t_video_timing_range is std_logic_vector(1 downto 0);

  -- constant C_ANIMATION  : t_video_timing_range := "00";
  -- constant C_VERTICAL   : t_video_timing_range := "01";
  -- constant C_HORIZONTAL : t_video_timing_range := "10";

end package;
