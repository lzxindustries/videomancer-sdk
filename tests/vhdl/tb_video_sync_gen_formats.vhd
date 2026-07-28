-- Videomancer SDK - VUnit Testbench for video_sync_generator (all formats)
-- Copyright (C) 2025 LZX Industries LLC
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Parameterized testbench exercising video_sync_generator across all 15
-- video timing formats. Each VUnit config supplies the timing ID and
-- expected per-format properties (clocks_per_line, interlaced, trisync_en).
--
-- Tests per config:
--   1. hsync_and_trisync_active - HSYNC edges appear after fsync; trisync
--      behaviour matches the config flag
--   2. hsync_period_matches_line - the rising-edge period of HSYNC equals
--      clocks_per_line
--   3. phase_advance_shifts_hsync (G_PHASE_ADVANCE=1 only)
--   4. phase_advance_preserves_line_period (G_PHASE_ADVANCE=1 only)
--   5. eq_trisync_under_advance (G_PHASE_ADVANCE=1, interlaced tri only)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;
use rtl_lib.video_sync_pkg.all;

entity tb_video_sync_gen_formats is
  generic (
    runner_cfg         : string;
    G_TIMING_ID        : natural := 4;
    G_CLOCKS_PER_LINE  : natural := 858;
    G_IS_INTERLACED    : natural := 0;
    G_TRISYNC_EN       : natural := 0;
    G_PHASE_ADVANCE    : natural := 0;
    G_PHASE_ADVANCE_CLKS : natural := 20
  );
end entity;

architecture tb of tb_video_sync_gen_formats is

  constant C_CLK_PERIOD    : time    := 10 ns;
  constant C_CONFIG_SETTLE : integer := 10;

  signal clk              : std_logic := '0';
  signal ref_hsync        : std_logic := '0';
  signal ref_vsync        : std_logic := '0';
  signal ref_field_n      : std_logic := '0';
  signal timing           : std_logic_vector(3 downto 0) := "0100";
  signal phase_advance    : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal trisync_p        : std_logic;
  signal trisync_n        : std_logic;
  signal hsync            : std_logic;
  signal vsync            : std_logic;
  signal trisync_p_adv    : std_logic;
  signal trisync_n_adv    : std_logic;
  signal hsync_adv        : std_logic;
  signal vsync_adv        : std_logic;

  -- ================================================================
  -- Helper: trigger frame sync via appropriate reference signal
  -- ================================================================
  procedure trigger_fsync(
    signal r_vsync   : out std_logic;
    signal r_field_n : out std_logic;
    constant interlaced : natural
  ) is
  begin
    if interlaced = 1 then
      r_field_n <= '1';
      wait until rising_edge(clk);
      r_field_n <= '0';
    else
      r_vsync <= '1';
      wait until rising_edge(clk);
      r_vsync <= '0';
    end if;
    wait until rising_edge(clk);
  end procedure;

  procedure advance_clks(signal s_clk : std_logic; n : integer) is
  begin
    for i in 1 to n loop
      wait until rising_edge(s_clk);
    end loop;
    wait for 1 ns;
  end procedure;

