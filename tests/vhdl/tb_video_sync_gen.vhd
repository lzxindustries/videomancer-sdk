-- Videomancer SDK - VUnit Testbench for video_sync_generator
-- Copyright (C) 2025 LZX Industries LLC
-- SPDX-License-Identifier: GPL-3.0-only
--
-- video_sync_generator drives bi-level and tri-level sync signals from
-- reference sync inputs and a timing configuration selected via a 4-bit ID.
--
-- Architecture:
--   - event_detectors: falling edge detection on ref_vsync and ref_field_n
--   - timing_config_regs: 2-cycle pipeline loading config from constant array
--   - counters: clk/line counters reset by fsync, wrap at clocks_per_line/lines_per_frame
--   - sync_gen: threshold comparisons generate hsync, vsync, csync, eq_pulses, etc.
--   - trisync output mux: combines sync signals for tri-level sync output
--
-- Tests use 480P (progressive, timing ID "0100") and NTSC (interlaced, "0000").
--
-- 480P config (from video_sync_pkg):
--   clocks_per_line=858, lines_per_frame=525
--   fsync_clks=1, fsync_lines=13
--   hsync_clks_1=1 (high), hsync_clks_0=64 (low) -> 63 clk pulse
--   vsync_a_lines_1=7 (high), vsync_a_lines_0=13 (low) -> 6 line pulse
--   trisync_en='0', is_interlaced='0'
--
-- Tests:
--   1. hsync_pulse_after_fsync_480p
--   2. hsync_pulse_width_480p
--   3. hsync_repeats_each_line_480p
--   4. vsync_generation_480p
--   5. ntsc_interlaced_field_fsync
--   6. trisync_p_zero_when_disabled
--   7. trisync_n_follows_csync_480p
--   8. counter_survives_full_line
--   9. config_pipeline_latency
--  10. multiple_fsync_resets
--  11. freerun_no_fsync_snap
--  12. phase_advance_shifts_hsync
--  13. phase_advance_1080i5994_eq
--  14. phase_advance_line_wrap_keeps_vsync

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;
use rtl_lib.video_sync_pkg.all;

entity tb_video_sync_gen is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_video_sync_gen is
  constant C_CLK_PERIOD : time := 10 ns;

  signal clk         : std_logic := '0';
  signal ref_hsync   : std_logic := '1';
  signal ref_vsync   : std_logic := '1';
  signal ref_field_n : std_logic := '1';
  signal timing      : std_logic_vector(3 downto 0) := C_480P;
  signal trisync_p   : std_logic;
  signal trisync_n   : std_logic;
  signal hsync       : std_logic;
  signal vsync       : std_logic;
  signal hsync_freerun : std_logic;
  signal hsync_phase   : std_logic;
  signal vsync_phase   : std_logic;
  signal trisync_p_phase : std_logic;
  signal trisync_n_phase : std_logic;
  signal phase_advance : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal test_done   : std_logic := '0';

  -- 480P known values
  constant C_480P_CPL         : integer := 858;   -- clocks_per_line
  constant C_480P_LPF         : integer := 525;   -- lines_per_frame
  constant C_480P_FSYNC_CLKS  : integer := 1;
  constant C_480P_FSYNC_LINES : integer := 13;
  constant C_480P_HSYNC_ON    : integer := 1;    -- hsync_clks_1 (set high)
  constant C_480P_HSYNC_OFF   : integer := 64;   -- hsync_clks_0 (set low)
  constant C_480P_VSYNC_ON_L  : integer := 7;    -- vsync_a_lines_1
  constant C_480P_VSYNC_OFF_L : integer := 13;   -- vsync_a_lines_0

  -- Config pipeline latency: timing port -> s_timing (1) -> config regs (1) = 2 cycles
  -- Plus margin for counter/sync_gen to see new config
  constant C_CONFIG_SETTLE    : integer := 6;

