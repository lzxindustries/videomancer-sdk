-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: proc_amp_u.vhd - Contrast and Brightness Adjustment for Unsigned Values
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
--   Processing amplifier for unsigned video streams
--
-- Author: 
--   Lars Larsen
--
-- Overview:
--   This module implements a video process amplifier (proc amp) that applies
--   contrast and brightness adjustments to unsigned video signals. It centers
--   the input around 0.5, applies contrast multiplication, and then adds
--   brightness offset. The design uses a signed multiplier internally for
--   accurate fixed-point arithmetic.
--
-- Algorithm:
--   Two-step processing:
--     1. Contrast: Multiply centered input by contrast factor
--     2. Brightness: Add brightness offset to result
--   
--   Mathematical formula:
--     result = (input - 0.5) * contrast + brightness
--   
--   Where:
--     input:      Unsigned video value [0, 1] normalized
--     contrast:   Multiplication factor [0, 2] where 1.0 = unity
--     brightness: Offset value [-0.5, +0.5] where 0 = no change
--     result:     Adjusted video value [0, 1] normalized (clamped)
--
-- Pipeline Architecture:
--   Stage 1: Center input around 0.5, prepare contrast and brightness
--            Convert unsigned inputs to signed fixed-point
--   Stage 2-N: Signed multiplier computes (centered * contrast) + brightness
--              Uses proc_amp multiplier_s with integrated accumulator
--   Output: Extract result bits and convert back to unsigned
--
-- Generic Parameters:
--   G_WIDTH: Bit width of input/output video data (typically 10 for SD/HD video)
--
-- Fixed-Point Representation (for G_WIDTH=10):
--   Input/Output range: 0 to 1023 (unsigned, representing 0.0 to ~1.0)
--   Contrast:
--     Input value 0 = 0.0x (full black output)
--     Input value 512 = 1.0x (unity gain, no change)
--     Input value 1023 = ~2.0x (double contrast)
--   Brightness:
--     Input value 0 = -0.5 (full black shift)
--     Input value 512 = 0.0 (no brightness change)
--     Input value 1023 = +0.5 (full white shift)
--
-- Internal Processing:
--   - All operations use G_WIDTH+2 bits for signed arithmetic
--   - C_FRAC_BITS = G_WIDTH fractional bits for fixed-point precision
--   - Multiplier includes integrated clamping to valid output range
--
-- Latency:
--   1 cycle (input registration) + multiplier_s latency (typically 6-9 cycles)
--   Total: ~7-10 clock cycles
--
-- Features:
--   - Precise fixed-point arithmetic using signed multiplier
--   - Integrated contrast and brightness in single pass
--   - Automatic output clamping to valid unsigned range
--   - Valid signal pipeline for dataflow control

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity proc_amp_u is
  generic (
    G_WIDTH : integer := 10
  );
  port (
    clk        : in std_logic;
    enable     : in std_logic;
    a          : in unsigned(G_WIDTH - 1 downto 0);
    contrast   : in unsigned(G_WIDTH - 1 downto 0);
    brightness : in unsigned(G_WIDTH - 1 downto 0);
    result     : out unsigned(G_WIDTH - 1 downto 0);
    valid      : out std_logic
  );
end proc_amp_u;

architecture rtl of proc_amp_u is
  --------------------------------------------------------------------------------
  -- Constants
  --------------------------------------------------------------------------------
  constant C_PROC_WIDTH : integer := G_WIDTH + 2;  -- Extra bits for signed arithmetic
  constant C_FRAC_BITS  : integer := G_WIDTH;      -- Fractional precision
  constant C_HALF       : signed(C_PROC_WIDTH - 1 downto 0) := to_signed(2 ** (C_FRAC_BITS - 1), C_PROC_WIDTH);  -- 0.5 in fixed-point
  
  --------------------------------------------------------------------------------
  -- Stage 1: Input Processing Signals
  --------------------------------------------------------------------------------
  signal s_centered     : signed(C_PROC_WIDTH - 1 downto 0);  -- Input centered around 0.5
  signal s_contrast     : signed(C_PROC_WIDTH - 1 downto 0);  -- Contrast factor [0, 2.0]
  signal s_brightness   : signed(C_PROC_WIDTH - 1 downto 0);  -- Brightness offset [-0.5, +0.5]
  signal s_enable       : std_logic;
  
  --------------------------------------------------------------------------------
  -- Stage 2+: Multiplier Output
  --------------------------------------------------------------------------------
  signal s_result       : signed(C_PROC_WIDTH - 1 downto 0);  -- Final result from multiplier
  signal s_valid        : std_logic;
  
begin

  --------------------------------------------------------------------------------
  -- Stage 1: Input Preparation and Centering
  -- Latency: 1 cycle
  -- Converts unsigned inputs to signed fixed-point and centers input around 0.5
  --------------------------------------------------------------------------------
  p_input_stage : process (clk)
  begin
    if rising_edge(clk) then
      -- Center input around 0.5 (neutral point for contrast operation)
      -- This allows contrast to work symmetrically around middle gray
      -- Calculation: centered = input - 0.5
      s_centered   <= resize(signed('0' & std_logic_vector(a)), C_PROC_WIDTH) - C_HALF;
      
      -- Prepare contrast: scale to range [0, 2.0] with 1 extra fractional bit
      -- Input 512 (half range) represents 1.0x unity gain
      -- Append '0' to create extra fractional precision
      s_contrast   <= resize(signed('0' & std_logic_vector(contrast) & '0'), C_PROC_WIDTH);
      
      -- Prepare brightness: convert to range [-0.5, +0.5] centered at 0
      -- Input 512 represents 0.0 (no brightness change)
      -- Subtract 0.5 to create symmetric range around zero
      s_brightness <= resize(signed('0' & std_logic_vector(brightness) & '0'), C_PROC_WIDTH) - C_HALF;
      
      -- Register enable signal
      s_enable     <= enable;
    end if;
  end process p_input_stage;
  
  --------------------------------------------------------------------------------
  -- Stage 2+: Multiplication and Addition
  -- Latency: multiplier_s pipeline depth (typically 6-9 cycles)
  -- Computes: result = (input - 0.5) * contrast + brightness
  -- The multiplier includes integrated accumulator (adds brightness)
  --------------------------------------------------------------------------------
  multiplier_inst : entity work.multiplier_s
    generic map(
      G_WIDTH      => C_PROC_WIDTH,
      G_FRAC_BITS  => C_FRAC_BITS,
      G_OUTPUT_MIN => 0,                          -- Clamp to valid unsigned range
      G_OUTPUT_MAX => (2 ** C_FRAC_BITS) - 1      -- Maximum unsigned value
    )
    port map(
      clk    => clk,
      enable => s_enable,
      x      => s_centered,     -- Centered input (multiplicand)
      y      => s_contrast,     -- Contrast factor (multiplier)
      z      => s_brightness,   -- Brightness offset (accumulator addend)
      result => s_result,       -- Final clamped result
      valid  => s_valid         -- Output valid signal
    );

  --------------------------------------------------------------------------------
  -- Output Assignments
  -- Extract lower bits and convert back to unsigned for video output
  --------------------------------------------------------------------------------
  result <= unsigned(std_logic_vector(s_result(C_FRAC_BITS - 1 downto 0)));
  valid  <= s_valid;

end rtl;
