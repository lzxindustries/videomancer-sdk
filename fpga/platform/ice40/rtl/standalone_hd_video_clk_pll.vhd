-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: standalone_hd_video_clk_pll.vhd - 27 MHz -> 74.25 MHz PLL Wrapper
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
--   PLL wrapper for the hd_standalone bitstream variant. Synthesizes a
--   74.25 MHz pixel clock from a 27 MHz reference supplied by the MCU
--   on RP2040_GPOUT_CLK (pin 128, repurposed as an FPGA input). The
--   output also drives a `locked` signal used to gate downstream resets
--   until the PLL has locked.
--
--   Configuration (verified with `icepll -i 27 -o 74.25`):
--     F_PLLIN  = 27.000 MHz
--     F_PLLOUT = 74.250 MHz (exact)
--     F_VCO    = 594.000 MHz
--     DIVR = 0, DIVF = 21, DIVQ = 3, FILTER_RANGE = 2
--
-- Authors:
--   Lars Larsen

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity standalone_hd_video_clk_pll is
  port(
    i_clk    : in  std_logic;  -- 27 MHz reference from MCU
    o_clk    : out std_logic;  -- 74.25 MHz pixel clock
    o_locked : out std_logic;  -- High when PLL has locked
    i_resetb : in  std_logic   -- Active low reset
  );
end entity standalone_hd_video_clk_pll;

architecture rtl of standalone_hd_video_clk_pll is

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
      LOCK : out std_logic;
      RESETB : in std_logic;
      BYPASS : in std_logic
    );
  end component SB_PLL40_CORE;

begin

  pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000",        -- Reference divider = 0+1 = 1 (input / 1)
      DIVF => "0010101",     -- Feedback divider = 21+1 = 22 (VCO = 27 MHz * 22 = 594 MHz)
      DIVQ => "011",         -- Output divider = 2^3 = 8 (output = 594 / 8 = 74.25 MHz)
      FILTER_RANGE => "010"  -- PLL filter range for 27 MHz input
    )
    port map(
      REFERENCECLK => i_clk,
      PLLOUTCORE   => open,
      PLLOUTGLOBAL => o_clk,
      LOCK         => o_locked,
      RESETB       => i_resetb,
      BYPASS       => '0'
    );

end architecture rtl;
