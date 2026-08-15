-- Videomancer SDK
-- File: tb_dual_sync_delay.vhd - VUnit testbench for dual_sync_delay
-- License: GNU General Public License v3.0
--
-- Verifies the HDMI-RX → ADV7181C EXT sync delay line used in dual routing:
-- after i_delay_clks rising edges, o_hsync/o_vsync match the delayed inputs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;

entity tb_dual_sync_delay is
  generic (
    runner_cfg   : string;
    G_DELAY_CLKS : natural := 4
  );
end entity;

architecture tb of tb_dual_sync_delay is
  constant C_CLK_PERIOD : time := 13.468 ns; -- ~74.25 MHz LLC

  signal clk          : std_logic := '0';
  signal i_delay_clks : unsigned(6 downto 0);
  signal i_hsync      : std_logic := '0';
  signal i_vsync      : std_logic := '0';
  signal o_hsync      : std_logic;
  signal o_vsync      : std_logic;
  signal stop         : boolean := false;
begin
  i_delay_clks <= to_unsigned(G_DELAY_CLKS, 7);

  clk <= not clk after C_CLK_PERIOD / 2 when not stop else '0';

  dut : entity rtl_lib.dual_sync_delay
    port map (
      clk          => clk,
      i_delay_clks => i_delay_clks,
      i_hsync      => i_hsync,
      i_vsync      => i_vsync,
      o_hsync      => o_hsync,
      o_vsync      => o_vsync
    );

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("passthrough_low") then
        i_hsync <= '0';
        i_vsync <= '0';
        wait for (G_DELAY_CLKS + 3) * C_CLK_PERIOD;
        check_equal(o_hsync, '0', "hsync stayed low");
        check_equal(o_vsync, '0', "vsync stayed low");

      elsif run("delay_hsync_pulse") then
        i_hsync <= '0';
        i_vsync <= '0';
        wait for (G_DELAY_CLKS + 3) * C_CLK_PERIOD;

        -- Still low just before the delay window completes.
        i_hsync <= '1';
        wait for (G_DELAY_CLKS - 1) * C_CLK_PERIOD + C_CLK_PERIOD / 4;
        check_equal(o_hsync, '0', "hsync still low before delay elapses");

        -- High once the full delay has passed.
        wait for C_CLK_PERIOD;
        check_equal(o_hsync, '1', "hsync high after G_DELAY_CLKS");

        i_hsync <= '0';
        wait for (G_DELAY_CLKS - 1) * C_CLK_PERIOD + C_CLK_PERIOD / 4;
        check_equal(o_hsync, '1', "hsync still high before fall delay elapses");
        wait for C_CLK_PERIOD;
        check_equal(o_hsync, '0', "hsync low after fall delay");

      elsif run("delay_vsync_independent") then
        i_hsync <= '0';
        i_vsync <= '0';
        wait for (G_DELAY_CLKS + 3) * C_CLK_PERIOD;
        i_vsync <= '1';
        wait for G_DELAY_CLKS * C_CLK_PERIOD + C_CLK_PERIOD / 4;
        check_equal(o_vsync, '1', "vsync delayed independently of hsync");
        check_equal(o_hsync, '0', "hsync unaffected by vsync");
      end if;
    end loop;

    stop <= true;
    test_runner_cleanup(runner);
  end process;
end architecture;
