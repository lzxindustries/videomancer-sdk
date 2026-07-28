-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: gbr422_20b_to_gbr444_30b.vhd - GBR422 16/20 to GBR444 24/30 Converter
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
--   Converts a GBR422 stream to a GBR444 stream with variable bit depth.
--
-- Pipeline Architecture:
--   Sync signals (hsync_n, vsync_n, avid, field_n): 2-cycle delay chain
--   G data path: 3-cycle delay (input reg -> delay reg -> output reg)
--   B/R chroma: Phase-dependent pairing with 2-3 cycle latency
--
-- Latency:
--   Sync outputs:  2 clock cycles from sync inputs
--   G data output:  3 clock cycles from G data input
--   Note: Sync signals arrive 1 clock cycle before the corresponding
--   G data. This is by design to match downstream pipeline alignment.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_stream_pkg.all;
use work.video_timing_pkg.all;
use work.core_pkg.all;

entity gbr422_20b_to_gbr444_30b is
    port (
        clk        : in  std_logic;
        i_data     : in  t_video_stream_gbr422_20b;
        o_data     : out t_video_stream_gbr444_30b
    );
end gbr422_20b_to_gbr444_30b;

architecture rtl of gbr422_20b_to_gbr444_30b is

    -- Constants
    constant C_BIT_DEPTH : integer := i_data.g'length;

    -- Sync signal delay chain (2 cycles total)
    signal s_hsync_n_d1    : std_logic := '1';
    signal s_hsync_n_d2    : std_logic := '1';
    signal s_vsync_n_d1    : std_logic := '1';
    signal s_vsync_n_d2    : std_logic := '1';
    signal s_avid_d1       : std_logic := '0';
    signal s_avid_d2       : std_logic := '0';
    signal s_field_n_d1    : std_logic := '1';
    signal s_field_n_d2    : std_logic := '1';

    -- Phase control
    signal s_phase_reset   : std_logic := '0';
    signal s_phase : std_logic := '0';  -- 0 = B, 1 = R

    -- Data path signals
    signal s_gbr422_y      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_c      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_y_d1   : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_c_d1   : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

    -- GBR444 output registers
    signal s_gbr444_y      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr444_u      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr444_v      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

begin

    -- Phase reset detection (falling edge of AVID delay chain)
    s_phase_reset <= '1' when (s_avid_d1 = '0' and s_avid_d2 = '1') else '0';

    -- Main processing pipeline
    process(clk)
    begin
        if rising_edge(clk) then
            -- Sync signal delay chain (2 cycles total)
            s_hsync_n_d1 <= i_data.hsync_n;
            s_hsync_n_d2 <= s_hsync_n_d1;
            s_vsync_n_d1 <= i_data.vsync_n;
            s_vsync_n_d2 <= s_vsync_n_d1;
            s_avid_d1    <= i_data.avid;
            s_avid_d2    <= s_avid_d1;
            s_field_n_d1 <= i_data.field_n;
            s_field_n_d2 <= s_field_n_d1;

            -- Data path
            s_gbr422_y <= i_data.g;
            s_gbr422_c <= i_data.c;

            -- Data delay registers
            s_gbr422_y_d1 <= s_gbr422_y;
            s_gbr422_c_d1 <= s_gbr422_c;

            -- Phase control logic
            if s_phase_reset = '1' then
                s_phase <= '0';  -- Start with B phase
            elsif i_data.avid = '1' then
                s_phase <= not s_phase;  -- Toggle phase each valid pixel
            end if;

            -- GBR422 to GBR444 conversion
            -- G always passes through with 1 cycle delay
            s_gbr444_y <= s_gbr422_y_d1;

            if s_phase = '0' then
                -- B phase - store chroma for next cycle
                s_gbr422_c_d1 <= s_gbr422_c;
            else
                -- R phase - output both U and V
                s_gbr444_u <= s_gbr422_c_d1;   -- Previous sample to U
                s_gbr444_v <= s_gbr422_c;      -- Current sample to V
            end if;

        end if;
    end process;

    -- Output assignments
    o_data.g <= s_gbr444_y;
    o_data.b <= s_gbr444_u;
    o_data.r <= s_gbr444_v;

    -- Sync outputs with 2-cycle delay
    o_data.hsync_n <= s_hsync_n_d2;
    o_data.vsync_n <= s_vsync_n_d2;
    o_data.avid    <= s_avid_d2;
    o_data.field_n <= s_field_n_d2;

end architecture rtl;
