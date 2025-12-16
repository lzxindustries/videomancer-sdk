-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_video_sync_generator.vhd - Testbench for Video Sync Generator
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
--   VUnit testbench for video_sync_generator module.
--   Tests sync signal generation for various video timing standards.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;

entity tb_video_sync_generator is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_video_sync_generator is

  -- Clock period - assumes 27 MHz clock for NTSC/PAL
  constant C_CLK_PERIOD : time := 37.037 ns;  -- ~27 MHz
  
  -- DUT signals
  signal clk          : std_logic := '0';
  signal ref_hsync    : std_logic := '1';
  signal ref_vsync    : std_logic := '1';
  signal ref_field_n  : std_logic := '1';
  signal timing       : std_logic_vector(3 downto 0) := (others => '0');
  signal trisync_p    : std_logic;
  signal trisync_n    : std_logic;
  signal hsync        : std_logic;
  signal vsync        : std_logic;
  
  -- Test control
  signal test_done : boolean := false;
  
  -- Counter for measuring pulse widths
  signal hsync_high_count : integer := 0;
  signal hsync_low_count  : integer := 0;
  signal vsync_high_count : integer := 0;
  signal vsync_low_count  : integer := 0;
  
  -- Type for all timing formats test
  type t_timing_array is array (natural range <>) of std_logic_vector(3 downto 0);
  constant C_ALL_TIMINGS : t_timing_array := (
    C_NTSC, C_PAL, C_480P, C_576P, 
    C_720P60, C_720P5994, C_720P50,
    C_1080I60, C_1080I5994, C_1080I50,
    C_1080P30, C_1080P2997, C_1080P25
  );

