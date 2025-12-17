-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: yuv444_top.vhd - YUV444 Core Program Interface
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
--   Interface declaration for all YUV Core programs.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.video_timing_pkg.all;
use work.video_stream_pkg.all;
use work.core_pkg.all;

entity yuv422_20b_top is
    port (
        clk             : in std_logic;
        registers_in    : in t_spi_ram;
        data_in         : in t_video_stream_yuv422_20b;
        data_out        : out t_video_stream_yuv422_20b
    );
end entity yuv422_20b_top;