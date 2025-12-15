-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: sync_slv.vhd - Clock Domain Synchronizer
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
--   2 flip-flip synchronizers for crossing clock domains.

--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_slv is
  port(
    clk : in  std_logic;
    a   : in  std_logic_vector;
    b   : out std_logic_vector
  );
end entity sync_slv;

architecture rtl of sync_slv is
  signal a_ff  : std_logic_vector(a'range);
  signal a_ff2 : std_logic_vector(a'range);

begin
  process(clk)
  begin
    if rising_edge(clk) then
      a_ff  <= a;
      a_ff2 <= a_ff;
    end if;
  end process;

  b <= a_ff2;

end architecture rtl;
