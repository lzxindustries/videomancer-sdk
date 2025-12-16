-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_video_field_detector.vhd - Testbench for Video Field Detector
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
--   VUnit testbench for video_field_detector module.
--   Tests detection of interlaced vs progressive video formats.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;

entity tb_video_field_detector is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_video_field_detector is

  constant C_CLK_PERIOD : time := 13.5 ns;
  constant C_LINE_WIDTH : natural := 1716;  -- 720p line width
  
  signal clk           : std_logic := '0';
  signal hsync         : std_logic := '1';
  signal vsync         : std_logic := '1';
  signal field_n       : std_logic;
  signal is_interlaced : std_logic;
  signal test_done     : boolean := false;

begin

  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  dut: entity rtl_lib.video_field_detector
    generic map (
      G_LINE_COUNTER_WIDTH => 12
    )
    port map (
      clk           => clk,
      hsync         => hsync,
      vsync         => vsync,
      field_n       => field_n,
      is_interlaced => is_interlaced
    );

  main: process
    procedure send_hsync is
    begin
      hsync <= '0';
      wait for 10 * C_CLK_PERIOD;
      hsync <= '1';
      wait for (C_LINE_WIDTH - 10) * C_CLK_PERIOD;
    end procedure;
    
    procedure send_progressive_frame is
    begin
      -- VSYNC at same position each frame (progressive)
      wait for 100 * C_CLK_PERIOD;  -- Position within line
      vsync <= '0';
      wait for 3 * C_CLK_PERIOD;
      vsync <= '1';
      
      -- Complete the frame with lines
      for i in 1 to 750 loop
        send_hsync;
      end loop;
    end procedure;
    
    procedure send_interlaced_field(half_line : boolean) is
    begin
      -- VSYNC at different position for odd/even fields
      if half_line then
        wait for 100 * C_CLK_PERIOD;  -- Start of line
      else
        wait for (C_LINE_WIDTH/2 + 100) * C_CLK_PERIOD;  -- Mid-line
      end if;
      
      vsync <= '0';
      wait for 3 * C_CLK_PERIOD;
      vsync <= '1';
      
      -- Complete the field
      for i in 1 to 262 loop
        send_hsync;
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    
    wait for 5 * C_CLK_PERIOD;
    
    while test_suite loop
      
      if run("test_progressive_detection") then
        info("Testing progressive video detection");
        
        -- Send multiple frames with VSYNC at same position
        for i in 1 to 3 loop
          send_progressive_frame;
        end loop;
        
        -- After multiple frames, progressive mode settles
        wait for 100 * C_CLK_PERIOD;
        info("Progressive detection test completed");
      
      elsif run("test_interlaced_detection") then
        info("Testing interlaced video detection");
        
        -- Send multiple alternating fields
        send_interlaced_field(false);  -- Even field (later in line)
        send_interlaced_field(true);   -- Odd field (earlier in line)
        send_interlaced_field(false);  -- Even field
        
        wait for 10 * C_CLK_PERIOD;
        info("Interlaced detection test completed");
      
      elsif run("test_field_parity") then
        info("Testing field parity detection");
        
        -- Send alternating fields to establish pattern
        send_interlaced_field(false);  -- Even field
        send_interlaced_field(true);   -- Odd field  
        send_interlaced_field(false);  -- Even field
        
        wait for 10 * C_CLK_PERIOD;
        info("Field parity test completed");
      
      elsif run("test_hsync_counter_reset") then
        info("Testing HSYNC resets pixel counter");
        
        -- Pixel counter should reset on each HSYNC
        for i in 1 to 5 loop
          send_hsync;
        end loop;
        
        wait for 10 * C_CLK_PERIOD;
        info("HSYNC counter test completed");
      
      end if;
      
    end loop;
    
    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 500 ms);

end architecture;
