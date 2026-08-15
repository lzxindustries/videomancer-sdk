-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_timing_generator_fielded.vhd - Video timing edge generator
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.video_timing_pkg.all;

entity video_timing_generator_fielded is
    port (
        clk           : in  std_logic;
        avid          : in  std_logic;
        hsync_n       : in  std_logic;
        vsync_n       : in  std_logic;
        field_n       : in  std_logic;
        timing        : out t_video_timing_port
    );
end entity video_timing_generator_fielded;

architecture rtl of video_timing_generator_fielded is
    signal s_avid_b       : std_logic;
    signal s_avid_rising  : std_logic;
    signal s_avid_falling : std_logic;
    signal s_hsync_b      : std_logic;
    signal s_hsync_rising : std_logic;
    signal s_vsync_b      : std_logic;
    signal s_vsync_rising : std_logic;
    signal s_field_b      : std_logic;
    signal s_is_interlaced : std_logic := '0';
begin

    avid_edge_inst : entity work.edge_detector
        port map(clk => clk, a => avid, b => s_avid_b,
                 rising => s_avid_rising, falling => s_avid_falling);

    hsync_edge_inst : entity work.edge_detector
        port map(clk => clk, a => hsync_n, b => s_hsync_b,
                 rising => open, falling => s_hsync_rising);

    vsync_edge_inst : entity work.edge_detector
        port map(clk => clk, a => vsync_n, b => s_vsync_b,
                 rising => open, falling => s_vsync_rising);

    field_edge_inst : entity work.edge_detector
        port map(clk => clk, a => field_n, b => s_field_b,
                 rising => open, falling => open);

    process(clk)
    begin
        if rising_edge(clk) then
            if s_vsync_rising = '1' then
                if s_field_b = '0' then
                    s_is_interlaced <= '1';
                end if;
            end if;
        end if;
    end process;

    timing.avid          <= s_avid_b;
    timing.hsync_n       <= s_hsync_b;
    timing.vsync_n       <= s_vsync_b;
    timing.field_n       <= s_field_b;
    timing.vavid         <= s_avid_b;
    timing.hsync_start   <= s_hsync_rising;
    timing.vsync_start   <= s_vsync_rising;
    timing.avid_start    <= s_avid_rising;
    timing.avid_end      <= s_avid_falling;
    timing.is_interlaced <= s_is_interlaced;

end architecture rtl;
