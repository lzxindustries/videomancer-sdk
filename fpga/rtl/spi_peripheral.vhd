-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: spi_peripheral.vhd - SPI Peripheral Controller
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
--   SPI peripheral controller allows an external SPI host to read and write to
--   local data over a typical RAM access port interface.

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity spi_peripheral is
    generic (
        DATA_WIDTH : natural   := 8;
        ADDR_WIDTH : natural   := 7;
        CPOL       : std_logic := '0'; -- Clock polarity
        CPHA       : std_logic := '0'  -- Clock phase -- not entirely supported, only used to determine rising/falling edge
    );
    port (
        clk   : in std_logic;
        sck   : in std_logic;
        sdi   : in std_logic;
        sdo   : inout std_logic;
        cs_n  : in std_logic;
        din   : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        dout  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        wr_en : out std_logic;
        rd_en : out std_logic;
        addr  : out unsigned(ADDR_WIDTH - 1 downto 0)
    );

end entity;

architecture rtl of spi_peripheral is
    signal s_sck_d     : std_logic := '0';
    signal s_sdi_d     : std_logic := '0';
    signal s_cs_n_d    : std_logic := '0';
    signal s_sck       : std_logic := '0';
    signal s_sdi       : std_logic := '0';
    signal s_cs_n      : std_logic := '0';
    signal s_input_en  : std_logic := '0';
    signal s_output_en : std_logic := '0';
    signal s_stop      : std_logic := '0';
    signal s_start     : std_logic := '0';
    signal s_sdo_state : std_logic := '0';
    signal s_sdo_en    : std_logic := '0';

    type t_state is (IDLE, RECEIVING_ADDRESS, RECEIVING_COMMAND, RECEIVING_DATA, REQUESTING_WRITE, WAITING_WRITE, REQUESTING_READ, WAITING_READ, SENDING_DATA);
    signal s_state     : t_state                                   := IDLE;
    signal s_bit_count : unsigned(DATA_WIDTH - 1 downto 0)         := (others => '0');
    signal s_addr_buf  : unsigned(ADDR_WIDTH - 1 downto 0)         := (others => '0');
    signal s_data_buf  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Pre-computed signals for critical path optimization
    signal s_output_en_reg : std_logic := '0';
    signal s_input_en_reg  : std_logic := '0';
    signal s_stop_reg      : std_logic := '0';
    signal s_start_reg     : std_logic := '0';
    signal s_last_addr_bit : std_logic := '0';  -- Pre-computed s_bit_count = ADDR_WIDTH - 1
    signal s_last_data_bit : std_logic := '0';  -- Pre-computed s_bit_count = DATA_WIDTH - 1

