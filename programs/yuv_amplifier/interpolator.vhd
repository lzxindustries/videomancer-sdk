-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: interpolator_u.vhd - Pipelined Unsigned Interpolator
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
--   4-Stage Pipelined Unsigned Interpolator
--
-- Authors: 
--   Lars Larsen
--
-- Overview:
--   This module implements a 4-stage pipelined linear interpolator for unsigned values.
--   It computes: result = a + (b - a) * t, where t is a normalized factor [0, 1].
--   The design handles signed arithmetic internally to correctly interpolate when b < a,
--   includes rounding for fractional scaling, and provides output clamping.
--
-- Algorithm:
--   Linear interpolation formula: result = a + (b - a) * t
--   Where:
--     a, b: Input values (unsigned endpoints)
--     t: Interpolation factor (0 = return a, max = return b)
--     result: Interpolated value between a and b
--
-- Pipeline Architecture (4 stages, 4 clock cycles latency):
--   Stage 0: Register inputs (a, b, t)
--   Stage 1: Compute signed difference (b - a), forward a and t
--   Stage 2: Multiply difference by t factor
--   Stage 3: Scale product, add back a, round, and clamp to output range
--
-- Generic Parameters:
--   G_WIDTH: Bit width of input/output data (typically 8 or 10)
--   G_FRAC_BITS: Fractional precision of t parameter (typically equals G_WIDTH)
--   G_OUTPUT_MIN: Minimum allowed output value (for clamping)
--   G_OUTPUT_MAX: Maximum allowed output value (for clamping)
--
-- Typical Usage:
--   For 10-bit video with t in range [0, 1023]:
--     G_WIDTH = 10, G_FRAC_BITS = 10
--     t = 0 gives result = a
--     t = 1023 gives result ≈ b
--     t = 512 gives result ≈ (a + b) / 2
--
-- Features:
--   - Signed arithmetic for correct handling of b < a
--   - Rounding when scaling down fractional bits
--   - Output clamping to specified range
--   - Valid signal pipeline for dataflow control

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity interpolator_u is
  generic (
    G_WIDTH      : integer := 8;
    G_FRAC_BITS  : integer := 8;
    G_OUTPUT_MIN : integer := 0;
    G_OUTPUT_MAX : integer := 255
  );
  port (
    clk    : in std_logic;
    enable : in std_logic;
    a      : in unsigned(G_WIDTH - 1 downto 0);
    b      : in unsigned(G_WIDTH - 1 downto 0);
    t      : in unsigned(G_FRAC_BITS - 1 downto 0);
    result : out unsigned(G_WIDTH - 1 downto 0);
    valid  : out std_logic
  );
end interpolator_u;

architecture rtl of interpolator_u is
  --------------------------------------------------------------------------------
  -- Constants
  --------------------------------------------------------------------------------
  constant C_DATA_WIDTH         : integer                        := G_WIDTH;
  constant C_DIFF_WIDTH         : integer                        := G_WIDTH + 1;  -- Extra bit for signed difference
  constant C_PRODUCT_WIDTH      : integer                        := C_DIFF_WIDTH + G_FRAC_BITS + 1;  -- Full product width
  constant C_PIPELINE_STAGES    : integer                        := 4;  -- Total pipeline depth
  constant C_OUTPUT_MIN         : unsigned(G_WIDTH - 1 downto 0) := to_unsigned(G_OUTPUT_MIN, G_WIDTH);
  constant C_OUTPUT_MAX         : unsigned(G_WIDTH - 1 downto 0) := to_unsigned(G_OUTPUT_MAX, G_WIDTH);

  --------------------------------------------------------------------------------
  -- Pipeline Stage 0: Input Registers
  --------------------------------------------------------------------------------
  signal s_a_0                  : unsigned(G_WIDTH - 1 downto 0);
  signal s_b_0                  : unsigned(G_WIDTH - 1 downto 0);
  signal s_t_0                  : unsigned(G_FRAC_BITS - 1 downto 0);
  
  --------------------------------------------------------------------------------
  -- Pipeline Stage 1: Difference Computation
  --------------------------------------------------------------------------------
  signal s_a_1                  : unsigned(G_WIDTH - 1 downto 0);  -- Delayed a
  signal s_t_1                  : unsigned(G_FRAC_BITS - 1 downto 0);  -- Delayed t
  signal s_diff                 : signed(C_DIFF_WIDTH - 1 downto 0);  -- Signed difference (b - a)
  
  --------------------------------------------------------------------------------
  -- Pipeline Stage 2: Multiplication
  --------------------------------------------------------------------------------
  signal s_a_2                  : unsigned(G_WIDTH - 1 downto 0);  -- Delayed a
  signal s_product              : signed(C_PRODUCT_WIDTH - 1 downto 0);  -- (b - a) * t
  
  --------------------------------------------------------------------------------
  -- Pipeline Stage 3: Scaling, Addition, and Clamping
  --------------------------------------------------------------------------------
  signal s_final_result         : unsigned(G_WIDTH - 1 downto 0);
  
  --------------------------------------------------------------------------------
  -- Valid Signal Pipeline
  --------------------------------------------------------------------------------
  signal s_valid_arr            : std_logic_vector(C_PIPELINE_STAGES - 1 downto 0) := (others => '0');

