-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_line_buffer.vhd - Dual-Bank Video Line Buffer
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
--   Dual-bank BRAM line buffer for video processing. While one bank is being
--   written (current line), the other bank is read (previous line). The i_ab
--   signal selects which bank is written vs read, typically toggled per line.
--
-- Pipeline Architecture (2 stages, 2 clock cycles read latency):
--   Stage 0: Register all inputs (i_ab, i_wr_addr, i_rd_addr, i_data)
--   Stage 1: BRAM read into output register; BRAM write from registered data
--
-- Latency:
--   o_data: 2 clock cycles from i_rd_addr change
--   Write-to-read: Data written on cycle N is available for read on cycle N+2
--   (1 cycle input register + 1 cycle BRAM read register).
--   The output MUX selects bank based on the registered i_ab signal.
--
-- Authors:
--   Lars Larsen
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_line_buffer is
    generic (
        G_WIDTH : integer := 10; -- Bits width of the data input
        G_DEPTH : integer := 11  -- Bits depth of the delay line
    );
    port (
        clk         : in  std_logic;
        i_ab        : in  std_logic;
        i_wr_addr   : in  unsigned(G_DEPTH - 1 downto 0);
        i_rd_addr   : in  unsigned(G_DEPTH - 1 downto 0);
        i_data      : in  std_logic_vector(G_WIDTH - 1 downto 0);
        o_data      : out std_logic_vector(G_WIDTH - 1 downto 0)
    );
end entity video_line_buffer;

architecture rtl of video_line_buffer is
    type t_ram is array(0 to ((2**G_DEPTH) - 1)) of std_logic_vector(G_WIDTH - 1 downto 0);
    -- Zero-initialized to match iCE40 EBR power-up state: without this,
    -- simulation reads 'U' before the first written line, and 'U'
    -- poisons downstream arithmetic (numeric_std 'U' * 0 = 'U') — e.g.
    -- mycelium's whole output, including the dry mix leg, decoded as
    -- black in the vmtest suite until first-line data was defined.
    signal s_ram_a : t_ram := (others => (others => '0'));
    signal s_ram_b : t_ram := (others => (others => '0'));
    signal s_output_a : std_logic_vector(G_WIDTH - 1 downto 0);
    signal s_output_b : std_logic_vector(G_WIDTH - 1 downto 0);
    signal s_i_wr_addr : unsigned(G_DEPTH - 1 downto 0);
    signal s_i_rd_addr : unsigned(G_DEPTH - 1 downto 0);
    signal s_input   : std_logic_vector(G_WIDTH - 1 downto 0);
    signal s_ab      : std_logic;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            s_ab <= i_ab;
            s_i_rd_addr <= i_rd_addr;
            s_i_wr_addr <= i_wr_addr;
            s_input <= i_data;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if s_ab = '0' then
                s_ram_a(to_integer(s_i_wr_addr)) <= s_input;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            s_output_a <= s_ram_a(to_integer(s_i_rd_addr));
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if s_ab = '1' then
                s_ram_b(to_integer(s_i_wr_addr)) <= s_input;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            s_output_b <= s_ram_b(to_integer(s_i_rd_addr));
        end if;
    end process;

    o_data <= s_output_a when s_ab = '1' else s_output_b;

end architecture rtl;
