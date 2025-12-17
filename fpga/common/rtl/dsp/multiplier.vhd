-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: multiplier_s.vhd - Pipelined Radix-4 Booth Multiplier with Signed Inputs
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
--   Pipelined signed multiplier using Radix-4 Booth encoding
--
-- Authors:
--   Ed Leckie & Lars Larsen
--
-- Overview:
--   This module implements a high-performance pipelined signed multiplier using
--   Radix-4 Booth encoding algorithm. It computes: result = (x * y) + z, where
--   all operands are signed fixed-point numbers. The design processes 2 bits per
--   clock cycle, providing efficient resource utilization and high throughput.
--
-- Algorithm:
--   Radix-4 Booth Multiplication with accumulator:
--     result = (x * y) / 2^G_FRAC_BITS + z
--
--   Radix-4 Booth encoding examines 3 bits at a time (current, previous, and
--   next bit) to determine the partial product: -2x, -x, 0, +x, or +2x.
--   This reduces the number of additions from N to N/2 compared to standard
--   shift-and-add multiplication.
--
-- Pipeline Architecture:
--   - Input registration stage
--   - N/2 multiplication stages (where N = G_WIDTH), processing 2 bits per stage
--   - Output scaling, addition of z, and clamping stage
--   - Valid signal pipeline tracking dataflow
--
-- Generic Parameters:
--   G_WIDTH: Bit width of input/output data (signed)
--   G_FRAC_BITS: Number of fractional bits in fixed-point representation
--   G_OUTPUT_MIN: Minimum allowed output value (for clamping)
--   G_OUTPUT_MAX: Maximum allowed output value (for clamping)
--
-- Fixed-Point Representation:
--   For G_WIDTH=10, G_FRAC_BITS=9:
--     - Input range: -512 to +511 (signed)
--     - Fixed-point range: -1.0 to +0.998 (approximately -1 to +1)
--     - 1.0 is represented as 512 (2^9)
--
-- Features:
--   - Radix-4 Booth encoding for efficient multiplication
--   - Pipelined for high throughput (one result per clock)
--   - Integrated accumulator (adds z to product)
--   - Fixed-point scaling with fractional bit handling
--   - Output clamping to specified range
--   - Valid signal pipeline for dataflow control

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multiplier_s is
  generic (
    G_WIDTH      : integer := 8;
    G_FRAC_BITS  : integer := 7;
    G_OUTPUT_MIN : integer := - 128;
    G_OUTPUT_MAX : integer := 127
  );
  port (
    clk    : in std_logic;
    enable : in std_logic;
    x      : in signed(G_WIDTH - 1 downto 0);
    y      : in signed(G_WIDTH - 1 downto 0);
    z      : in signed(G_WIDTH - 1 downto 0);
    result : out signed(G_WIDTH - 1 downto 0);
    valid  : out std_logic
  );
end multiplier_s;

