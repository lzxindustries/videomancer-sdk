-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2026 LZX Industries LLC
-- File: auto_resolution_detector.vhd - Live active-resolution measurement
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
--   Continuously measures the active video region by counting pixels per
--   active line and active lines per frame from a video_timing_generator
--   output port.  Replaces resolution_pkg lookups (which return hardcoded
--   720/1280/1920 values driven by a firmware-supplied timing ID and
--   ignore clock division).
--
--   The auto-measured outputs are correct for all supported video standards.
--   Values stabilise after the first full frame; default boot-time values
--   (1920x1080) are emitted until then.
--
--   Outputs are registered.  Centre signals are computed by a single
--   right-shift of the measured dimensions and are also registered, so
--   downstream logic sees consistent h/v_active and h/v_centre on the
--   same clock edge.
--
-- Latency:
--   Active outputs are registered (1 cycle from internal latch).
--   Centres are combinational right-shifts of the active outputs.
--   Up to one full frame for the first valid measurement.
--
-- Resource cost:
--   ~4 x G_WIDTH flip-flops (two counters + two registered actives),
--   no BRAM, no DSP.
--
-- Authors:
--   Lars Larsen
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.video_timing_pkg.all;

entity auto_resolution_detector is
    generic (
        G_WIDTH         : natural := 12;
        G_DEFAULT_H     : natural := 1920;
        G_DEFAULT_V     : natural := 1080
    );
    port (
        clk      : in  std_logic;
        timing   : in  t_video_timing_port;
        h_active : out unsigned(G_WIDTH - 1 downto 0);
        v_active : out unsigned(G_WIDTH - 1 downto 0);
        h_center : out unsigned(G_WIDTH - 1 downto 0);
        v_center : out unsigned(G_WIDTH - 1 downto 0)
    );
end entity auto_resolution_detector;

architecture rtl of auto_resolution_detector is

    signal s_h_pixel_counter : unsigned(G_WIDTH - 1 downto 0) := (others => '0');
    signal s_v_line_counter  : unsigned(G_WIDTH - 1 downto 0) := (others => '0');

    signal s_h_active : unsigned(G_WIDTH - 1 downto 0) :=
        to_unsigned(G_DEFAULT_H, G_WIDTH);
    signal s_v_active : unsigned(G_WIDTH - 1 downto 0) :=
        to_unsigned(G_DEFAULT_V, G_WIDTH);

begin

    h_active <= s_h_active;
    v_active <= s_v_active;
    -- Centres are combinational right-shifts of the registered actives,
    -- saving 2 x G_WIDTH flip-flops and one cycle of latency.
    h_center <= '0' & s_h_active(G_WIDTH - 1 downto 1);
    v_center <= '0' & s_v_active(G_WIDTH - 1 downto 1);

    p_measure : process(clk)
    begin
        if rising_edge(clk) then
            -- Horizontal: count active pixels per line, latch on hsync
            if timing.hsync_start = '1' then
                if s_h_pixel_counter > 0 then
                    s_h_active <= s_h_pixel_counter;
                end if;
                s_h_pixel_counter <= (others => '0');
            elsif timing.avid = '1' then
                s_h_pixel_counter <= s_h_pixel_counter + 1;
            end if;

            -- Vertical: count active lines per frame, latch on vsync
            if timing.vsync_start = '1' then
                if s_v_line_counter > 0 then
                    s_v_active <= s_v_line_counter;
                end if;
                s_v_line_counter <= (others => '0');
            elsif timing.avid_start = '1' then
                s_v_line_counter <= s_v_line_counter + 1;
            end if;
        end if;
    end process;

end architecture rtl;
