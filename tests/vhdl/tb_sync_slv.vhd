-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_sync_slv.vhd - Testbench for Clock Domain Synchronizer
-- License: GNU General Public License v3.0
-- https://github.com/lzxindustries/videomancer-sdk
--
-- This file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- Description:
--   VUnit testbench for sync_slv (clock domain synchronizer) module.
--   Tests basic synchronization behavior and verifies 2-FF delay chain.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;

entity tb_sync_slv is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_sync_slv is

  -- Clock period
  constant C_CLK_PERIOD : time := 10 ns;
  
  -- Test vector width
  constant C_WIDTH : integer := 8;
  
  -- DUT signals
  signal clk : std_logic := '0';
  signal a   : std_logic_vector(C_WIDTH-1 downto 0) := (others => '0');
  signal b   : std_logic_vector(C_WIDTH-1 downto 0);
  
  -- Test control
  signal test_done : boolean := false;

begin

  -- Clock generation
  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  -- Device Under Test
  dut: entity rtl_lib.sync_slv
    port map (
      clk => clk,
      a   => a,
      b   => b
    );

  -- Main test process
  main: process
    variable expected : std_logic_vector(C_WIDTH-1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    
    while test_suite loop
      
      -- Test 1: Basic synchronization with zero value
      if run("test_sync_zeros") then
        info("Testing synchronization of zero value");
        
        -- Set input to zeros
        a <= (others => '0');
        wait for C_CLK_PERIOD;
        
        -- After 2 clock cycles, output should be stable at zero
        wait for C_CLK_PERIOD;
        wait for C_CLK_PERIOD;
        
        check_equal(b, std_logic_vector(to_unsigned(0, C_WIDTH)), 
                   "Output should be zero after 2 clock cycles");
      
      -- Test 2: Basic synchronization with non-zero value
      elsif run("test_sync_value") then
        info("Testing synchronization of non-zero value");
        
        -- Set input to a known value
        expected := x"A5";
        a <= expected;
        
        -- Wait one clock cycle - output should still be old value
        wait for C_CLK_PERIOD;
        wait for 1 ns;
        check(b /= expected, 
             "Output should not match input after 1 clock cycle");
        
        -- Wait another clock cycle - output should now match
        wait for C_CLK_PERIOD;
        wait for 1 ns;
        check_equal(b, expected, 
                   "Output should match input after 2 clock cycles");
      
      -- Test 3: Value change propagation
      elsif run("test_value_changes") then
        info("Testing multiple value changes");
        
        -- Test multiple transitions
        for i in 0 to 15 loop
          expected := std_logic_vector(to_unsigned(i, C_WIDTH));
          a <= expected;
          
          -- Wait 2 clock cycles for synchronization
          wait for 2 * C_CLK_PERIOD;
          wait for 1 ns;
          
          check_equal(b, expected, 
                     "Output should match input value " & integer'image(i));
        end loop;
      
      -- Test 4: Verify 2-FF delay (metastability protection)
      elsif run("test_two_ff_delay") then
        info("Testing 2-FF synchronization delay");
        
        -- Set initial value
        a <= x"00";
        wait for 3 * C_CLK_PERIOD;
        
        -- Change input and verify delay
        a <= x"FF";
        wait for 1 ns;  -- Small delta to avoid clock edge
        
        -- After 0 clocks, output should still be old value
        check_equal(b, std_logic_vector(to_unsigned(0, C_WIDTH)),
                   "Output should not change immediately");
        
        -- After 1 clock, output should still be old value (first FF)
        wait for C_CLK_PERIOD;
        wait for 1 ns;
        check_equal(b, std_logic_vector(to_unsigned(0, C_WIDTH)),
                   "Output should not change after 1 clock (first FF)");
        
        -- After 2 clocks, output should have new value (second FF)
        wait for C_CLK_PERIOD;
        wait for 1 ns;
        check_equal(b, std_logic_vector'(x"FF"),
                   "Output should change after 2 clocks (second FF)");
      
      -- Test 5: All bits transition
      elsif run("test_all_bits") then
        info("Testing all bits can be synchronized");
        
        -- Test that all bits can transition independently
        a <= x"AA";  -- 10101010
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(b, std_logic_vector'(x"AA"), "Pattern 0xAA should synchronize");
        
        a <= x"55";  -- 01010101
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(b, std_logic_vector'(x"55"), "Pattern 0x55 should synchronize");
        
        a <= x"F0";  -- 11110000
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(b, std_logic_vector'(x"F0"), "Pattern 0xF0 should synchronize");
        
        a <= x"0F";  -- 00001111
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(b, std_logic_vector'(x"0F"), "Pattern 0x0F should synchronize");
        
      end if;
      
    end loop;
    
    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  -- Watchdog to prevent infinite simulation
  test_runner_watchdog(runner, 10 ms);

end architecture;
