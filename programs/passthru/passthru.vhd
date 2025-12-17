-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: passthru.vhd - Simple passthrough program for Videomancer
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
-- Program Name:
--   Passthru
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   This is a simple passthrough program that forwards the input video stream
--   directly to the output with minimal latency (1 clock cycle). It serves as
--   a reference implementation and testing baseline for the Videomancer SDK.
--
-- Architecture:
--   Single-stage pipeline:
--     - Input video stream is registered and passed directly to output
--     - All video data (Y, U, V) and sync signals (hsync_n, vsync_n, field_n, avid)
--       are forwarded unchanged
--     - 1 clock cycle latency
--
-- Submodules:
--   None - this is a minimal reference implementation
--
-- Register Map:
--   Compatible with Videomancer ABI 1.x
--   No registers are used by this program. All registers_in values are ignored.
--
-- Timing:
--   Total pipeline latency: 1 clock cycle
--   All signals are simply registered on the rising clock edge
--
-- Use Cases:
--   - Baseline reference for testing video signal integrity
--   - Template for new program development
--   - Verification of SDK build and FPGA synthesis flow
--   - Bypass mode when no video processing is needed

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_stream_pkg.all;
use work.core_pkg.all;
use work.all;

architecture passthru of program_top is
begin
    --------------------------------------------------------------------------------
    -- Single-Stage Pipeline: Direct Video Forwarding
    -- Latency: 1 clock cycle
    -- Registers all input signals and passes them directly to output
    --------------------------------------------------------------------------------
    p_passthrough : process(clk)
    begin
        if rising_edge(clk) then
            -- Forward entire video stream structure unchanged
            -- This includes Y, U, V data and all sync signals
            data_out <= data_in;
        end if;
    end process p_passthrough;

end architecture passthru;
