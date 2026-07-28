-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: gbr444_30b_to_gbr422_20b.vhd - GBR444 24/30 to GBR422 16/20 Converter
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
--   Converts a GBR444 stream to a GBR422 stream with variable bit depth.
--
-- Pipeline Architecture:
--   Stage 0: Input register (Y, U, V, sync signals)         [1 cycle]
--   Stage 1: Sync delay + phase mux (B/R to C channel)      [1 cycle]
--   Stage 2: Output alignment register (Y, C data)           [1 cycle]
--
-- Latency:
--   Sync outputs:  2 clock cycles from sync inputs  (input reg + sync delay)
--   G/C data out:  3 clock cycles from data inputs  (input reg + mux + output)
--   Note: Sync signals arrive 1 clock cycle before the corresponding
--   G/C data. This is by design to match downstream pipeline alignment.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_stream_pkg.all;
use work.video_timing_pkg.all;
use work.core_pkg.all;

entity gbr444_30b_to_gbr422_20b is
    port (
        clk : in std_logic;
        i_data : in t_video_stream_gbr444_30b;
        o_data : out t_video_stream_gbr422_20b
    );
end gbr444_30b_to_gbr422_20b;

architecture rtl of gbr444_30b_to_gbr422_20b is

    -- Constants
    constant C_BIT_DEPTH : integer := i_data.g'length;

    -- Input registers
    signal s_g_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_b_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_r_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_hsync_n_in : std_logic := '1';
    signal s_vsync_n_in : std_logic := '1';
    signal s_avid_in : std_logic := '0';
    signal s_field_n_in : std_logic := '1';

    -- Sync signal delay chain (1 cycle after input register)
    signal s_hsync_n_d1 : std_logic := '1';
    signal s_vsync_n_d1 : std_logic := '1';
    signal s_avid_d1 : std_logic := '0';
    signal s_field_n_d1 : std_logic := '1';

    -- Phase control
    signal s_phase_reset : std_logic := '0';
    signal s_phase : std_logic := '0'; -- 0 = B, 1 = R

    -- GBR422 output registers
    signal s_gbr422_y : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_c : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_y_out : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_gbr422_c_out : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

begin

    -- Phase reset detection (falling edge of AVID delay chain)
    s_phase_reset <= '1' when (s_avid_in = '0' and s_avid_d1 = '1') else
        '0';

    -- Main processing pipeline
    process (clk)
    begin
        if rising_edge(clk) then
            -- Input registers
            s_g_in <= i_data.g;
            s_b_in <= i_data.b;
            s_r_in <= i_data.r;
            s_hsync_n_in <= i_data.hsync_n;
            s_vsync_n_in <= i_data.vsync_n;
            s_avid_in <= i_data.avid;
            s_field_n_in <= i_data.field_n;

            -- Sync signal delay chain (1 cycle after input register)
            s_hsync_n_d1 <= s_hsync_n_in;
            s_vsync_n_d1 <= s_vsync_n_in;
            s_avid_d1 <= s_avid_in;
            s_field_n_d1 <= s_field_n_in;

            -- Phase control logic
            if s_phase_reset = '1' then
                s_phase <= '0'; -- Start with B phase
            elsif s_avid_in = '1' then
                s_phase <= not s_phase; -- Toggle phase each valid pixel
            end if;

            -- GBR444 to GBR422 conversion
            -- G always passes through, B/R alternate on C
            s_gbr422_y <= s_g_in;
            case s_phase is
                when '0' => -- U phase
                    s_gbr422_c <= s_b_in;
                when '1' => -- V phase
                    s_gbr422_c <= s_r_in;
                when others =>
                    null;
            end case;

            -- Second delay stage to align with sync delay (2 cycles total)
            s_gbr422_y_out <= s_gbr422_y;
            s_gbr422_c_out <= s_gbr422_c;

        end if;
    end process;

    -- Output assignments with 2-cycle delay
    o_data.g <= s_gbr422_y_out;
    o_data.c <= s_gbr422_c_out;

    -- Sync outputs with 2-cycle delay
    o_data.hsync_n <= s_hsync_n_d1;
    o_data.vsync_n <= s_vsync_n_d1;
    o_data.avid <= s_avid_d1;
    o_data.field_n <= s_field_n_d1;

end architecture rtl;