-- Videomancer SDK
-- File: passthru_gbr422.vhd - GBR422 passthrough
-- License: GNU General Public License v3.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_stream_pkg.all;
use work.core_pkg.all;
use work.all;

architecture passthru_gbr422 of program_top is
begin
    p_passthrough : process(clk)
    begin
        if rising_edge(clk) then
            data_out <= data_in;
        end if;
    end process p_passthrough;
end architecture passthru_gbr422;
