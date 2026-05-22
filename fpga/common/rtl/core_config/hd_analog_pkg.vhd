-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: hd_analog_pkg.vhd - HD Analog Core Configuration
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
--   Core configuration package for HD analog video mode.
--   Enables analog output at HD resolution with no clock division.
--
-- Authors:
--   Lars Larsen

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package core_config_pkg is
  constant C_ENABLE_ANALOG     : boolean := true;
  constant C_ENABLE_HDMI       : boolean := false;
  constant C_ENABLE_DUAL       : boolean := false;
  constant C_ENABLE_STANDALONE : boolean := false;
  constant C_ENABLE_SD         : boolean := false;
  constant C_ENABLE_HD         : boolean := true;
end package core_config_pkg;