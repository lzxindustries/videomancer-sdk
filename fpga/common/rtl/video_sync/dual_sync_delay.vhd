-- Videomancer SDK
-- File: dual_sync_delay.vhd - Delay HDMI RX sync into ADV7181C EXT HS/VS
-- License: GNU General Public License v3.0
--
-- Split read/write synchronous RAM for iCE40 BRAM inference. Registered read
-- adds 1 LLC; dual_ext_sync_delay_total subtracts one from non-zero totals.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dual_sync_delay is
    port (
        clk          : in  std_logic;
        i_delay_clks : in  unsigned(6 downto 0);
        i_hsync      : in  std_logic;
        i_vsync      : in  std_logic;
        o_hsync      : out std_logic;
        o_vsync      : out std_logic
    );
end entity dual_sync_delay;

architecture rtl of dual_sync_delay is
    constant C_ADDR_BITS : natural := 7;
    constant C_DEPTH     : natural := 2 ** C_ADDR_BITS;

    type t_ram is array (0 to C_DEPTH - 1) of std_logic_vector(1 downto 0);
    signal s_ram : t_ram := (others => (others => '0'));

    attribute syn_ramstyle : string;
    attribute syn_ramstyle of s_ram : signal is "block_ram";

    signal s_wr      : unsigned(C_ADDR_BITS - 1 downto 0) := (others => '0');
    signal s_rd_addr : unsigned(C_ADDR_BITS - 1 downto 0);
    signal s_rd_q    : std_logic_vector(1 downto 0) := (others => '0');
    signal s_wdata   : std_logic_vector(1 downto 0);
begin
    s_wdata <= i_hsync & i_vsync;

    ram_write : process (clk)
    begin
        if rising_edge(clk) then
            s_wr <= s_wr + 1;
            s_ram(to_integer(s_wr)) <= s_wdata;
        end if;
    end process;

    ram_read : process (clk)
    begin
        if rising_edge(clk) then
            if i_delay_clks = 0 then
                s_rd_q <= s_wdata;
            else
                s_rd_addr <= s_wr - resize(i_delay_clks, C_ADDR_BITS);
                s_rd_q <= s_ram(to_integer(s_rd_addr));
            end if;
        end if;
    end process;

    o_hsync <= s_rd_q(1);
    o_vsync <= s_rd_q(0);
end architecture rtl;
