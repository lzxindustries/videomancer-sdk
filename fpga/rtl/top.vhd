-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: top.vhd - Top Level Hardware Interface for Videomancer
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

entity top is
  port(
    -- host communication
    SPI_SCK               : in    std_logic;
    SPI_SDO               : inout std_logic;
    SPI_SDI               : in    std_logic;
    SPI_CS_N              : in    std_logic;
    MCU_GPOUT_CLK         : out   std_logic;

    -- sd/hd sync output
    VID_SYNC_OUT_P        : out   std_logic;
    VID_SYNC_OUT_N        : out   std_logic;

    -- analog video input
    VID_DEC_CLK           : in    std_logic;
    VID_DEC_D             : in    std_logic_vector(19 downto 0);
    VID_DEC_HSYNC         : in    std_logic;
    VID_DEC_VSYNC         : in    std_logic;
    VID_DEC_FIELD_DE      : in    std_logic;
    VID_DEC_HSYNC_IN      : out   std_logic;
    VID_DEC_VSYNC_IN      : out   std_logic;

    -- hdmi video input
    HDMI_RX_CLK           : in    std_logic;
    HDMI_RX_D             : in    std_logic_vector(23 downto 0);
    HDMI_RX_HSYNC         : in    std_logic;
    HDMI_RX_VSYNC         : in    std_logic;
    HDMI_RX_DE            : in    std_logic;

    -- analog/hdmi video output
    HDMI_TX_CLK   : out   std_logic;
    HDMI_TX_D     : out   std_logic_vector(23 downto 0);
    HDMI_TX_HSYNC : out   std_logic;
    HDMI_TX_VSYNC : out   std_logic;
    VID_ENC_CLK   : out   std_logic;
    VID_ENC_D     : out   std_logic_vector(15 downto 0);
    VID_ENC_HSYNC : out   std_logic;
    VID_ENC_VSYNC : out   std_logic

  );
end entity top;
