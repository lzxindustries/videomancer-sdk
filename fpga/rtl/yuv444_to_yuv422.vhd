-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: yuv444_to_yuv422.vhd - YUV444 24/30 to YUV422 16/20 Converter
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
--   Converts a YUV444 stream to a YUV422 stream with variable bit depth
--   and discrete syncs passed with 1-cycle delay.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.core_pkg.all;

entity yuv444_to_yuv422 is
    port (
        clk : in std_logic;
        i_data : in t_video_stream_yuv444;
        o_data : out t_video_stream_yuv422
    );
end yuv444_to_yuv422;

architecture rtl of yuv444_to_yuv422 is

    -- Constants
    constant C_BIT_DEPTH : integer := i_data.y'length;

    -- Input registers
    signal s_y_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_u_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_v_in : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
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
    signal s_phase : std_logic := '0'; -- 0 = U/Cb, 1 = V/Cr

    -- YUV422 output registers
    signal s_yuv422_y : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv422_c : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

begin

    -- Phase reset detection (rising edge of AVID)
    s_phase_reset <= '1' when (s_avid_in = '0' and s_avid_d1 = '1') else
        '0';

    -- Main processing pipeline
    process (clk)
    begin
        if rising_edge(clk) then
            -- Input registers
            s_y_in <= i_data.y;
            s_u_in <= i_data.u;
            s_v_in <= i_data.v;
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
                s_phase <= '0'; -- Start with U/Cb phase
            elsif s_avid_in = '1' then
                s_phase <= not s_phase; -- Toggle phase each valid pixel
            end if;

            -- YUV444 to YUV422 conversion
            -- Y always passes through, U/V alternate on C
            s_yuv422_y <= s_y_in;
            case s_phase is
                when '0' => -- U phase
                    s_yuv422_c <= s_u_in;
                when '1' => -- V phase
                    s_yuv422_c <= s_v_in;
                when others =>
                    null;
            end case;

        end if;
    end process;

    -- Output assignments
    o_data.y <= s_yuv422_y;
    o_data.c <= s_yuv422_c;

    -- Sync outputs with 1-cycle delay
    o_data.hsync_n <= s_hsync_n_d1;
    o_data.vsync_n <= s_vsync_n_d1;
    o_data.avid <= s_avid_d1;
    o_data.field_n <= s_field_n_d1;

end architecture rtl;