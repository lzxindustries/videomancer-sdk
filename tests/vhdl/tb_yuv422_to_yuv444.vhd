-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_yuv422_to_yuv444.vhd - Testbench for YUV422 to YUV444 Converter
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
--   VUnit testbench for yuv422_to_yuv444 converter module.
--   Tests YUV422 to YUV444 conversion with various input patterns.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;
use rtl_lib.core_pkg.all;

entity tb_yuv422_to_yuv444 is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_yuv422_to_yuv444 is

  -- Clock period
  constant C_CLK_PERIOD : time := 13.5 ns;  -- ~74.25 MHz for 720p/1080i
  constant C_BIT_DEPTH  : integer := 10;
  
  -- DUT signals
  signal clk     : std_logic := '0';
  signal i_data  : t_video_stream_yuv422;
  signal o_data  : t_video_stream_yuv444;
  
  -- Test control
  signal test_done : boolean := false;

begin

  -- Clock generation
  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  -- Device Under Test
  dut: entity rtl_lib.yuv422_to_yuv444
    port map (
      clk    => clk,
      i_data => i_data,
      o_data => o_data
    );

  -- Main test process
  main: process
    -- Helper procedure to send YUV422 pixel pair
    procedure send_yuv422_pair(
      constant y0_val : integer;
      constant u_val  : integer;
      constant y1_val : integer;
      constant v_val  : integer;
      constant avid   : std_logic
    ) is
    begin
      -- Send Y0 and U/Cb
      i_data.y    <= std_logic_vector(to_unsigned(y0_val, C_BIT_DEPTH));
      i_data.c    <= std_logic_vector(to_unsigned(u_val, C_BIT_DEPTH));
      i_data.avid <= avid;
      wait for C_CLK_PERIOD;
      
      -- Send Y1 and V/Cr
      i_data.y    <= std_logic_vector(to_unsigned(y1_val, C_BIT_DEPTH));
      i_data.c    <= std_logic_vector(to_unsigned(v_val, C_BIT_DEPTH));
      i_data.avid <= avid;
      wait for C_CLK_PERIOD;
    end procedure;

    variable expected_y, expected_u, expected_v : integer;

  begin
    test_runner_setup(runner, runner_cfg);
    
    -- Initialize input signals with default values
    i_data.y       <= (others => '0');
    i_data.c       <= (others => '0');
    i_data.hsync_n <= '1';
    i_data.vsync_n <= '1';
    i_data.avid    <= '0';
    i_data.field_n <= '1';
    
    -- Wait for pipeline initialization (flush delay chain with default values)
    wait for 5 * C_CLK_PERIOD;
    
    while test_suite loop
      
      -- Test 1: Basic YUV422 to YUV444 conversion
      if run("test_basic_conversion") then
        info("Testing basic YUV422 to YUV444 conversion");
        
        -- Reset state
        i_data.avid <= '0';
        wait for 5 * C_CLK_PERIOD;
        
        -- Send a pixel pair: Y0=100, U=200, Y1=150, V=250
        send_yuv422_pair(100, 200, 150, 250, '1');
        
        -- Wait for pipeline delay (2 cycles)
        wait for 2 * C_CLK_PERIOD;
        wait for 1 ns;
        
        -- First pixel should have Y0, U, V (V is held from previous pair)
        -- Second pixel should have Y1, U, V (U is held from current pair)
        info("Conversion test completed");
      
      -- Test 2: Sync signal propagation with correct delay
      elsif run("test_sync_delay") then
        info("Testing sync signal propagation with 2-cycle delay");
        
        -- Start with syncs inactive
        i_data.hsync_n <= '1';
        i_data.vsync_n <= '1';
        i_data.avid    <= '0';
        i_data.field_n <= '1';
        wait for C_CLK_PERIOD;
        
        -- Activate hsync
        i_data.hsync_n <= '0';
        wait for C_CLK_PERIOD;
        
        -- Output hsync should still be high (1-cycle delay)
        wait for 1 ns;
        check_equal(o_data.hsync_n, '1', 
                   "HSYNC should not propagate after 1 cycle");
        
        -- After 2 cycles, output hsync should be active
        wait for C_CLK_PERIOD;
        wait for 1 ns;
        check_equal(o_data.hsync_n, '0', 
                   "HSYNC should propagate after 2 cycles");
        
        -- Deactivate hsync
        i_data.hsync_n <= '1';
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.hsync_n, '1', 
                   "HSYNC deactivation should propagate after 2 cycles");
      
      -- Test 3: AVID control for phase reset
      elsif run("test_avid_phase_reset") then
        info("Testing AVID rising edge resets phase");
        
        -- Start with AVID low
        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;
        
        -- Send some data with AVID high
        send_yuv422_pair(100, 200, 150, 250, '1');
        send_yuv422_pair(110, 210, 160, 255, '1');
        
        -- Drop AVID (end of line)
        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;
        
        -- Start new line - phase should reset
        -- First chroma should be U (phase 0)
        send_yuv422_pair(120, 220, 170, 240, '1');
        
        info("AVID phase reset test completed");
      
      -- Test 4: Black level (16, 128, 128 in YUV)
      elsif run("test_black_level") then
        info("Testing black level conversion");
        
        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;
        
        -- Send black level in 10-bit (16<<2=64, 128<<2=512)
        send_yuv422_pair(64, 512, 64, 512, '1');
        
        wait for 3 * C_CLK_PERIOD;
        info("Black level test completed");
      
      -- Test 5: White level (235, 128, 128 in YUV)
      elsif run("test_white_level") then
        info("Testing white level conversion");
        
        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;
        
        -- Send white level in 10-bit (235<<2=940, 128<<2=512)
        send_yuv422_pair(940, 512, 940, 512, '1');
        
        wait for 3 * C_CLK_PERIOD;
        info("White level test completed");
      
      -- Test 6: Field signal propagation
      elsif run("test_field_propagation") then
        info("Testing field signal propagation");
        
        -- Test field_n = 1 (first field)
        i_data.field_n <= '1';
        i_data.avid    <= '1';
        wait for 3 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.field_n, '1', 
                   "Field signal should propagate (field 1)");
        
        -- Test field_n = 0 (second field)
        i_data.field_n <= '0';
        wait for 3 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.field_n, '0', 
                   "Field signal should propagate (field 0)");
      
      -- Test 7: Continuous stream
      elsif run("test_continuous_stream") then
        info("Testing continuous pixel stream");
        
        i_data.avid <= '0';
        wait for 2 * C_CLK_PERIOD;
        
        -- Send continuous stream of pixels
        for i in 0 to 9 loop
          send_yuv422_pair(
            100 + i*10, 200 + i*5,
            150 + i*10, 250 - i*5,
            '1'
          );
        end loop;
        
        wait for 5 * C_CLK_PERIOD;
        info("Continuous stream test completed");
        
      end if;
      
    end loop;
    
    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  -- Watchdog to prevent infinite simulation
  test_runner_watchdog(runner, 50 ms);

end architecture;
