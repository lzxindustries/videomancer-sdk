-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: video_field_detector.vhd - Video Field Detector
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

entity video_field_detector is
    generic (
        G_LINE_COUNTER_WIDTH : positive := 12
    );
    port (
        clk : in std_logic;
        hsync : in std_logic;
        vsync : in std_logic;
        field_n : out std_logic;
        is_interlaced : out std_logic
    );
end entity;

architecture rtl of video_field_detector is
    signal hsync_prev : std_logic := '1';
    signal vsync_prev : std_logic := '1';
    signal pixel_counter : unsigned(G_LINE_COUNTER_WIDTH -1 downto 0) := (others => '0');
    signal vsync_pixel_pos : unsigned(G_LINE_COUNTER_WIDTH -1 downto 0) := (others => '0');
    signal last_vsync_pixel_pos : unsigned(G_LINE_COUNTER_WIDTH -1 downto 0) := (others => '0');
    signal field_parity : std_logic := '0';
    signal interlaced : std_logic := '0';
begin

    process (clk)
    begin
        if rising_edge(clk) then
            hsync_prev <= hsync;
            vsync_prev <= vsync;
            
            pixel_counter <= pixel_counter + 1;

            -- HSYNC rising edge: reset pixel counter
            if hsync_prev = '0' and hsync = '1' then
                pixel_counter <= (others => '0');
            end if;

            -- VSYNC rising edge: capture position and determine field
            if vsync_prev = '0' and vsync = '1' then
                vsync_pixel_pos <= pixel_counter;
                
                -- Compare current VSYNC position with previous
                -- If positions differ significantly (half-line difference),
                -- fields alternate. Otherwise same field type.
                if vsync_pixel_pos < last_vsync_pixel_pos then
                    field_parity <= '1';  -- Odd field (earlier in line)
                    interlaced <= '1';    -- Different positions = interlaced
                else
                    field_parity <= '0';  -- Even field (later in line)
                    if vsync_pixel_pos = last_vsync_pixel_pos then
                        interlaced <= '0';  -- Same position = progressive
                    else
                        interlaced <= '1';  -- Different positions = interlaced
                    end if;
                end if;
                
                last_vsync_pixel_pos <= vsync_pixel_pos;
            end if;
        end if;
    end process;

    field_n <= not field_parity;
    is_interlaced <= interlaced;

end architecture;