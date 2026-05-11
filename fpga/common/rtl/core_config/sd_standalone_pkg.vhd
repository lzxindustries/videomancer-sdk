-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: sd_standalone_pkg.vhd - SD Standalone Core Configuration
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
--   Core configuration package for SD standalone video mode.
--   Standalone mode disconnects the HDMI receiver and analog decoder
--   inputs entirely and generates all pixel clocks internally from a
--   27 MHz reference clock supplied by the MCU on RP2040_GPOUT_CLK
--   (pin 128, repurposed as an input in standalone bitstreams). The
--   bitstream supports two pixel clock rates selected at runtime by
--   the SPI timing register: 13.5 MHz (NTSC, PAL) and 27 MHz
--   (480p, 576p), with glitch-free runtime switching.
--
-- Authors:
--   Lars Larsen

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package core_config_pkg is
  constant C_ENABLE_ANALOG     : boolean := false;
  constant C_ENABLE_HDMI       : boolean := false;
  constant C_ENABLE_DUAL       : boolean := false;
  constant C_ENABLE_STANDALONE : boolean := true;
  constant C_ENABLE_SD         : boolean := true;
  constant C_ENABLE_HD         : boolean := false;
  constant C_HD_CLOCK_DIVISOR  : integer := 1;
end package core_config_pkg;