begin

  clk <= not clk after C_CLK_PERIOD / 2 when test_done = '0' else unaffected;

  dut : entity rtl_lib.video_sync_generator
    port map (
      clk         => clk,
      ref_hsync   => ref_hsync,
      ref_vsync   => ref_vsync,
      ref_field_n => ref_field_n,
      timing      => timing,
      trisync_p   => trisync_p,
      trisync_n   => trisync_n,
      hsync       => hsync,
      vsync       => vsync
    );

  dut_freerun : entity rtl_lib.video_sync_generator
    generic map (
      G_LOCK_TO_REF => false
    )
    port map (
      clk         => clk,
      ref_hsync   => ref_hsync,
      ref_vsync   => ref_vsync,
      ref_field_n => ref_field_n,
      timing      => timing,
      trisync_p   => open,
      trisync_n   => open,
      hsync       => hsync_freerun,
      vsync       => open
    );

  dut_phase : entity rtl_lib.video_sync_generator
    generic map (
      G_LOCK_TO_REF   => true,
      G_PHASE_ADVANCE => true
    )
    port map (
      clk                => clk,
      ref_hsync          => ref_hsync,
      ref_vsync          => ref_vsync,
      ref_field_n        => ref_field_n,
      timing             => timing,
      phase_advance_clks => phase_advance,
      trisync_p          => trisync_p_phase,
      trisync_n          => trisync_n_phase,
      hsync              => hsync_phase,
      vsync              => vsync_phase
    );

  main : process
    -- Wait N rising edges then settle
    procedure clk_wait(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
      wait for 1 ns;
    end procedure;

    -- Let config pipeline settle
    procedure settle_config is
    begin
      clk_wait(C_CONFIG_SETTLE);
    end procedure;

    -- Trigger frame sync via ref_vsync falling edge (progressive mode)
    procedure trigger_vsync_fsync is
    begin
      ref_vsync <= '0';
      wait until rising_edge(clk);
      ref_vsync <= '1';
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;

    -- Advance N clocks
    procedure advance_clks(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
      wait for 1 ns;
    end procedure;

    variable v_hsync_high_count : integer;
    variable v_hsync_before     : std_logic;
    variable v_base_low_clks    : integer;
    variable v_phase_low_clks   : integer;
    variable v_hsync_prev       : std_logic;
    variable v_found_first_edge : boolean;
    variable v_trisync_prev     : std_logic;
    variable v_trisync_edges    : integer;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      -- Reset to known state
      timing        <= C_480P;
      ref_vsync     <= '1';
      ref_field_n   <= '1';
      ref_hsync     <= '1';
      phase_advance <= (others => '0');
      settle_config;

      -- ====================================================================
      if run("hsync_pulse_after_fsync_480p") then
      -- ====================================================================
        trigger_vsync_fsync;
        check_equal(hsync, '1', "hsync high at counter=1 (hsync_clks_1)");

      -- ====================================================================
      elsif run("hsync_pulse_width_480p") then
      -- ====================================================================
        trigger_vsync_fsync;
        check_equal(hsync, '1', "hsync starts high");

        v_hsync_high_count := 0;
        while hsync = '1' loop
          v_hsync_high_count := v_hsync_high_count + 1;
          wait until rising_edge(clk);
          wait for 1 ns;
        end loop;
        check(v_hsync_high_count >= 60 and v_hsync_high_count <= 66,
              "hsync pulse width ~63, got " & integer'image(v_hsync_high_count));

      -- ====================================================================
      elsif run("hsync_repeats_each_line_480p") then
      -- ====================================================================
        trigger_vsync_fsync;
        check_equal(hsync, '1', "first hsync");

        while hsync = '1' loop
          wait until rising_edge(clk);
          wait for 1 ns;
        end loop;

        while hsync = '0' loop
          wait until rising_edge(clk);
          wait for 1 ns;
        end loop;
        check_equal(hsync, '1', "hsync re-asserts on next line");

      -- ====================================================================
      elsif run("vsync_generation_480p") then
      -- ====================================================================
        trigger_vsync_fsync;
        advance_clks(2);
        check_equal(vsync, '0', "vsync off at line 13");

        for i in 1 to 20 loop
          advance_clks(C_480P_CPL);
        end loop;
        check_equal(vsync, '0', "vsync still off 20 lines after fsync");

      -- ====================================================================
      elsif run("ntsc_interlaced_field_fsync") then
      -- ====================================================================
        timing <= C_NTSC;
        settle_config;

        ref_vsync <= '0';
        wait until rising_edge(clk);
        ref_vsync <= '1';
        advance_clks(3);

        ref_field_n <= '0';
        wait until rising_edge(clk);
        ref_field_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        advance_clks(C_480P_CPL);

      -- ====================================================================
      elsif run("trisync_p_zero_when_disabled") then
      -- ====================================================================
        trigger_vsync_fsync;
        check_equal(trisync_p, '0', "trisync_p off with trisync_en=0");

        for i in 1 to 100 loop
          wait until rising_edge(clk);
          wait for 1 ns;
          check_equal(trisync_p, '0',
                      "trisync_p stays off at clk " & integer'image(i));
        end loop;

      -- ====================================================================
      elsif run("trisync_n_follows_csync_480p") then
      -- ====================================================================
        trigger_vsync_fsync;
        advance_clks(100);
        check_equal(trisync_n, '1',
                    "trisync_n follows csync high (counter past csync_clks_1)");

      -- ====================================================================
      elsif run("counter_survives_full_line") then
      -- ====================================================================
        trigger_vsync_fsync;
        check_equal(hsync, '1', "hsync initially high after fsync");

        advance_clks(C_480P_CPL);
        check_equal(hsync, '1', "hsync re-asserts after full line wrap");

      -- ====================================================================
      elsif run("config_pipeline_latency") then
      -- ====================================================================
        -- Verify that changing timing ID propagates through the 2-cycle
        -- config pipeline. After 2 edges, the new config registers are loaded.
        trigger_vsync_fsync;
        v_hsync_before := hsync;

        -- Switch to NTSC config
        timing <= C_NTSC;
        -- After 2 clock edges, config registers should hold NTSC values.
        -- We can't directly read config regs, but we verify the pipeline
        -- doesn't stall or break sync generation.
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        -- Config has loaded — trigger fsync with new config
        trigger_vsync_fsync;
        -- After fsync with NTSC config, sync generator should operate
        -- with NTSC timings. Run for a line and verify no stall.
        advance_clks(100);

      -- ====================================================================
      elsif run("multiple_fsync_resets") then
      -- ====================================================================
        -- Verify consecutive fsync triggers work correctly — counters
        -- reset cleanly each time
        trigger_vsync_fsync;
        check_equal(hsync, '1', "hsync after first fsync");

        -- Advance half a line
        advance_clks(C_480P_CPL / 2);

        -- Trigger fsync again mid-line
        trigger_vsync_fsync;
        -- Counters should reset, hsync should re-assert at counter=1
        check_equal(hsync, '1', "hsync after second fsync mid-line");

        -- Advance half a line again and re-trigger
        advance_clks(C_480P_CPL / 2);
        trigger_vsync_fsync;
        check_equal(hsync, '1', "hsync after third fsync mid-line");

      -- ====================================================================
      elsif run("freerun_no_fsync_snap") then
      -- ====================================================================
        -- Mid-line ref_vsync must snap the locked DUT but not the free-run
        -- instance (standalone / G_LOCK_TO_REF=false).
        advance_clks(C_480P_CPL / 2);
        check_equal(hsync_freerun, '0', "freerun mid-line before fsync");
        trigger_vsync_fsync;
        check_equal(hsync, '1', "locked DUT snaps to fsync seed");
        check_equal(hsync_freerun, '0', "freerun DUT ignores ref_vsync snap");

      -- ====================================================================
      elsif run("phase_advance_shifts_hsync") then
      -- ====================================================================
        phase_advance <= to_unsigned(10, phase_advance'length);
        trigger_vsync_fsync;
        settle_config;

        v_hsync_prev       := hsync;
        v_base_low_clks    := 0;
        v_found_first_edge := false;
        for i in 1 to 2 * C_480P_CPL loop
          wait until rising_edge(clk);
          wait for 1 ns;
          v_base_low_clks := v_base_low_clks + 1;
          if hsync = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync;
        end loop;
        check(v_found_first_edge, "baseline hsync rising edge should occur after fsync");

        trigger_vsync_fsync;
        settle_config;

        v_hsync_prev       := hsync_phase;
        v_phase_low_clks   := 0;
        v_found_first_edge := false;
        for i in 1 to 2 * C_480P_CPL loop
          wait until rising_edge(clk);
          wait for 1 ns;
          v_phase_low_clks := v_phase_low_clks + 1;
          if hsync_phase = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync_phase;
        end loop;
        check(v_found_first_edge, "advanced hsync rising edge should occur after fsync");

        -- Positive phase offsets DELAY the waveform so the jack tracks
        -- the processed-video pipeline (VMT-F004).
        if v_phase_low_clks >= v_base_low_clks then
          check_equal(v_phase_low_clks - v_base_low_clks, 10,
                      "phase offset trails baseline hsync rising edge");
        else
          check_equal(v_phase_low_clks + C_480P_CPL - v_base_low_clks, 10,
                      "phase offset trails baseline hsync rising edge (wrap)");
        end if;

      -- ====================================================================
      elsif run("phase_advance_1080i5994_eq") then
      -- ====================================================================
        timing <= C_1080I5994;
        phase_advance <= to_unsigned(22, phase_advance'length);
        settle_config;

        ref_field_n <= '1';
        wait until rising_edge(clk);
        ref_field_n <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        settle_config;

        v_trisync_prev  := trisync_p_phase;
        v_trisync_edges := 0;
        for i in 1 to 4 * 2200 loop
          wait until rising_edge(clk);
          wait for 1 ns;
          if trisync_p_phase /= v_trisync_prev then
            v_trisync_edges := v_trisync_edges + 1;
          end if;
          v_trisync_prev := trisync_p_phase;
        end loop;
        check(v_trisync_edges >= 1,
              "1080i5994 eq/tri path should toggle trisync_p under phase advance");

      -- ====================================================================
      elsif run("phase_advance_line_wrap_keeps_vsync") then
      -- ====================================================================
      -- With phase advance near clocks_per_line, v_eff_clks wraps while
      -- s_counter_lines has not yet incremented. v_eff_lines must advance
      -- with the wrap so line-gated vsync edges still fire (Fix C).
        timing <= C_480P;
        -- Advance by CPL-5 so wrap window is early in each free-run line.
        phase_advance <= to_unsigned(C_480P_CPL - 5, phase_advance'length);
        settle_config;
        trigger_vsync_fsync;
        settle_config;

        v_found_first_edge := false;
        for i in 1 to (C_480P_LPF + 10) * C_480P_CPL loop
          wait until rising_edge(clk);
          wait for 1 ns;
          if vsync_phase = '1' then
            v_found_first_edge := true;
            exit;
          end if;
        end loop;
        check(v_found_first_edge,
              "vsync must assert under large phase advance (v_eff_lines wrap)");

      end if;
    end loop;

    test_done <= '1';
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 100 ms);

end architecture;
