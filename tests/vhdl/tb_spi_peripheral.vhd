-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: tb_spi_peripheral.vhd - Testbench for SPI Peripheral Controller
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
--   VUnit testbench for spi_peripheral module.
--   Tests SPI read/write operations, state machine transitions, and edge cases.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library rtl_lib;

entity tb_spi_peripheral is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_spi_peripheral is

  -- Clock periods
  constant C_CLK_PERIOD : time := 10 ns;
  constant C_SCK_PERIOD : time := 100 ns;
  
  -- Configuration constants
  constant C_DATA_WIDTH : natural := 8;
  constant C_ADDR_WIDTH : natural := 7;
  constant C_CPOL       : std_logic := '0';
  constant C_CPHA       : std_logic := '1';
  
  -- DUT signals
  signal clk     : std_logic := '0';
  signal sck     : std_logic := '0';
  signal sdi     : std_logic := '0';
  signal sdo     : std_logic := 'Z';
  signal cs_n    : std_logic := '1';
  signal din     : std_logic_vector(C_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal dout    : std_logic_vector(C_DATA_WIDTH - 1 downto 0);
  signal wr_en   : std_logic;
  signal rd_en   : std_logic;
  signal addr    : unsigned(C_ADDR_WIDTH - 1 downto 0);
  
  -- Test control
  signal test_done : boolean := false;
  
  -- Memory model for testing
  type t_memory is array (0 to 2**C_ADDR_WIDTH - 1) of std_logic_vector(C_DATA_WIDTH - 1 downto 0);
  signal memory : t_memory := (others => (others => '0'));

begin

  -- Clock generation
  clk <= not clk after C_CLK_PERIOD/2 when not test_done;

  -- Device Under Test
  dut: entity rtl_lib.spi_peripheral
    generic map (
      DATA_WIDTH => C_DATA_WIDTH,
      ADDR_WIDTH => C_ADDR_WIDTH,
      CPOL       => C_CPOL,
      CPHA       => C_CPHA
    )
    port map (
      clk   => clk,
      sck   => sck,
      sdi   => sdi,
      sdo   => sdo,
      cs_n  => cs_n,
      din   => din,
      dout  => dout,
      wr_en => wr_en,
      rd_en => rd_en,
      addr  => addr
    );

  -- Memory model process (responds to read/write requests)
  memory_model: process(clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        memory(to_integer(addr)) <= dout;
      end if;
      if rd_en = '1' then
        din <= memory(to_integer(addr));
      end if;
    end if;
  end process;

  -- Main test process
  main: process
    variable read_data : std_logic_vector(C_DATA_WIDTH - 1 downto 0);
    
    -- SPI transaction procedures
    procedure spi_write_byte(
      constant byte_val : in std_logic_vector(7 downto 0);
      signal sck_sig    : out std_logic;
      signal sdi_sig    : out std_logic
    ) is
    begin
      for i in 7 downto 0 loop
        sdi_sig <= byte_val(i);
        wait for C_SCK_PERIOD/2;
        sck_sig <= '1';
        wait for C_SCK_PERIOD/2;
        sck_sig <= '0';
      end loop;
    end procedure;

    procedure spi_read_byte(
      variable byte_val : out std_logic_vector(7 downto 0);
      signal sck_sig    : out std_logic;
      signal sdo_sig    : in std_logic
    ) is
    begin
      for i in 7 downto 0 loop
        wait for C_SCK_PERIOD/2;
        sck_sig <= '1';
        wait for C_SCK_PERIOD/4;
        byte_val(i) := sdo_sig;
        wait for C_SCK_PERIOD/4;
        sck_sig <= '0';
      end loop;
    end procedure;

    procedure spi_transaction_write(
      constant address  : in unsigned(C_ADDR_WIDTH - 1 downto 0);
      constant data     : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
      signal cs_sig     : out std_logic;
      signal sck_sig    : out std_logic;
      signal sdi_sig    : out std_logic
    ) is
      variable addr_byte : std_logic_vector(C_ADDR_WIDTH - 1 downto 0);
    begin
      addr_byte := std_logic_vector(address);
      
      -- Assert CS
      cs_sig <= '0';
      wait for C_SCK_PERIOD;
      
      -- Send address (7 bits)
      for i in C_ADDR_WIDTH - 1 downto 0 loop
        sdi_sig <= addr_byte(i);
        wait for C_SCK_PERIOD/2;
        sck_sig <= '1';
        wait for C_SCK_PERIOD/2;
        sck_sig <= '0';
      end loop;
      
      -- Send write command (1 bit, '1' for write)
      sdi_sig <= '1';
      wait for C_SCK_PERIOD/2;
      sck_sig <= '1';
      wait for C_SCK_PERIOD/2;
      sck_sig <= '0';
      
      -- Send data (8 bits)
      spi_write_byte(data, sck_sig, sdi_sig);
      
      -- Deassert CS
      wait for C_SCK_PERIOD;
      cs_sig <= '1';
      -- Wait for internal state machine to complete write (several clock cycles needed)
      wait for C_CLK_PERIOD * 20;
    end procedure;

    procedure spi_transaction_read(
      constant address  : in unsigned(C_ADDR_WIDTH - 1 downto 0);
      variable data     : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
      signal cs_sig     : out std_logic;
      signal sck_sig    : out std_logic;
      signal sdi_sig    : out std_logic;
      signal sdo_sig    : in std_logic
    ) is
      variable addr_byte : std_logic_vector(C_ADDR_WIDTH - 1 downto 0);
    begin
      addr_byte := std_logic_vector(address);
      
      -- Assert CS
      cs_sig <= '0';
      wait for C_SCK_PERIOD;
      
      -- Send address (7 bits)
      for i in C_ADDR_WIDTH - 1 downto 0 loop
        sdi_sig <= addr_byte(i);
        wait for C_SCK_PERIOD/2;
        sck_sig <= '1';
        wait for C_SCK_PERIOD/2;
        sck_sig <= '0';
      end loop;
      
      -- Send read command (1 bit, '0' for read)
      sdi_sig <= '0';
      wait for C_SCK_PERIOD/2;
      sck_sig <= '1';
      wait for C_SCK_PERIOD/2;
      sck_sig <= '0';
      
      -- Read data (8 bits)
      spi_read_byte(data, sck_sig, sdo_sig);
      
      -- Deassert CS
      wait for C_SCK_PERIOD;
      cs_sig <= '1';
      wait for C_SCK_PERIOD * 2;
    end procedure;
    
  begin
    test_runner_setup(runner, runner_cfg);
    
    while test_suite loop
      
      -- Initialize
      cs_n <= '1';
      sck <= '0';
      sdi <= '0';
      wait for 10 * C_CLK_PERIOD;
      
      -- Test 1: Basic write operation
      if run("test_spi_write") then
        info("Testing SPI write operation");
        
        -- Write value 0xA5 to address 0x10
        spi_transaction_write(
          address => to_unsigned(16#10#, C_ADDR_WIDTH),
          data    => x"A5",
          cs_sig  => cs_n,
          sck_sig => sck,
          sdi_sig => sdi
        );
        
        -- Wait for memory model to update
        wait for C_CLK_PERIOD * 5;
        
        -- Verify memory was written
        check_equal(memory(16#10#), std_logic_vector'(x"A5"),
                   "Memory should contain written value");
      
      -- Test 2: Multiple consecutive writes
      elsif run("test_multiple_writes") then
        info("Testing multiple consecutive SPI writes");
        
        -- Write multiple values
        for i in 0 to 15 loop
          spi_transaction_write(
            address => to_unsigned(i, C_ADDR_WIDTH),
            data    => std_logic_vector(to_unsigned(i * 16, C_DATA_WIDTH)),
            cs_sig  => cs_n,
            sck_sig => sck,
            sdi_sig => sdi
          );
        end loop;
        
        -- Verify all values were written
        for i in 0 to 15 loop
          check_equal(memory(i), std_logic_vector(to_unsigned(i * 16, C_DATA_WIDTH)),
                     "Memory location " & integer'image(i) & " should contain correct value");
        end loop;
      
      -- Test 3: CS deassertion during transaction (abort test)
      elsif run("test_cs_abort") then
        info("Testing transaction abort with CS deassertion");
        
        -- Start a write transaction but abort it
        cs_n <= '0';
        wait for C_SCK_PERIOD;
        
        -- Send partial address
        for i in C_ADDR_WIDTH - 1 downto C_ADDR_WIDTH - 3 loop
          sdi <= '1';
          wait for C_SCK_PERIOD/2;
          sck <= '1';
          wait for C_SCK_PERIOD/2;
          sck <= '0';
        end loop;
        
        -- Abort by deasserting CS
        cs_n <= '1';
        wait for C_SCK_PERIOD * 4;
        
        -- Verify no write occurred (wr_en should not have been asserted)
        check(wr_en = '0', "Write enable should not be asserted after abort");
      
      -- Test 4: Different address patterns
      elsif run("test_address_patterns") then
        info("Testing various address patterns");
        
        -- Test addresses with different bit patterns
        spi_transaction_write(to_unsigned(16#00#, C_ADDR_WIDTH), x"01", cs_n, sck, sdi);
        spi_transaction_write(to_unsigned(16#7F#, C_ADDR_WIDTH), x"02", cs_n, sck, sdi);
        spi_transaction_write(to_unsigned(16#55#, C_ADDR_WIDTH), x"03", cs_n, sck, sdi);
        spi_transaction_write(to_unsigned(16#2A#, C_ADDR_WIDTH), x"04", cs_n, sck, sdi);
        
        check_equal(memory(16#00#), std_logic_vector'(x"01"), "Address 0x00 check");
        check_equal(memory(16#7F#), std_logic_vector'(x"02"), "Address 0x7F check");
        check_equal(memory(16#55#), std_logic_vector'(x"03"), "Address 0x55 check");
        check_equal(memory(16#2A#), std_logic_vector'(x"04"), "Address 0x2A check");
      
      -- Test 5: Data patterns
      elsif run("test_data_patterns") then
        info("Testing various data patterns");
        
        -- Test different data patterns at a fixed address
        spi_transaction_write(to_unsigned(16#40#, C_ADDR_WIDTH), x"00", cs_n, sck, sdi);
        check_equal(memory(16#40#), std_logic_vector'(x"00"), "Data 0x00");
        
        spi_transaction_write(to_unsigned(16#40#, C_ADDR_WIDTH), x"FF", cs_n, sck, sdi);
        check_equal(memory(16#40#), std_logic_vector'(x"FF"), "Data 0xFF");
        
        spi_transaction_write(to_unsigned(16#40#, C_ADDR_WIDTH), x"AA", cs_n, sck, sdi);
        check_equal(memory(16#40#), std_logic_vector'(x"AA"), "Data 0xAA");
        
        spi_transaction_write(to_unsigned(16#40#, C_ADDR_WIDTH), x"55", cs_n, sck, sdi);
        check_equal(memory(16#40#), std_logic_vector'(x"55"), "Data 0x55");
        
      end if;
      
    end loop;
    
    test_done <= true;
    test_runner_cleanup(runner);
  end process;

  -- Watchdog to prevent infinite simulation
  test_runner_watchdog(runner, 100 ms);

end architecture;
