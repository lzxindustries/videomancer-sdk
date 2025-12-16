-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: yuv422_to_yuv444.vhd - YUV422 16/20 to YUV444 24/30 Converter
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
--   Converts a YUV422 stream to a YUV444 stream with variable bit depth and
--   discrete syncs passed with 2-cycle delay.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.core_pkg.all;

entity yuv422_to_yuv444 is
    port (
        clk        : in  std_logic;
        i_data     : in  t_video_stream_yuv422;
        o_data     : out t_video_stream_yuv444
    );
end yuv422_to_yuv444;

architecture rtl of yuv422_to_yuv444 is

    -- Constants
    constant C_BIT_DEPTH : integer := i_data.y'length;

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
    signal s_phase : std_logic := '0';  -- 0 = U/Cb, 1 = V/Cr

    -- Data path signals
    signal s_yuv422_y      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv422_c      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv422_y_d1   : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv422_c_d1   : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

    -- YUV444 output registers
    signal s_yuv444_y      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv444_u      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');
    signal s_yuv444_v      : std_logic_vector(C_BIT_DEPTH - 1 downto 0) := (others => '0');

begin

    -- Phase reset detection (rising edge of AVID)
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
            s_yuv422_y <= i_data.y;
            s_yuv422_c <= i_data.c;

            -- Data delay registers
            s_yuv422_y_d1 <= s_yuv422_y;
            s_yuv422_c_d1 <= s_yuv422_c;

            -- Phase control logic
            if s_phase_reset = '1' then
                s_phase <= '0';  -- Start with U/Cb phase
            elsif i_data.avid = '1' then
                s_phase <= not s_phase;  -- Toggle phase each valid pixel
            end if;

            -- YUV422 to YUV444 conversion
            -- Y always passes through with 1 cycle delay
            s_yuv444_y <= s_yuv422_y_d1;

            if s_phase = '0' then
                -- U/Cb phase - store chroma for next cycle
                s_yuv422_c_d1 <= s_yuv422_c;
            else
                -- V/Cr phase - output both U and V
                s_yuv444_u <= s_yuv422_c_d1;   -- Previous sample to U
                s_yuv444_v <= s_yuv422_c;      -- Current sample to V
            end if;

        end if;
    end process;

    -- Output assignments
    o_data.y <= s_yuv444_y;
    o_data.u <= s_yuv444_u;
    o_data.v <= s_yuv444_v;

    -- Sync outputs with 2-cycle delay
    o_data.hsync_n <= s_hsync_n_d2;
    o_data.vsync_n <= s_vsync_n_d2;
    o_data.avid    <= s_avid_d2;
    o_data.field_n <= s_field_n_d2;

end architecture rtl;