begin

  clk <= not clk after C_CLK_PERIOD / 2;

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

  dut_adv : entity rtl_lib.video_sync_generator
    generic map (
      G_LOCK_TO_REF   => true,
      G_PHASE_ADVANCE => (G_PHASE_ADVANCE = 1)
    )
    port map (
      clk                => clk,
      ref_hsync          => ref_hsync,
      ref_vsync          => ref_vsync,
      ref_field_n        => ref_field_n,
      timing             => timing,
      phase_advance_clks => phase_advance,
      trisync_p          => trisync_p_adv,
      trisync_n          => trisync_n_adv,
      hsync              => hsync_adv,
      vsync              => open
    );

  main : process
    variable v_hsync_prev          : std_logic;
    variable v_hsync_edge_count    : integer;
    variable v_trisync_stayed_zero : boolean;
    variable v_trisync_edge_count  : integer;
    variable v_trisync_prev        : std_logic;
    variable v_period_count        : integer;
    variable v_found_first_edge    : boolean;
    variable v_base_high           : integer;
    variable v_adv_high            : integer;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop

      timing      <= std_logic_vector(to_unsigned(G_TIMING_ID, 4));
      ref_hsync   <= '0';
      ref_vsync   <= '0';
      ref_field_n <= '0';
      if G_PHASE_ADVANCE = 1 then
        phase_advance <= to_unsigned(G_PHASE_ADVANCE_CLKS, phase_advance'length);
      else
        phase_advance <= (others => '0');
      end if;

      for i in 1 to C_CONFIG_SETTLE loop
        wait until rising_edge(clk);
      end loop;

      trigger_fsync(ref_vsync, ref_field_n, G_IS_INTERLACED);

      for i in 1 to C_CONFIG_SETTLE loop
        wait until rising_edge(clk);
      end loop;

      -- ============================================================
      if run("hsync_and_trisync_active") then
      -- ============================================================
        v_hsync_prev       := hsync;
        v_hsync_edge_count := 0;

        v_trisync_prev        := trisync_p;
        v_trisync_edge_count  := 0;
        v_trisync_stayed_zero := true;

        for i in 1 to 2 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);

          if hsync /= v_hsync_prev then
            v_hsync_edge_count := v_hsync_edge_count + 1;
          end if;
          v_hsync_prev := hsync;

          if trisync_p /= '0' then
            v_trisync_stayed_zero := false;
          end if;
          if trisync_p /= v_trisync_prev then
            v_trisync_edge_count := v_trisync_edge_count + 1;
          end if;
          v_trisync_prev := trisync_p;
        end loop;

        check(v_hsync_edge_count >= 2,
              "HSYNC should have >= 2 edges in 2 lines (got " &
              integer'image(v_hsync_edge_count) & ")");

        if G_TRISYNC_EN = 1 then
          check(v_trisync_edge_count >= 2,
                "trisync_p should be active when enabled (got " &
                integer'image(v_trisync_edge_count) & " edges)");
        else
          check(v_trisync_stayed_zero,
                "trisync_p should stay zero when disabled");
        end if;

      -- ============================================================
      elsif run("hsync_period_matches_line") then
      -- ============================================================
        v_hsync_prev       := hsync;
        v_found_first_edge := false;

        for i in 1 to 2 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);
          if hsync = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync;
        end loop;

        check(v_found_first_edge,
              "Should find an HSYNC rising edge within 2 line periods");

        v_hsync_prev   := hsync;
        v_period_count := 0;

        for i in 1 to G_CLOCKS_PER_LINE + 10 loop
          wait until rising_edge(clk);
          v_period_count := v_period_count + 1;
          if hsync = '1' and v_hsync_prev = '0' then
            check_equal(v_period_count, G_CLOCKS_PER_LINE,
                        "HSYNC period should equal clocks_per_line (" &
                        integer'image(G_CLOCKS_PER_LINE) & ")");
            exit;
          end if;
          v_hsync_prev := hsync;
        end loop;

      -- ============================================================
      elsif run("phase_advance_shifts_hsync") and G_PHASE_ADVANCE = 1 then
      -- ============================================================
        trigger_fsync(ref_vsync, ref_field_n, G_IS_INTERLACED);
        advance_clks(clk, C_CONFIG_SETTLE);

        v_hsync_prev       := hsync;
        v_base_high        := 0;
        v_found_first_edge := false;
        for i in 1 to 2 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);
          wait for 1 ns;
          v_base_high := v_base_high + 1;
          if hsync = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync;
        end loop;
        check(v_found_first_edge, "baseline hsync rising edge should occur after fsync");

        trigger_fsync(ref_vsync, ref_field_n, G_IS_INTERLACED);
        advance_clks(clk, C_CONFIG_SETTLE);

        v_hsync_prev       := hsync_adv;
        v_adv_high         := 0;
        v_found_first_edge := false;
        for i in 1 to 2 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);
          wait for 1 ns;
          v_adv_high := v_adv_high + 1;
          if hsync_adv = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync_adv;
        end loop;
        check(v_found_first_edge, "advanced hsync rising edge should occur after fsync");

        -- Positive phase offsets DELAY the waveform so the jack tracks
        -- the processed-video pipeline (VMT-F004: the original advance
        -- direction pushed jack sync 2x the pipeline delay ahead of
        -- jack video).
        if v_adv_high >= v_base_high then
          check_equal(v_adv_high - v_base_high, G_PHASE_ADVANCE_CLKS,
                      "phase offset trails baseline hsync rising edge");
        else
          check_equal(v_adv_high + G_CLOCKS_PER_LINE - v_base_high, G_PHASE_ADVANCE_CLKS,
                      "phase offset trails baseline hsync rising edge (wrap)");
        end if;

      -- ============================================================
      elsif run("phase_advance_preserves_line_period") and G_PHASE_ADVANCE = 1 then
      -- ============================================================
        trigger_fsync(ref_vsync, ref_field_n, G_IS_INTERLACED);
        advance_clks(clk, C_CONFIG_SETTLE);

        v_hsync_prev       := hsync_adv;
        v_found_first_edge := false;

        for i in 1 to 2 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);
          if hsync_adv = '1' and v_hsync_prev = '0' then
            v_found_first_edge := true;
            exit;
          end if;
          v_hsync_prev := hsync_adv;
        end loop;

        check(v_found_first_edge,
              "Advanced DUT should produce HSYNC rising edge");

        v_hsync_prev   := hsync_adv;
        v_period_count := 0;

        for i in 1 to G_CLOCKS_PER_LINE + 10 loop
          wait until rising_edge(clk);
          v_period_count := v_period_count + 1;
          if hsync_adv = '1' and v_hsync_prev = '0' then
            check_equal(v_period_count, G_CLOCKS_PER_LINE,
                        "Advanced HSYNC period should equal clocks_per_line");
            exit;
          end if;
          v_hsync_prev := hsync_adv;
        end loop;

      -- ============================================================
      elsif run("eq_trisync_under_advance")
           and G_PHASE_ADVANCE = 1
           and G_IS_INTERLACED = 1
           and G_TRISYNC_EN = 1 then
      -- ============================================================
        trigger_fsync(ref_vsync, ref_field_n, G_IS_INTERLACED);
        advance_clks(clk, C_CONFIG_SETTLE);

        v_trisync_prev       := trisync_p_adv;
        v_trisync_edge_count := 0;

        for i in 1 to 4 * G_CLOCKS_PER_LINE loop
          wait until rising_edge(clk);
          if trisync_p_adv /= v_trisync_prev then
            v_trisync_edge_count := v_trisync_edge_count + 1;
          end if;
          v_trisync_prev := trisync_p_adv;
        end loop;

        check(v_trisync_edge_count >= 1,
              "trisync_p should toggle under phase advance on interlaced tri-level format");

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 200 ms);

end architecture;