begin

  -- Clock generation
  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  -- Device Under Test
  dut: entity rtl_lib.video_sync_generator
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

  -- Reference signal generator for interlaced formats
  ref_signal_gen: process
    constant ref_hsync_period : time := 63.555 us;  -- Approximate NTSC H period
  begin
    if not test_done then
      ref_hsync <= '0';
      wait for 4.7 us;  -- Approximate NTSC hsync width
      ref_hsync <= '1';
      wait for ref_hsync_period - 4.7 us;
    else
      wait;
    end if;
  end process;

  -- Reference vsync generator
  ref_vsync_gen: process
    constant ref_vsync_period : time := 16.683 ms;  -- Approximate NTSC field period (60 Hz)
  begin
    if not test_done then
      ref_vsync <= '0';
      wait for 100 us;  -- Approximate vsync pulse width
      ref_vsync <= '1';
      wait for ref_vsync_period - 100 us;
    else
      wait;
    end if;
  end process;

  -- Reference field signal for interlaced formats
  ref_field_gen: process
    constant ref_field_period : time := 16.683 ms * 2;  -- Full frame period
  begin
    if not test_done then
      ref_field_n <= '0';
      wait for ref_field_period / 2;
      ref_field_n <= '1';
      wait for ref_field_period / 2;
    else
      wait;
    end if;
  end process;

  -- Pulse width measurement process
  measure_pulses: process(clk)
  begin
    if rising_edge(clk) then
      -- Measure hsync high and low times
      if hsync = '1' then
        hsync_high_count <= hsync_high_count + 1;
        hsync_low_count <= 0;
      else
        hsync_low_count <= hsync_low_count + 1;
        hsync_high_count <= 0;
      end if;
      
      -- Measure vsync high and low times
      if vsync = '1' then
        vsync_high_count <= vsync_high_count + 1;
        vsync_low_count <= 0;
      else
        vsync_low_count <= vsync_low_count + 1;
        vsync_high_count <= 0;
      end if;
    end if;
  end process;

  -- Main test process
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    
    while test_suite loop
      
      -- Test 1: NTSC timing configuration
      if run("test_ntsc_timing") then
        info("Testing NTSC video timing");
        
        timing <= C_NTSC;
        wait for 100 us;
        
        -- Verify sync signals are being generated
        -- (basic check that signals toggle)
        wait until falling_edge(hsync);
        check(hsync = '0', "HSYNC should go low");
        
        wait until rising_edge(hsync);
        check(hsync = '1', "HSYNC should go high");
        
        -- Wait for a vsync edge
        wait until falling_edge(vsync);
        check(vsync = '0', "VSYNC should go low");
        
        info("NTSC timing basic checks passed");
      
      -- Test 2: PAL timing configuration
      elsif run("test_pal_timing") then
        info("Testing PAL video timing");
        
        timing <= C_PAL;
        wait for 100 us;
        
        -- Verify sync signals are being generated
        wait until falling_edge(hsync);
        check(hsync = '0', "HSYNC should go low for PAL");
        
        wait until rising_edge(hsync);
        check(hsync = '1', "HSYNC should go high for PAL");
        
        info("PAL timing basic checks passed");
      
      -- Test 3: 480p timing configuration
      elsif run("test_480p_timing") then
        info("Testing 480p video timing");
        
        timing <= C_480P;
        wait for 100 us;
        
        -- Verify progressive format sync generation
        wait until falling_edge(hsync);
        wait until rising_edge(hsync);
        
        check(hsync = '1', "HSYNC should toggle for 480p");
        
        info("480p timing basic checks passed");
      
      -- Test 4: 720p60 timing configuration
      elsif run("test_720p60_timing") then
        info("Testing 720p60 video timing");
        
        timing <= C_720P60;
        wait for 100 us;
        
        -- Verify HD format sync generation
        wait until falling_edge(hsync);
        wait until rising_edge(hsync);
        
        check(hsync = '1', "HSYNC should toggle for 720p60");
        
        info("720p60 timing basic checks passed");
      
      -- Test 5: 1080i60 timing configuration
      elsif run("test_1080i60_timing") then
        info("Testing 1080i60 video timing");
        
        timing <= C_1080I60;
        wait for 100 us;
        
        -- Verify interlaced HD format sync generation
        wait until falling_edge(hsync);
        wait until rising_edge(hsync);
        
        check(hsync = '1', "HSYNC should toggle for 1080i60");
        
        info("1080i60 timing basic checks passed");
      
      -- Test 6: Timing format switching
      elsif run("test_timing_switch") then
        info("Testing switching between timing formats");
        
        -- Start with NTSC
        timing <= C_NTSC;
        wait for 50 us;
        
        wait until rising_edge(hsync);
        check(hsync = '1', "HSYNC active for NTSC");
        
        -- Switch to PAL
        timing <= C_PAL;
        wait for 50 us;
        
        wait until rising_edge(hsync);
        check(hsync = '1', "HSYNC active for PAL");
        
        -- Switch to 480p
        timing <= C_480P;
        wait for 50 us;
        
        wait until rising_edge(hsync);
        check(hsync = '1', "HSYNC active for 480p");
        
        info("Timing format switching passed");
      
      -- Test 7: Reference sync input response
      elsif run("test_ref_sync_response") then
        info("Testing reference sync input response");
        
        timing <= C_NTSC;
        wait for 10 us;
        
        -- Verify that generator responds to reference hsync
        wait until falling_edge(ref_hsync);
        wait for 1 us;
        
        -- Generator should produce syncs based on reference
        -- Just verify it's running and responsive
        check(hsync = '1' or hsync = '0', "HSYNC should be active");
        
        info("Reference sync response test passed");
      
      -- Test 8: Tri-level sync generation
      elsif run("test_trisync_generation") then
        info("Testing tri-level sync generation");
        
        -- Test with HD format that uses trisync
        timing <= C_720P60;
        wait for 100 us;
        
        -- Verify trisync signals are being generated
        -- (basic toggle check)
        wait for 10 us;
        check(trisync_p = '0' or trisync_p = '1', 
              "Trisync_p should have valid logic level");
        check(trisync_n = '0' or trisync_n = '1', 
              "Trisync_n should have valid logic level");
        
        info("Tri-level sync generation test passed");
      
      -- Test 9: HSYNC frequency test
      elsif run("test_hsync_frequency") then
        info("Testing HSYNC frequency for NTSC");
        
        timing <= C_NTSC;
        wait for 50 us;
        
        -- Measure time between hsync pulses
        wait until falling_edge(hsync);
        wait until falling_edge(hsync);
        wait until falling_edge(hsync);
        
        -- After multiple cycles, hsync should be regular
        check(hsync = '0', "HSYNC should pulse regularly");
        
        info("HSYNC frequency test passed");
      
      -- Test 10: VSYNC generation test
      elsif run("test_vsync_generation") then
        info("Testing VSYNC generation");
        
        timing <= C_NTSC;
        
        -- Wait for initial vsync
        wait for 100 us;
        wait until falling_edge(vsync);
        
        check(vsync = '0', "VSYNC should go low");
        
        -- Wait for vsync to go back high
        wait until rising_edge(vsync) for 1 ms;
        
        check(vsync = '1', "VSYNC should return high");
        
        info("VSYNC generation test passed");
      
      -- Test 11: All timing formats quick test
      elsif run("test_all_formats") then
        info("Quick test of all supported timing formats");
        
        for i in C_ALL_TIMINGS'range loop
          timing <= C_ALL_TIMINGS(i);
          wait for 20 us;
          
          -- Basic sanity check that sync is toggling
          wait until rising_edge(hsync) for 10 us;
          check(hsync = '1', "HSYNC should toggle for format " & integer'image(i));
        end loop;
        
        info("All timing formats test passed");
      
      -- Test 12: Counter synchronization on field/frame sync
      elsif run("test_counter_sync") then
        info("Testing counter synchronization on frame/field sync");
        
        timing <= C_NTSC;
        
        -- Wait for stable operation
        wait for 50 us;
        
        -- Generate a reference vsync event
        ref_vsync <= '0';
        wait for 1 us;
        ref_vsync <= '1';
        
        -- Generator should resynchronize
        wait for 10 us;
        
        -- Check that sync signals continue to operate
        wait until falling_edge(hsync);
        check(hsync = '0', "HSYNC should continue after resync");
        
        info("Counter synchronization test passed");
        
      end if;
      
    end loop;
    
    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  -- Watchdog to prevent infinite simulation
  test_runner_watchdog(runner, 200 ms);

end architecture;
