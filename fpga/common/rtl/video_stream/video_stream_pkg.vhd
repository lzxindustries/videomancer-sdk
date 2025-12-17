-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_stream_pkg.vhd - Video Stream and Colorspace Package
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
--   Types and constants for video stream interfaces and colorspace formats.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package video_stream_pkg is

  -- YUV 4:4:4 30-bit video stream type
  type t_video_stream_yuv444_30b is record
    y       : std_logic_vector(9 downto 0);
    u       : std_logic_vector(9 downto 0);
    v       : std_logic_vector(9 downto 0);
    avid    : std_logic;
    hsync_n : std_logic;
    vsync_n : std_logic;
    field_n : std_logic;
  end record;

  -- YUV 4:2:2 20-bit video stream type
  type t_video_stream_yuv422_20b is record
    y       : std_logic_vector(9 downto 0);
    c       : std_logic_vector(9 downto 0);
    avid    : std_logic;
    hsync_n : std_logic;
    vsync_n : std_logic;
    field_n : std_logic;
  end record;

end package video_stream_pkg;
