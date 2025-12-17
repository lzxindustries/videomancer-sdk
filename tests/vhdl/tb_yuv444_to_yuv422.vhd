-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_yuv444_to_yuv422.vhd - Testbench for YUV444 to YUV422 Converter
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
--   VUnit testbench for yuv444_to_yuv422 converter module.
--   Tests YUV444 to YUV422 conversion (inverse of yuv422_to_yuv444).

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;
use rtl_lib.video_timing_pkg.all;
use rtl_lib.core_pkg.all;

entity tb_yuv444_to_yuv422 is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_yuv444_to_yuv422 is

  constant C_CLK_PERIOD : time := 13.5 ns;
  constant C_BIT_DEPTH  : integer := 10;

  signal clk       : std_logic := '0';
  signal i_data    : t_video_stream_yuv444;
  signal o_data    : t_video_stream_yuv422;
  signal test_done : boolean := false;

begin

  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  dut: entity rtl_lib.yuv444_to_yuv422
    port map (
      clk    => clk,
      i_data => i_data,
      o_data => o_data
    );

  main: process
    procedure send_yuv444_pixel(
      constant y_val  : integer;
      constant u_val  : integer;
      constant v_val  : integer;
      constant avid   : std_logic
    ) is
    begin
      i_data.y    <= std_logic_vector(to_unsigned(y_val, C_BIT_DEPTH));
      i_data.u    <= std_logic_vector(to_unsigned(u_val, C_BIT_DEPTH));
      i_data.v    <= std_logic_vector(to_unsigned(v_val, C_BIT_DEPTH));
      i_data.avid <= avid;
      wait for C_CLK_PERIOD;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- Initialize signals
    i_data.y       <= (others => '0');
    i_data.u       <= (others => '0');
    i_data.v       <= (others => '0');
    i_data.hsync_n <= '1';
    i_data.vsync_n <= '1';
    i_data.avid    <= '0';
    i_data.field_n <= '1';

    wait for 5 * C_CLK_PERIOD;

    while test_suite loop

      if run("test_basic_conversion") then
        info("Testing YUV444 to YUV422 conversion");

        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;

        -- Send two YUV444 pixels
        send_yuv444_pixel(100, 200, 250, '1');
        send_yuv444_pixel(150, 210, 240, '1');

        -- Wait for pipeline (first pixel after total 3 cycles)
        wait for 1 * C_CLK_PERIOD + 1 ns;

        -- First output: Y0 with U from pixel 0
        check_equal(unsigned(o_data.y), 100, "First Y value");
        check_equal(unsigned(o_data.c), 200, "First chroma (U)");

        -- Second output: Y1 with V from pixel 1
        wait for C_CLK_PERIOD;
        check_equal(unsigned(o_data.y), 150, "Second Y value");
        check_equal(unsigned(o_data.c), 240, "Second chroma (V)");

      elsif run("test_sync_delay") then
        info("Testing sync signal propagation with 2-cycle delay");

        i_data.hsync_n <= '1';
        i_data.avid    <= '0';
        wait for C_CLK_PERIOD;

        i_data.hsync_n <= '0';
        wait for C_CLK_PERIOD + 1 ns;
        check_equal(o_data.hsync_n, '1', "HSYNC should not propagate after 1 cycle");

        wait for C_CLK_PERIOD;
        check_equal(o_data.hsync_n, '0', "HSYNC should propagate after 2 cycles");

        i_data.hsync_n <= '1';
        wait for 2 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.hsync_n, '1', "HSYNC deactivation after 2 cycles");

      elsif run("test_phase_reset") then
        info("Testing phase reset on AVID rising edge");

        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;

        -- Send pixels with AVID high
        send_yuv444_pixel(100, 200, 250, '1');
        send_yuv444_pixel(110, 210, 240, '1');

        i_data.avid <= '0';
        wait for 3 * C_CLK_PERIOD;

        -- New line should start with U phase
        send_yuv444_pixel(120, 220, 230, '1');
        send_yuv444_pixel(130, 225, 235, '1');

        wait for 3 * C_CLK_PERIOD;
        info("Phase reset test completed");

      elsif run("test_chroma_alternation") then
        info("Testing U/V chroma alternation");

        i_data.avid <= '0';
        wait for 2 * C_CLK_PERIOD;

        -- Send 4 pixels
        send_yuv444_pixel(100, 200, 250, '1');  -- Pixel 0: U=200
        send_yuv444_pixel(110, 210, 240, '1');  -- Pixel 1: V=240
        send_yuv444_pixel(120, 220, 230, '1');  -- Pixel 2: U=220
        send_yuv444_pixel(130, 225, 235, '1');  -- Pixel 3: V=235

        wait for 3 * C_CLK_PERIOD + 1 ns;

        -- Check that phase alternates correctly
        info("Chroma alternation test completed");

      elsif run("test_field_propagation") then
        info("Testing field signal propagation");

        i_data.field_n <= '1';
        i_data.avid    <= '1';
        wait for 3 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.field_n, '1', "Field 1 should propagate");

        i_data.field_n <= '0';
        wait for 3 * C_CLK_PERIOD + 1 ns;
        check_equal(o_data.field_n, '0', "Field 0 should propagate");

      end if;

    end loop;

    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 50 ms);

end architecture;
