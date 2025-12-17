-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: sd_video_clk_pll_2x.vhd - 2x Clock Multiplier PLL Wrapper
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

entity sd_video_clk_pll_2x is
  port(
    i_clk       : in  std_logic;  -- Input clock (e.g., 13.5 MHz)
    o_clk       : out std_logic;  -- Output clock (2x input, e.g., 27 MHz)
    i_resetb    : in  std_logic;  -- Active low reset
    i_bypass    : in  std_logic   -- Bypass mode
  );
end entity sd_video_clk_pll_2x;

architecture rtl of sd_video_clk_pll_2x is

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

  -- PLL Configuration for 2x clock multiplication
  -- Input: 13.5 MHz
  -- VCO: 13.5 MHz * 32 = 432 MHz
  -- Output: 432 MHz / 16 = 27 MHz (2x input)
  pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000",        -- Reference divider = 0+1 = 1 (input / 1)
      DIVF => "0011111",     -- Feedback divider = 31+1 = 32 (VCO = input * 32)
      DIVQ => "100",         -- Output divider = 2^4 = 16 (output = VCO / 16)
      FILTER_RANGE => "001"  -- PLL filter range for 13.5 MHz input
    )
    port map(
      REFERENCECLK => i_clk,
      PLLOUTCORE   => open,
      PLLOUTGLOBAL => o_clk,
      RESETB       => i_resetb,
      BYPASS       => i_bypass
    );

end architecture rtl;
