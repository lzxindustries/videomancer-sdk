-- Videomancer SDK
-- File: gbr444_30b_blanking.vhd - GBR444 Blanking
-- License: GNU General Public License v3.0
-- Black = G=B=R=0 during avid='0'. 2-cycle latency.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_stream_pkg.all;

entity gbr444_30b_blanking is
    port (
        clk        : in  std_logic;
        data_in    : in  t_video_stream_gbr444_30b;
        data_out   : out t_video_stream_gbr444_30b
    );
end gbr444_30b_blanking;

architecture rtl of gbr444_30b_blanking is
    signal s_data_reg : t_video_stream_gbr444_30b;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            s_data_reg <= data_in;
            if s_data_reg.avid = '1' then
                data_out.g <= s_data_reg.g;
                data_out.b <= s_data_reg.b;
                data_out.r <= s_data_reg.r;
            else
                data_out.g <= (others => '0');
                data_out.b <= (others => '0');
                data_out.r <= (others => '0');
            end if;
            data_out.avid    <= s_data_reg.avid;
            data_out.hsync_n <= s_data_reg.hsync_n;
            data_out.vsync_n <= s_data_reg.vsync_n;
            data_out.field_n <= s_data_reg.field_n;
        end if;
    end process;
end rtl;
