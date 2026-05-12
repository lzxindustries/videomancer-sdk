-- Videomancer SDK - VUnit Testbench for standalone_hd_video_clk_pll
-- Copyright (C) 2025 LZX Industries LLC
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Tests:
--   1.  reset_holds_lock_low -- with i_resetb='0', o_locked stays low
--   2.  lock_after_reset -- after releasing reset, o_locked rises within
--                          a documented window
--   3.  output_frequency -- after lock, o_clk runs at 74.25 MHz
--                          (74250 kHz +/- 0.1 %)
--   4.  reset_drops_lock -- pulling reset low after lock drops o_locked
--                          and stops the output clock
--
-- Uses a behavioural SB_PLL40_CORE simulation stub
-- (sb_pll40_core_sim.vhd) so this testbench runs in pure GHDL.  The stub
-- honours DIVR/DIVF/DIVQ exactly per the SIMPLE-feedback formula, so it
-- exercises the same generic settings the real DUT instantiates.

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;

entity tb_standalone_hd_video_clk_pll is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_standalone_hd_video_clk_pll is

  constant C_REFCLK_PERIOD     : time := 37037 ps;       -- 27 MHz
  constant C_EXPECTED_OUT_FREQ : real := 74_250_000.0;   -- 74.25 MHz
  constant C_LOCK_TIMEOUT      : time := 10 us;

  signal clk_in  : std_logic := '0';
  signal clk_out : std_logic;
  signal locked  : std_logic;
  signal resetb  : std_logic := '0';
  signal stop    : std_logic := '0';

begin

  clk_in <= not clk_in after C_REFCLK_PERIOD / 2 when stop = '0' else unaffected;

  dut : entity rtl_lib.standalone_hd_video_clk_pll
    port map (
      i_clk    => clk_in,
      o_clk    => clk_out,
      o_locked => locked,
      i_resetb => resetb
    );

  main : process

    -- Measure the period of clk_out by averaging across N rising edges.
    procedure measure_period(constant n_edges  : positive;
                             period_out : out time) is
      variable v_t0 : time;
      variable v_t1 : time;
    begin
      wait until rising_edge(clk_out);
      v_t0 := now;
      for i in 1 to n_edges loop
        wait until rising_edge(clk_out);
      end loop;
      v_t1 := now;
      period_out := (v_t1 - v_t0) / n_edges;
    end procedure;

    variable v_period         : time;
    variable v_expected_per   : time;
    variable v_diff           : time;
    variable v_tol            : time;
    variable v_lock_start     : time;
    variable v_no_edge_window : time;
    variable v_saw_edge       : boolean;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      -- Reset between tests
      resetb <= '0';
      wait for 200 ns;

      if run("reset_holds_lock_low") then
        wait for 2 us;
        check_equal(locked, '0', "locked must stay low while resetb='0'");

      elsif run("lock_after_reset") then
        v_lock_start := now;
        resetb <= '1';
        wait until locked = '1' for C_LOCK_TIMEOUT;
        check_equal(locked, '1',
          "locked failed to rise within " & time'image(C_LOCK_TIMEOUT));

      elsif run("output_frequency") then
        resetb <= '1';
        wait until locked = '1' for C_LOCK_TIMEOUT;
        check_equal(locked, '1', "PLL did not lock");
        -- Wait one extra microsecond so the stub's free-running clock
        -- has stabilised.
        wait for 1 us;
        measure_period(20, v_period);
        v_expected_per := 1 sec / integer(C_EXPECTED_OUT_FREQ);
        v_tol := v_expected_per / 1000;  -- 0.1 % tolerance
        if v_period > v_expected_per then
          v_diff := v_period - v_expected_per;
        else
          v_diff := v_expected_per - v_period;
        end if;
        check(v_diff <= v_tol,
              "o_clk period " & time'image(v_period) &
              " deviates from expected " & time'image(v_expected_per) &
              " by more than 0.1 %");

      elsif run("reset_drops_lock") then
        resetb <= '1';
        wait until locked = '1' for C_LOCK_TIMEOUT;
        check_equal(locked, '1', "PLL did not lock");
        wait for 500 ns;
        resetb <= '0';
        wait for 200 ns;
        check_equal(locked, '0', "locked did not drop after reset");
        -- And the output clock should have stopped toggling.
        v_saw_edge := false;
        v_no_edge_window := 1 us;
        wait on clk_out for v_no_edge_window;
        if clk_out'event then
          v_saw_edge := true;
        end if;
        check(not v_saw_edge,
          "clk_out continued toggling after reset asserted");

      end if;
    end loop;

    stop <= '1';
    test_runner_cleanup(runner);
    wait;
  end process;

end architecture tb;
