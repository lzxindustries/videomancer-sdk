-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: hd_standalone_pkg.vhd - HD Standalone Core Configuration
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
--   Core configuration package for HD standalone video mode.
--   Standalone mode disconnects the HDMI receiver and analog decoder
--   video datapaths and uses the ADV7181C LLC clock (i_vid_dec_clk)
--   directly as the pixel clock. Firmware configures the decoder's
--   CP-PLL in clock-generator-only mode so the LLC frequency exactly
--   matches the selected HD video timing (74.25 MHz, or 74.25/1.001
--   MHz for dropframe rates). All eleven HD timing rates are
--   supported: 720p50, 720p59.94, 720p60, 1080i50, 1080i59.94,
--   1080i60, 1080p23.98, 1080p24, 1080p25, 1080p29.97, 1080p30.
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
  constant C_ENABLE_SD         : boolean := false;
  constant C_ENABLE_HD         : boolean := true;
end package core_config_pkg;
