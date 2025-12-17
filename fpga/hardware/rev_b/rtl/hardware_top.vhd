-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: hardware_top.vhd - Top Level Hardware Interface for Videomancer
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

entity hardware_top is
  port(
    -- host communication
    RP2040_SPI0_SCK               : in    std_logic;
    RP2040_SPI0_SDO               : inout std_logic;
    RP2040_SPI0_SDI               : in    std_logic;
    RP2040_SPI0_CS_N              : in    std_logic;
    RP2040_GPOUT_CLK         : out   std_logic;

    -- sd/hd sync output
    VID_SYNC_OUT_P        : out   std_logic;
    VID_SYNC_OUT_N        : out   std_logic;

    -- analog video input
    ADV7181C_CLK           : in    std_logic;
    ADV7181C_D             : in    std_logic_vector(19 downto 0);
    ADV7181C_HSYNC         : in    std_logic;
    ADV7181C_VSYNC         : in    std_logic;
    ADV7181C_FIELD_DE      : in    std_logic;
    ADV7181C_HSYNC_IN      : out   std_logic;
    ADV7181C_VSYNC_IN      : out   std_logic;

    -- hdmi video input
    ADV7611_CLK           : in    std_logic;
    ADV7611_D             : in    std_logic_vector(23 downto 0);
    ADV7611_HSYNC         : in    std_logic;
    ADV7611_VSYNC         : in    std_logic;
    ADV7611_DE            : in    std_logic;

    -- analog/hdmi video output
    ADV7513_CLK   : out   std_logic;
    ADV7513_D     : out   std_logic_vector(23 downto 0);
    ADV7513_HSYNC : out   std_logic;
    ADV7513_VSYNC : out   std_logic;
    ADV7393_CLK   : out   std_logic;
    ADV7393_D     : out   std_logic_vector(15 downto 0);
    ADV7393_HSYNC : out   std_logic;
    ADV7393_VSYNC : out   std_logic

  );
end entity hardware_top;


architecture rtl of hardware_top is
begin

  -- Videomancer Core Instantiation
  u_core_top : entity work.core_top
    port map(
      -- host communication
      i_spi_sck               => RP2040_SPI0_SCK,
      i_spi_sdo               => RP2040_SPI0_SDO,
      i_spi_sdi               => RP2040_SPI0_SDI,
      i_spi_cs_n              => RP2040_SPI0_CS_N,
      o_mcu_gpout_clk         => RP2040_GPOUT_CLK,

      -- sd/hd sync output
      o_vid_sync_out_p        => VID_SYNC_OUT_P,
      o_vid_sync_out_n        => VID_SYNC_OUT_N,

      -- analog video input
      i_vid_dec_clk           => ADV7181C_CLK,
      i_vid_dec_d             => ADV7181C_D,
      i_vid_dec_hsync         => ADV7181C_HSYNC,
      i_vid_dec_vsync         => ADV7181C_VSYNC,
      i_vid_dec_field_de      => ADV7181C_FIELD_DE,
      o_vid_dec_hsync_in      => ADV7181C_HSYNC_IN,
      o_vid_dec_vsync_in      => ADV7181C_VSYNC_IN,

      -- hdmi video input
      i_hdmi_rx_clk           => ADV7611_CLK,
      i_hdmi_rx_d             => ADV7611_D,
      i_hdmi_rx_hsync         => ADV7611_HSYNC,
      i_hdmi_rx_vsync         => ADV7611_VSYNC,
      i_hdmi_rx_de            => ADV7611_DE,

      -- analog/hdmi video output
      o_hdmi_tx_clk   => ADV7513_CLK,
      o_hdmi_tx_d     => ADV7513_D,
      o_hdmi_tx_hsync => ADV7513_HSYNC,
      o_hdmi_tx_vsync => ADV7513_VSYNC,
      o_vid_enc_clk   => ADV7393_CLK,
      o_vid_enc_d     => ADV7393_D,
      o_vid_enc_hsync => ADV7393_HSYNC,
      o_vid_enc_vsync => ADV7393_VSYNC
    );

end architecture rtl;