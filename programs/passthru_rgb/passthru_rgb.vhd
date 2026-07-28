-- Videomancer SDK
-- File: passthru_rgb.vhd - GBR444 passthrough (RGB processing core)
-- License: GNU General Public License v3.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_stream_pkg.all;
use work.core_pkg.all;
use work.all;

architecture passthru_rgb of program_top is
    -- Even delay required (odd delay inverts Cb/Cr vs Sync Out / encoder).
    constant C_PROCESSING_DELAY_CLKS : integer := 0;
begin
    data_out <= data_in;
end architecture passthru_rgb;
