-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_blanking_yuv444.vhd - Testbench for YUV444 Blanking Module
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
--   VUnit testbench for blanking_yuv444 module.
--   Tests blanking interval replacement with black level.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;

entity tb_blanking_yuv444 is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_blanking_yuv444 is

  constant C_CLK_PERIOD : time := 13.5 ns;
  constant C_BIT_DEPTH  : integer := 10;

  -- Black level values in 10-bit
  constant C_BLACK_Y : unsigned(C_BIT_DEPTH-1 downto 0) := to_unsigned(0, C_BIT_DEPTH);
  constant C_BLACK_U : unsigned(C_BIT_DEPTH-1 downto 0) := to_unsigned(512, C_BIT_DEPTH);
  constant C_BLACK_V : unsigned(C_BIT_DEPTH-1 downto 0) := to_unsigned(512, C_BIT_DEPTH);

  signal clk       : std_logic := '0';
  signal data_in   : t_video_stream_yuv444;
  signal data_out  : t_video_stream_yuv444;
  signal test_done : boolean := false;

begin

  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  dut: entity rtl_lib.blanking_yuv444
    port map (
      clk      => clk,
      data_in  => data_in,
      data_out => data_out
    );

  main: process
    procedure send_pixel(
      constant y_val    : integer;
      constant u_val    : integer;
      constant v_val    : integer;
      constant avid     : std_logic;
      constant hsync_n  : std_logic := '1';
      constant vsync_n  : std_logic := '1';
      constant field_n  : std_logic := '1'
    ) is
    begin
      data_in.y       <= std_logic_vector(to_unsigned(y_val, C_BIT_DEPTH));
      data_in.u       <= std_logic_vector(to_unsigned(u_val, C_BIT_DEPTH));
      data_in.v       <= std_logic_vector(to_unsigned(v_val, C_BIT_DEPTH));
      data_in.avid    <= avid;
      data_in.hsync_n <= hsync_n;
      data_in.vsync_n <= vsync_n;
      data_in.field_n <= field_n;
      wait for C_CLK_PERIOD;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- Initialize signals
    data_in.y       <= (others => '0');
    data_in.u       <= (others => '0');
    data_in.v       <= (others => '0');
    data_in.hsync_n <= '1';
    data_in.vsync_n <= '1';
    data_in.avid    <= '0';
    data_in.field_n <= '1';

    wait for 5 * C_CLK_PERIOD;

    while test_suite loop

      if run("test_active_video_passthrough") then
        info("Testing active video passes through unchanged");

        -- Send active video pixels
        send_pixel(200, 300, 400, '1');

        -- Check immediately after pipeline establishes (2 cycles from first pixel)
        wait for 1 * C_CLK_PERIOD + 1 ns;

        check_equal(unsigned(data_out.y), 200, "Active Y should pass through");
        check_equal(unsigned(data_out.u), 300, "Active U should pass through");
        check_equal(unsigned(data_out.v), 400, "Active V should pass through");
        check_equal(data_out.avid, '1', "AVID should pass through");

      elsif run("test_blanking_replacement") then
        info("Testing blanking pixels replaced with black");

        -- Send blanking pixels (AVID=0) with non-black values
        send_pixel(500, 600, 700, '0');

        -- Wait for pipeline delay
        wait for 2 * C_CLK_PERIOD + 1 ns;

        check_equal(unsigned(data_out.y), C_BLACK_Y, "Blanking Y should be 0");
        check_equal(unsigned(data_out.u), C_BLACK_U, "Blanking U should be 512");
        check_equal(unsigned(data_out.v), C_BLACK_V, "Blanking V should be 512");
        check_equal(data_out.avid, '0', "AVID should remain 0");

      elsif run("test_sync_passthrough") then
        info("Testing sync signals pass through unchanged");

        -- Send pixel with sync signals active
        send_pixel(100, 200, 300, '1', '0', '0', '0');

        wait for 2 * C_CLK_PERIOD + 1 ns;

        check_equal(data_out.hsync_n, '0', "HSYNC should pass through");
        check_equal(data_out.vsync_n, '0', "VSYNC should pass through");
        check_equal(data_out.field_n, '0', "Field should pass through");

      elsif run("test_transition_to_blanking") then
        info("Testing transition from active to blanking");

        -- Active video
        send_pixel(200, 300, 400, '1');

        -- Transition to blanking
        send_pixel(500, 600, 700, '0');

        wait for 3 * C_CLK_PERIOD + 1 ns;

        -- Output should be black
        check_equal(unsigned(data_out.y), C_BLACK_Y, "Should output black Y");
        check_equal(unsigned(data_out.u), C_BLACK_U, "Should output black U");
        check_equal(unsigned(data_out.v), C_BLACK_V, "Should output black V");

      elsif run("test_transition_to_active") then
        info("Testing transition from blanking to active");

        -- Blanking
        send_pixel(500, 600, 700, '0');

        -- Transition to active video
        send_pixel(200, 300, 400, '1');

        wait for 3 * C_CLK_PERIOD + 1 ns;

        -- Output should be active video data
        check_equal(unsigned(data_out.y), 200, "Should output active Y");
        check_equal(unsigned(data_out.u), 300, "Should output active U");
        check_equal(unsigned(data_out.v), 400, "Should output active V");
        check_equal(data_out.avid, '1', "AVID should be 1");

      elsif run("test_continuous_blanking") then
        info("Testing continuous blanking interval");

        -- Send multiple blanking pixels
        for i in 1 to 10 loop
          send_pixel(100*i, 200*i, 300*i, '0');
        end loop;

        -- All should be replaced with black
        wait for 1 ns;
        check_equal(unsigned(data_out.y), C_BLACK_Y, "Continuous blanking Y");
        check_equal(unsigned(data_out.u), C_BLACK_U, "Continuous blanking U");
        check_equal(unsigned(data_out.v), C_BLACK_V, "Continuous blanking V");

      end if;

    end loop;

    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 50 ms);

end architecture;
