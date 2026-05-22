-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: hd_video_clk_pll_div4.vhd - HD Clock Divider PLL (74.25 MHz -> 18.5625 MHz)
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
--   PLL wrapper that divides the 74.25 MHz HD pixel clock by 4, producing
--   an 18.5625 MHz program clock for HD clock decimation mode.
--   Note: This PLL is no longer instantiated by core_top.
--
--   PLL parameters (verified with icepll):
--     F_PLLIN:  74.250 MHz
--     F_PLLOUT: 18.5625 MHz (exact)
--     F_VCO:    594.000 MHz
--     DIVR=0, DIVF=7, DIVQ=5, FILTER_RANGE=5

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity hd_video_clk_pll_div4 is
  port(
    i_clk       : in  std_logic;  -- Input clock (74.25 MHz)
    o_clk       : out std_logic;  -- Output clock (18.5625 MHz)
    i_resetb    : in  std_logic;  -- Active low reset
    i_bypass    : in  std_logic   -- Bypass mode
  );
end entity hd_video_clk_pll_div4;

architecture rtl of hd_video_clk_pll_div4 is

  component SB_PLL40_CORE is
    generic (
      FEEDBACK_PATH : string := "SIMPLE";
      DIVR : std_logic_vector(3 downto 0) := "0000";
      DIVF : std_logic_vector(6 downto 0) := "0000000";
      DIVQ : std_logic_vector(2 downto 0) := "000";
      FILTER_RANGE : std_logic_vector(2 downto 0) := "000"
    );
    port (
      REFERENCECLK : in std_logic;
      PLLOUTCORE : out std_logic;
      PLLOUTGLOBAL : out std_logic;
      RESETB : in std_logic;
      BYPASS : in std_logic
    );
  end component SB_PLL40_CORE;

begin

  -- PLL Configuration for divide-by-4
  -- Input:  74.25 MHz
  -- VCO:    74.25 MHz * 8 = 594 MHz
  -- Output: 594 MHz / 32 = 18.5625 MHz (input / 4)
  pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000",        -- Reference divider = 0+1 = 1 (input / 1)
      DIVF => "0000111",     -- Feedback divider = 7+1 = 8 (VCO = input * 8)
      DIVQ => "101",         -- Output divider = 2^5 = 32 (output = VCO / 32)
      FILTER_RANGE => "101"  -- PLL filter range for 74.25 MHz input
    )
    port map(
      REFERENCECLK => i_clk,
      PLLOUTCORE   => open,
      PLLOUTGLOBAL => o_clk,
      RESETB       => i_resetb,
      BYPASS       => i_bypass
    );

end architecture rtl;