architecture rtl of multiplier_s is
  --------------------------------------------------------------------------------
  -- Constants
  --------------------------------------------------------------------------------
  constant C_DATA_WIDTH         : integer                      := G_WIDTH;
  constant C_PRODUCT_WIDTH      : integer                      := 2 * C_DATA_WIDTH;  -- Full product width
  constant C_MULTIPLIER_STAGES  : integer                      := (C_DATA_WIDTH + 1) / 2;  -- Radix-4: 2 bits/stage
  constant C_Z_DELAY_STAGES     : integer                      := C_MULTIPLIER_STAGES + 1;  -- Match multiplication latency
  constant C_VALID_DELAY_STAGES : integer                      := C_MULTIPLIER_STAGES;  -- Valid pipeline depth
  constant C_OUTPUT_MIN         : signed(G_WIDTH - 1 downto 0) := to_signed(G_OUTPUT_MIN, G_WIDTH);
  constant C_OUTPUT_MAX         : signed(G_WIDTH - 1 downto 0) := to_signed(G_OUTPUT_MAX, G_WIDTH);

  --------------------------------------------------------------------------------
  -- Input Registers
  --------------------------------------------------------------------------------
  signal s_x                    : signed(C_DATA_WIDTH - 1 downto 0);  -- Multiplicand
  signal s_y                    : signed(C_DATA_WIDTH - 1 downto 0);  -- Multiplier
  signal s_z                    : signed(C_DATA_WIDTH - 1 downto 0);  -- Accumulator addend
  signal s_enable               : std_logic;
  signal s_valid                : std_logic;

  --------------------------------------------------------------------------------
  -- Array Type Declarations
  --------------------------------------------------------------------------------
  -- Multiplier array: Holds partial products at each Booth stage
  type t_multiplier_arr is array (integer range <>) of signed(C_PRODUCT_WIDTH downto 0);
  -- Multiplicand array: Shifts through pipeline for Booth encoding
  type t_multiplicand_arr is array (integer range <>) of signed(C_DATA_WIDTH - 1 downto 0);
  -- Z delay array: Delays z through pipeline to match multiplication latency
  type t_z_arr is array (integer range <>) of signed(C_DATA_WIDTH - 1 downto 0);

  --------------------------------------------------------------------------------
  -- Pipeline Signals
  --------------------------------------------------------------------------------
  signal s_multiplier_arr   : t_multiplier_arr(0 to C_MULTIPLIER_STAGES);      -- Booth partial products
  signal s_multiplicand_arr : t_multiplicand_arr(0 to C_MULTIPLIER_STAGES);    -- Delayed multiplicand
  signal s_z_arr            : t_z_arr(0 to C_Z_DELAY_STAGES - 1);              -- Delayed z
  signal s_valid_arr        : std_logic_vector(C_VALID_DELAY_STAGES - 1 downto 0) := (others => '0');
  signal s_scaled_result    : signed(C_PRODUCT_WIDTH - G_FRAC_BITS - 1 downto 0)  := (others => '0');
  signal s_final_result     : signed(G_WIDTH - 1 downto 0)                        := (others => '0');

