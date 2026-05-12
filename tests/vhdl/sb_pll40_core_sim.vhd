-- Videomancer SDK - Behavioral SB_PLL40_CORE simulation stub
-- Copyright (C) 2025 LZX Industries LLC
-- SPDX-License-Identifier: GPL-3.0-only
--
-- A minimal, simulation-only behavioural model of Lattice's SB_PLL40_CORE
-- primitive.  Enough to exercise the surrounding VHDL wrapper in GHDL.
--
-- Limitations:
--   * Generics other than DIVR / DIVF / DIVQ are ignored.
--   * F_OUT = F_REF * (DIVF + 1) / ((DIVR + 1) * 2**DIVQ)  -- SIMPLE feedback.
--   * Output begins toggling at F_OUT once RESETB has been high for >= 50 ns.
--   * LOCK rises 1 us after RESETB deassertion.
--   * BYPASS routes REFERENCECLK directly to PLLOUTCORE/PLLOUTGLOBAL.
--   * No phase noise, no jitter, no startup glitches.
--
-- This stub allows pure-GHDL testing of any wrapper that instantiates
-- SB_PLL40_CORE.  For sign-off simulation use Lattice's iCEcube2
-- sim_ice40 libraries instead.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SB_PLL40_CORE is
  generic (
    FEEDBACK_PATH : string := "SIMPLE";
    DIVR : std_logic_vector(3 downto 0) := "0000";
    DIVF : std_logic_vector(6 downto 0) := "0000000";
    DIVQ : std_logic_vector(2 downto 0) := "000";
    FILTER_RANGE : std_logic_vector(2 downto 0) := "000"
  );
  port (
    REFERENCECLK : in  std_logic;
    PLLOUTCORE   : out std_logic;
    PLLOUTGLOBAL : out std_logic;
    LOCK         : out std_logic;
    RESETB       : in  std_logic;
    BYPASS       : in  std_logic
  );
end entity SB_PLL40_CORE;

architecture sim of SB_PLL40_CORE is
  constant C_LOCK_DELAY : time := 1 us;
  signal s_pll_out : std_logic := '0';
  signal s_lock    : std_logic := '0';
begin

  -- Generate the PLL output.  Measure REFERENCECLK period over one cycle,
  -- compute output period, then toggle a free-running clock at that rate
  -- while RESETB is high.
  p_gen : process
    variable v_t0       : time;
    variable v_ref_per  : time := 0 ns;
    variable v_out_per  : time;
    variable v_divr_int : integer;
    variable v_divf_int : integer;
    variable v_divq_int : integer;
  begin
    s_pll_out <= '0';
    -- Wait for RESETB to release.
    wait until RESETB = '1';

    -- Measure REFERENCECLK period.
    wait until rising_edge(REFERENCECLK);
    v_t0 := now;
    wait until rising_edge(REFERENCECLK);
    v_ref_per := now - v_t0;

    v_divr_int := to_integer(unsigned(DIVR));
    v_divf_int := to_integer(unsigned(DIVF));
    v_divq_int := to_integer(unsigned(DIVQ));

    -- F_OUT = F_REF * (DIVF + 1) / ((DIVR + 1) * 2**DIVQ)
    -- => T_OUT = T_REF * (DIVR + 1) * 2**DIVQ / (DIVF + 1)
    v_out_per := v_ref_per * ((v_divr_int + 1) * (2 ** v_divq_int)) /
                 (v_divf_int + 1);

    -- Free-run at v_out_per until RESETB drops.
    while RESETB = '1' loop
      s_pll_out <= '0';
      wait for v_out_per / 2;
      exit when RESETB = '0';
      s_pll_out <= '1';
      wait for v_out_per / 2;
    end loop;
  end process;

  -- Lock rises C_LOCK_DELAY after RESETB deassertion, falls immediately on reset.
  p_lock : process(RESETB)
  begin
    if RESETB = '0' then
      s_lock <= '0';
    elsif rising_edge(RESETB) then
      s_lock <= '0', '1' after C_LOCK_DELAY;
    end if;
  end process;

  PLLOUTCORE   <= REFERENCECLK when BYPASS = '1' else s_pll_out;
  PLLOUTGLOBAL <= REFERENCECLK when BYPASS = '1' else s_pll_out;
  LOCK         <= '1'          when BYPASS = '1' else s_lock;

end architecture sim;
