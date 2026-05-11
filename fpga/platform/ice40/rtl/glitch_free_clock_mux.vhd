-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: glitch_free_clock_mux.vhd - 2:1 Glitch-Free Clock Multiplexer
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
--   Standard 2:1 glitch-free clock multiplexer.
--
--   Each input clock has its own 2-FF synchronizer chain that samples
--   the desynchronized request from the opposite clock. The clock gate
--   for clock_a is enabled only when (1) clock_b's gate has fully
--   relinquished (synchronized into the clock_a domain) and (2) the
--   user has selected clock_a. The output is the OR of two AND-gated
--   clocks, neither of which can ever be high simultaneously, which
--   guarantees no short pulses or glitches on the output clock.
--
--   Switching latency: ~3 cycles of the outgoing clock + ~3 cycles of
--   the incoming clock. Both clocks must be free-running and stable
--   (not tri-stated). The select input may be asynchronous.
--
--   This implementation is a textbook recipe and uses only fabric
--   logic (no SB_GB or SB_PLL40_CORE primitives). For best results,
--   the output should be routed onto a global clock buffer (SB_GB)
--   by the caller.
--
-- Authors:
--   Lars Larsen

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity glitch_free_clock_mux is
  port(
    i_clk_a    : in  std_logic;  -- Clock input A
    i_clk_b    : in  std_logic;  -- Clock input B
    i_sel      : in  std_logic;  -- '0' selects A, '1' selects B
    o_clk      : out std_logic   -- Selected clock output
  );
end entity glitch_free_clock_mux;

architecture rtl of glitch_free_clock_mux is

  -- Per-clock enable chain: a request stage (combinational AND of
  -- (selected) AND (other-clock-released)) and two synchronizer FFs.
  signal s_a_enable_meta : std_logic := '1';
  signal s_a_enable      : std_logic := '1';
  signal s_b_enable_meta : std_logic := '0';
  signal s_b_enable      : std_logic := '0';

  signal s_sel_a : std_logic;  -- '1' when caller selects A
  signal s_sel_b : std_logic;  -- '1' when caller selects B

  signal s_a_gate : std_logic;
  signal s_b_gate : std_logic;

begin

  s_sel_a <= not i_sel;
  s_sel_b <=     i_sel;

  -- Clock A enable chain: clocked by clock A. Latch enable on the
  -- FALLING edge so that the AND gate (clock A AND enable) only
  -- changes value when clock A is low; this prevents short pulses.
  p_a_chain : process(i_clk_a)
  begin
    if falling_edge(i_clk_a) then
      s_a_enable_meta <= s_sel_a and (not s_b_enable);
      s_a_enable      <= s_a_enable_meta;
    end if;
  end process;

  -- Clock B enable chain: clocked by clock B, falling edge.
  p_b_chain : process(i_clk_b)
  begin
    if falling_edge(i_clk_b) then
      s_b_enable_meta <= s_sel_b and (not s_a_enable);
      s_b_enable      <= s_b_enable_meta;
    end if;
  end process;

  s_a_gate <= s_a_enable and i_clk_a;
  s_b_gate <= s_b_enable and i_clk_b;
  o_clk    <= s_a_gate or s_b_gate;

end architecture rtl;