begin
    u_sync_to_clk_sdi  : entity work.sync_slv port map(clk => clk, a(0) => sdi, b(0) => s_sdi);
    u_sync_to_clk_sck  : entity work.sync_slv port map(clk => clk, a(0) => sck, b(0) => s_sck);
    u_sync_to_clk_cs_n : entity work.sync_slv port map(clk => clk, a(0) => cs_n, b(0) => s_cs_n);

    sdo <= 'Z' when s_sdo_en = '0' else
        s_sdo_state;

    -- Pre-compute edge detections and delays
    edge_detection : process (clk)
    begin
        if rising_edge(clk) then
            s_sck_d  <= s_sck;
            s_cs_n_d <= s_cs_n;
            s_sdi_d  <= s_sdi;

            -- Register edge detections to break critical path
            s_output_en_reg <= '1' when (s_sck xor CPOL xor CPHA) = '1' and (s_sck_d xor CPOL xor CPHA) = '0' else '0';
            s_input_en_reg  <= '1' when (s_sck xor CPOL xor CPHA) = '0' and (s_sck_d xor CPOL xor CPHA) = '1' else '0';
            s_stop_reg      <= '1' when s_cs_n = '1' and s_cs_n_d = '0' else '0';
            s_start_reg     <= '1' when s_cs_n = '0' and s_cs_n_d = '1' else '0';

            -- Pre-compute bit count comparisons (breaks critical path)
            s_last_addr_bit <= '1' when s_bit_count = (ADDR_WIDTH - 1) else '0';
            s_last_data_bit <= '1' when s_bit_count = (DATA_WIDTH - 1) else '0';
        end if;
    end process;

    -- Combinatorial versions for compatibility
    s_output_en <= '1' when (s_sck xor CPOL xor CPHA) = '1' and (s_sck_d xor CPOL xor CPHA) = '0' else
        '0'; -- rising edge
    s_input_en <= '1' when (s_sck xor CPOL xor CPHA) = '0' and (s_sck_d xor CPOL xor CPHA) = '1' else
        '0'; -- falling edge

    s_stop <= '1' when s_cs_n = '1' and s_cs_n_d = '0' else
        '0';
    s_start <= '1' when s_cs_n = '0' and s_cs_n_d = '1' else
        '0';

    -- Main state machine with optimized critical path
    process (clk)
    begin
        if rising_edge(clk) then
            wr_en <= '0';
            rd_en <= '0';

            -- Priority: stop/start first (highest priority)
            if s_stop_reg = '1' then
                s_sdo_en <= '0';
                s_state  <= IDLE;
            elsif s_start_reg = '1' then
                s_sdo_state <= '0';
                s_sdo_en    <= '1';
                s_addr_buf  <= to_unsigned(0, ADDR_WIDTH);
                s_bit_count <= to_unsigned(0, DATA_WIDTH);
                s_data_buf  <= (others => '0');
                s_state     <= RECEIVING_ADDRESS;
            else
                -- State-based logic (use case statement for better synthesis)
                case s_state is
                    when REQUESTING_READ =>
                        s_state <= WAITING_READ;

                    when WAITING_READ =>
                        s_data_buf <= din;
                        s_state    <= SENDING_DATA;

                    when REQUESTING_WRITE =>
                        dout        <= s_data_buf;
                        wr_en       <= '1';
                        s_bit_count <= to_unsigned(0, DATA_WIDTH);
                        s_state     <= WAITING_WRITE;

                    when WAITING_WRITE =>
                        s_state <= IDLE;

                    when RECEIVING_ADDRESS =>
                        if s_input_en_reg = '1' then
                            s_addr_buf(ADDR_WIDTH - 1 - to_integer(s_bit_count)) <= s_sdi;
                            if s_last_addr_bit = '1' then
                                s_bit_count <= to_unsigned(0, DATA_WIDTH);
                                s_state     <= RECEIVING_COMMAND;
                            else
                                s_bit_count <= s_bit_count + to_unsigned(1, DATA_WIDTH);
                            end if;
                        end if;

                    when RECEIVING_COMMAND =>
                        if s_input_en_reg = '1' then
                            addr  <= s_addr_buf;
                            rd_en <= '1';
                            if s_sdi = '1' then
                                s_state <= RECEIVING_DATA;
                            else
                                s_state <= REQUESTING_READ;
                            end if;
                        end if;

                    when RECEIVING_DATA =>
                        if s_input_en_reg = '1' then
                            s_data_buf(DATA_WIDTH - 1 - to_integer(s_bit_count)) <= s_sdi;
                            if s_last_data_bit = '1' then
                                s_state <= REQUESTING_WRITE;
                            else
                                s_bit_count <= s_bit_count + to_unsigned(1, DATA_WIDTH);
                            end if;
                        end if;

                    when SENDING_DATA =>
                        if s_output_en_reg = '1' then
                            s_sdo_state <= s_data_buf(DATA_WIDTH - 1 - to_integer(s_bit_count));
                            if s_last_data_bit = '1' then
                                s_state <= IDLE;
                            else
                                s_bit_count <= s_bit_count + to_unsigned(1, DATA_WIDTH);
                            end if;
                        end if;

                    when others => -- IDLE
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture;