begin

  --------------------------------------------------------------------------------
  -- Input Registration
  -- Captures all inputs on rising clock edge
  --------------------------------------------------------------------------------
  p_input_reg : process (clk)
  begin
    if rising_edge(clk) then
      s_x      <= x;       -- Multiplicand
      s_y      <= y;       -- Multiplier
      s_z      <= z;       -- Accumulator addend
      s_enable <= enable;  -- Pipeline enable
    end if;
  end process p_input_reg;

  --------------------------------------------------------------------------------
  -- Radix-4 Booth Multiplication Pipeline
  -- Processes 2 bits of multiplier per stage using Booth encoding
  --
  -- Booth encoding rules for 3-bit groups (examining bits i+1, i, i-1):
  --   000, 111: Add 0 (no operation)
  --   001, 010: Add +1x multiplicand
  --   011:      Add +2x multiplicand (shift left)
  --   100:      Add -2x multiplicand (shift left and negate)
  --   101, 110: Add -1x multiplicand (negate)
  --------------------------------------------------------------------------------
  p_booth_multiply : process (clk)
    variable v_sel : signed(2 downto 0);  -- 3-bit Booth selector
  begin
    if rising_edge(clk) then
      -- Shift multiplicand through pipeline for parallel Booth stages
      s_multiplicand_arr <= s_x & s_multiplicand_arr(0 to s_multiplicand_arr'high - 1);

      -- Initialize first multiplier stage with y in lower bits
      s_multiplier_arr(0)                        <= (others => '0');
      s_multiplier_arr(0)(C_DATA_WIDTH downto 1) <= s_y;

      -- Process each Booth stage (handles 2 bits per iteration)
      for i in 0 to C_MULTIPLIER_STAGES - 1 loop
        -- Extract 3-bit Booth selector (current, previous, and implicit next bit)
        v_sel := s_multiplier_arr(i)(2 downto 0);

        -- Apply Booth encoding rule
        case v_sel is
          -- Add +1x multiplicand
          when "001" | "010" =>
            s_multiplier_arr(i + 1) <= (resize(s_multiplier_arr(i)(C_PRODUCT_WIDTH downto C_DATA_WIDTH + 1), C_DATA_WIDTH + 2) + s_multiplicand_arr(i)) & s_multiplier_arr(i)(C_DATA_WIDTH downto 2);

          -- Add +2x multiplicand (shift left = multiply by 2)
          when "011" =>
            s_multiplier_arr(i + 1) <= (resize(s_multiplier_arr(i)(C_PRODUCT_WIDTH downto C_DATA_WIDTH + 1), C_DATA_WIDTH + 2) + shift_left(resize(s_multiplicand_arr(i), C_DATA_WIDTH + 1), 1)) & s_multiplier_arr(i)(C_DATA_WIDTH downto 2);

          -- Add -2x multiplicand (shift left and negate)
          when "100" =>
            s_multiplier_arr(i + 1) <= (resize(s_multiplier_arr(i)(C_PRODUCT_WIDTH downto C_DATA_WIDTH + 1), C_DATA_WIDTH + 2) - shift_left(resize(s_multiplicand_arr(i), C_DATA_WIDTH + 1), 1)) & s_multiplier_arr(i)(C_DATA_WIDTH downto 2);

          -- Add -1x multiplicand (negate)
          when "101" | "110" =>
            s_multiplier_arr(i + 1) <= (resize(s_multiplier_arr(i)(C_PRODUCT_WIDTH downto C_DATA_WIDTH + 1), C_DATA_WIDTH + 2) - s_multiplicand_arr(i)) & s_multiplier_arr(i)(C_DATA_WIDTH downto 2);

          -- Add 0 (no operation, just shift)
          when others =>
            s_multiplier_arr(i + 1) <= shift_right(s_multiplier_arr(i), 2);
        end case;
      end loop;
    end if;
  end process p_booth_multiply;

  --------------------------------------------------------------------------------
  -- Delay Pipelines for Valid Signal and Accumulator (z)
  -- Delays valid and z signals to match multiplication pipeline latency
  --------------------------------------------------------------------------------
  p_delay_pipelines : process (clk)
  begin
    if rising_edge(clk) then
      -- Shift valid signal through pipeline
      for i in s_valid_arr'high downto 1 loop
        s_valid_arr(i) <= s_valid_arr(i - 1);
      end loop;
      s_valid_arr(0) <= s_enable;

      -- Shift z (accumulator addend) through pipeline
      -- z must be delayed to match when the product is ready
      for i in s_z_arr'high downto 1 loop
        s_z_arr(i) <= s_z_arr(i - 1);
      end loop;
      s_z_arr(0) <= s_z;
    end if;
  end process p_delay_pipelines;

  --------------------------------------------------------------------------------
  -- Output Stage: Scaling, Addition, and Clamping
  -- Completes the operation: result = (x * y) / 2^G_FRAC_BITS + z
  -- Includes fixed-point scaling and output range clamping
  --------------------------------------------------------------------------------
  p_output_stage : process (clk)
    variable v_scaled : signed(C_PRODUCT_WIDTH - G_FRAC_BITS - 1 downto 0);  -- Scaled product
    variable v_added  : signed(G_WIDTH downto 0);  -- Sum with extra bit
  begin
    if rising_edge(clk) then
      -- Step 1: Scale product by removing fractional bits (divide by 2^G_FRAC_BITS)
      -- This converts from fixed-point product back to fixed-point result
      v_scaled := s_multiplier_arr(C_MULTIPLIER_STAGES)(C_PRODUCT_WIDTH downto G_FRAC_BITS + 1);

      -- Step 2: Add z (accumulator) to scaled product
      v_added  := resize(v_scaled, G_WIDTH + 1) + resize(s_z_arr(s_z_arr'high), G_WIDTH + 1);

      -- Step 3: Clamp result to output range
      if v_added < G_OUTPUT_MIN then
        s_final_result <= C_OUTPUT_MIN;  -- Clamp to minimum
      elsif v_added > G_OUTPUT_MAX then
        s_final_result <= C_OUTPUT_MAX;  -- Clamp to maximum
      else
        s_final_result <= resize(v_added, G_WIDTH);  -- Normal case
      end if;

      -- Output delayed valid signal
      s_valid <= s_valid_arr(s_valid_arr'high);
    end if;
  end process p_output_stage;

  --------------------------------------------------------------------------------
  -- Output Assignments
  --------------------------------------------------------------------------------
  result <= s_final_result;
  valid  <= s_valid;

end rtl;
