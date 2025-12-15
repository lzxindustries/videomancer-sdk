-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: core_pkg.vhd - Core Package Definitions
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

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;

package core_pkg is

  constant C_PARAMETER_DATA_WIDTH      : integer := 10; -- Width of parameter data
  constant C_VIDEO_DATA_WIDTH          : integer := 10; -- Width of video data
  -- spi ram config
  constant C_SPI_TRANSFER_DATA_BITS    : integer := C_PARAMETER_DATA_WIDTH; 
  constant C_SPI_TRANSFER_SIZE_BYTES   : integer := 2;
  constant C_VIDEO_TIMING_DEPTH        : integer := C_VIDEO_TIMING_DATA_WIDTH;
  
  -- spi ram derived constants
  constant C_SPI_TRANSFER_TOTAL_BITS    : integer := C_SPI_TRANSFER_SIZE_BYTES * 8;
  constant C_SPI_TRANSFER_COMMAND_BITS  : integer := 1;
  constant C_SPI_TRANSFER_ADDR_WIDTH    : integer := C_SPI_TRANSFER_TOTAL_BITS - C_SPI_TRANSFER_COMMAND_BITS - C_SPI_TRANSFER_DATA_BITS;
  constant C_SPI_RAM_ARRAY_SIZE         : integer := 2 ** C_SPI_TRANSFER_ADDR_WIDTH;

  -- spi ram signals
  type t_spi_ram is array(0 to C_SPI_RAM_ARRAY_SIZE - 1) of std_logic_vector(C_SPI_TRANSFER_DATA_BITS - 1 downto 0);

end package core_pkg;