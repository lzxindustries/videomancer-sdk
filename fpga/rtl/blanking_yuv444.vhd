-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: blanking_yuv444.vhd - YUV444 Blanking
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

library work;
use work.video_timing_pkg.all;

entity blanking_yuv444 is
    port (
        clk        : in  std_logic;
        data_in    : in  t_video_stream_yuv444;
        data_out   : out t_video_stream_yuv444
    );
end blanking_yuv444;

architecture rtl of blanking_yuv444 is
    signal s_data_reg : t_video_stream_yuv444;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Input register (cycle 1)
            s_data_reg <= data_in;
            
            -- Processing with 2-cycle total delay
            if s_data_reg.avid = '1' then
                data_out.y <= s_data_reg.y;
                data_out.u <= s_data_reg.u;
                data_out.v <= s_data_reg.v;
            else
                data_out.y <= std_logic_vector(to_unsigned(0,   10));
                data_out.u <= std_logic_vector(to_unsigned(512, 10));
                data_out.v <= std_logic_vector(to_unsigned(512, 10));
            end if;

            data_out.avid <= s_data_reg.avid;
            data_out.hsync_n <= s_data_reg.hsync_n;
            data_out.vsync_n <= s_data_reg.vsync_n;
            data_out.field_n <= s_data_reg.field_n;
        end if;
    end process;

end architecture rtl;