begin

  --------------------------------------------------------------------------------
  -- Stage 0: Input Registration
  -- Latency: 1 cycle
  -- Captures inputs when enable is high
  --------------------------------------------------------------------------------
  p_stage0_input : process (clk)
  begin
    if rising_edge(clk) then
      if enable = '1' then
        s_a_0 <= a;  -- Start point
        s_b_0 <= b;  -- End point
        s_t_0 <= t;  -- Interpolation factor
      end if;
    end if;
  end process p_stage0_input;

  --------------------------------------------------------------------------------
  -- Stage 1: Difference Computation
  -- Latency: 1 cycle
  -- Computes (b - a) using signed arithmetic to handle b < a
  -- Forwards a and t for later stages
  --------------------------------------------------------------------------------
  p_stage1_diff : process (clk)
  begin
    if rising_edge(clk) then
      -- Delay a and t through the pipeline
      s_a_1   <= s_a_0;
      s_t_1   <= s_t_0;
      
      -- Compute signed difference: diff = b - a
      -- Using signed arithmetic ensures correct result when b < a (negative difference)
      s_diff  <= signed(resize(s_b_0, C_DIFF_WIDTH)) - signed(resize(s_a_0, C_DIFF_WIDTH));
    end if;
  end process p_stage1_diff;

  --------------------------------------------------------------------------------
  -- Stage 2: Multiplication
  -- Latency: 1 cycle
  -- Computes product = (b - a) * t
  -- t is treated as unsigned, prepended with '0' for signed multiplication
  --------------------------------------------------------------------------------
  p_stage2_mult : process (clk)
  begin
    if rising_edge(clk) then
      -- Continue delaying a for final addition
      s_a_2     <= s_a_1;
      
      -- Multiply difference by interpolation factor
      -- Product = (b - a) * t, where t is in range [0, 2^G_FRAC_BITS - 1]
      s_product <= s_diff * signed('0' & s_t_1);
    end if;
  end process p_stage2_mult;

  --------------------------------------------------------------------------------
  -- Stage 3: Scaling, Addition, and Clamping
  -- Latency: 1 cycle
  -- Completes interpolation: result = a + (b - a) * t / 2^G_FRAC_BITS
  -- Includes rounding and output range clamping
  --------------------------------------------------------------------------------
  p_stage3_scale_add_clamp : process (clk)
    variable v_scaled    : signed(C_DIFF_WIDTH downto 0);  -- Scaled product
    variable v_added     : signed(G_WIDTH + 1 downto 0);   -- Final sum with extra bits
    variable v_round_bit : std_logic;                       -- Rounding bit
  begin
    if rising_edge(clk) then
      -- Step 1: Extract rounding bit (MSB of fractional part being discarded)
      -- This is the most significant bit that will be lost during scaling
      if G_FRAC_BITS > 0 then
        v_round_bit := s_product(G_FRAC_BITS - 1);
      else
        v_round_bit := '0';
      end if;
      
      -- Step 2: Scale product by removing fractional bits (divide by 2^G_FRAC_BITS)
      -- This converts from fixed-point back to integer representation
      v_scaled := s_product(C_PRODUCT_WIDTH - 1 downto G_FRAC_BITS);
      
      -- Step 3: Round to nearest (add 1 if rounding bit is set)
      if v_round_bit = '1' then
        v_scaled := v_scaled + 1;
      end if;
      
      -- Step 4: Add back the 'a' value to complete interpolation
      -- result = a + scaled_product = a + (b - a) * t / 2^G_FRAC_BITS
      v_added  := signed(resize(s_a_2, G_WIDTH + 2)) + resize(v_scaled, G_WIDTH + 2);

      -- Step 5: Clamp result to output range and convert back to unsigned
      if v_added < G_OUTPUT_MIN then
        s_final_result <= C_OUTPUT_MIN;  -- Clamp to minimum
      elsif v_added > G_OUTPUT_MAX then
        s_final_result <= C_OUTPUT_MAX;  -- Clamp to maximum
      else
        s_final_result <= unsigned(v_added(G_WIDTH - 1 downto 0));  -- Normal case
      end if;
    end if;
  end process p_stage3_scale_add_clamp;

  --------------------------------------------------------------------------------
  -- Valid Signal Pipeline
  -- Shifts valid signal through pipeline stages to track data flow
  --------------------------------------------------------------------------------
  p_valid_pipeline : process (clk)
  begin
    if rising_edge(clk) then
      -- Shift valid signals through the pipeline (oldest to newest)
      for i in s_valid_arr'high downto 1 loop
        s_valid_arr(i) <= s_valid_arr(i - 1);
      end loop;
      -- Input enable becomes the newest valid signal
      s_valid_arr(0) <= enable;
    end if;
  end process p_valid_pipeline;

  --------------------------------------------------------------------------------
  -- Output Assignments
  --------------------------------------------------------------------------------
  result <= s_final_result;
  valid  <= s_valid_arr(s_valid_arr'high);  -- Output valid after all stages

end rtl;
