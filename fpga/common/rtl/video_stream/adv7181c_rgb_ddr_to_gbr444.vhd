-- Videomancer SDK
-- File: adv7181c_rgb_ddr_to_gbr444.vhd - ADV7181C 12-bit DDR RGB → GBR444
-- License: GNU General Public License v3.0
--
-- Soft IDDR unpack of ADV7181C datasheet Table 10 (12-bit 4:4:4 RGB DDR on P[19:8]):
--   Rising LLC:  P[19:12]=B[7:0], P[11:8]=G[3:0]
--   Falling LLC: P[19:16]=R[3:0], P[15:12]=G[7:4], P[11:8]=R[7:4]
-- One RGB888 pixel per LLC period; outputs in G/B/R 10-bit lanes (MSBs + "00").
--
-- Pipeline (1 LLC latency):
--   Rising T: capture rise half into s_rise_q; latch sync into s_sync_d
--   Falling T: capture fall half into s_fall_q
--   Rising T+1: assemble RGB from s_rise_q + s_fall_q; emit s_sync_d
--   (sync and data therefore belong to the same LLC period)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_stream_pkg.all;

entity adv7181c_rgb_ddr_to_gbr444 is
    port (
        llc        : in  std_logic;  -- ADV7181C LLC (pixel clock for DDR RGB)
        i_p19_8    : in  std_logic_vector(11 downto 0);  -- i_vid_dec_d(19 downto 8)
        i_hsync_n  : in  std_logic;
        i_vsync_n  : in  std_logic;
        i_avid     : in  std_logic;  -- must be DE (field_out_select=1), not FIELD
        i_field_n  : in  std_logic;
        o_data     : out t_video_stream_gbr444_30b
    );
end adv7181c_rgb_ddr_to_gbr444;

architecture rtl of adv7181c_rgb_ddr_to_gbr444 is
    signal s_rise_q   : std_logic_vector(11 downto 0) := (others => '0');
    signal s_fall_q   : std_logic_vector(11 downto 0) := (others => '0');
    signal s_sync_hs  : std_logic := '1';
    signal s_sync_vs  : std_logic := '1';
    signal s_sync_av  : std_logic := '0';
    signal s_sync_fld : std_logic := '1';
    signal s_r8       : std_logic_vector(7 downto 0) := (others => '0');
    signal s_g8       : std_logic_vector(7 downto 0) := (others => '0');
    signal s_b8       : std_logic_vector(7 downto 0) := (others => '0');
    signal s_hsync_n  : std_logic := '1';
    signal s_vsync_n  : std_logic := '1';
    signal s_avid     : std_logic := '0';
    signal s_field_n  : std_logic := '1';
begin

    -- Falling-edge capture (R nibbles + G[7:4]) for the LLC period that
    -- started on the previous rising edge.
    p_fall : process(llc)
    begin
        if falling_edge(llc) then
            s_fall_q <= i_p19_8;
        end if;
    end process;

    -- Rising-edge: assemble previous LLC's rise+fall; capture this LLC's rise
    -- and sync for assembly on the next rising edge.
    p_rise : process(llc)
    begin
        if rising_edge(llc) then
            -- Assemble pixel that completed on the prior falling edge
            s_b8 <= s_rise_q(11 downto 4);                              -- B[7:0]
            s_g8 <= s_fall_q(7 downto 4) & s_rise_q(3 downto 0);        -- G[7:0]
            s_r8 <= s_fall_q(3 downto 0) & s_fall_q(11 downto 8);       -- R[7:0]

            s_hsync_n  <= s_sync_hs;
            s_vsync_n  <= s_sync_vs;
            s_avid     <= s_sync_av;
            s_field_n  <= s_sync_fld;

            -- Capture this LLC period's rising half + sync
            s_rise_q   <= i_p19_8;
            s_sync_hs  <= i_hsync_n;
            s_sync_vs  <= i_vsync_n;
            s_sync_av  <= i_avid;
            s_sync_fld <= i_field_n;
        end if;
    end process;

    o_data.g <= s_g8 & "00";
    o_data.b <= s_b8 & "00";
    o_data.r <= s_r8 & "00";
    o_data.hsync_n <= s_hsync_n;
    o_data.vsync_n <= s_vsync_n;
    o_data.avid    <= s_avid;
    o_data.field_n <= s_field_n;

end architecture rtl;
