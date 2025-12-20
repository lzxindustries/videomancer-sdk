# Program Development Guide

Create VHDL-based video processing programs for Videomancer FPGA hardware.

## Prerequisites

**VHDL knowledge** (entities, architectures, processes, signals)

- [Free Range VHDL](https://github.com/fabriziotappero/Free-Range-VHDL-book) - Open-source VHDL textbook

- [VHDL Tutorial](https://www.nandland.com/vhdl/tutorials/tutorial-introduction-to-vhdl-for-beginners.html) - Nandland beginner tutorials

- [VHDL Programming by Example](https://www.doulos.com/knowhow/vhdl/) - Doulos VHDL resources

**Fixed-point arithmetic** (10-bit unsigned, 0-1023)

- [Fixed-Point Arithmetic: An Introduction](https://inst.eecs.berkeley.edu/~cs61c/sp06/handout/fixedpt.html) - Berkeley CS course notes

- [FPGA Numerical Formats](https://zipcpu.com/dsp/2017/07/22/rounding.html) - ZipCPU fixed-point tutorial

**The SDK and build tools**

- Included in this repository

## Program Architecture

### The Standard Interface

All Videomancer programs implement the same `program_yuv444` entity interface:

```vhdl

entity program_yuv444 is

    port (

        clk             : in std_logic;                    -- System clock (74.25 MHz)

        registers_in    : in t_spi_ram;                    -- 8 registers × 10 bits

        data_in         : in t_video_stream_yuv444;        -- Input video stream

        data_out        : out t_video_stream_yuv444        -- Output video stream

    );

end entity program_yuv444;

```

**Key Points:**

- **Clock**: 74.25 MHz pixel clock (for HD) or 13.5MHz pixel clock (for SD)

- **Registers**: 8 control registers (0-7) for parameters

- **Video Format**: YUV 4:4:4, 10-bit per channel (0-1023)

- **Sync Signals**: hsync_n, vsync_n, field_n, avid (active video flag)

## Project Structure

Each program lives in its own directory under `programs/`:

```

programs/

  your_program/

    your_program.vhd        # Main architecture file

    your_program.toml       # Configuration and metadata

    component1.vhd          # Optional: additional VHDL modules

    component2.vhd          # Optional: more modules

```

### Required Files

1. **Main VHDL file**: Implements the `program_yuv444` architecture

2. **TOML config**: Defines program metadata and register mappings

## Development Workflow

### Step 1: Concept and Planning

Define your program's functionality:

- What effect will it create?

- What parameters need user control?

- What processing stages are needed?

- What's the acceptable latency?

**Example**: A color inverter needs:

- One control register (enable/disable)

- Simple bitwise NOT operation

- Minimal latency (1 clock cycle)

### Step 2: Design the Pipeline

Break your processing into stages:

1. **Input stage**: Register inputs, prepare data

2. **Processing stages**: Arithmetic, logic, transformations

3. **Output stage**: Format results, multiplex outputs

**Key Considerations:**

- Each stage adds 1+ clock cycles of latency

- Sync signals must be delayed to match video data path

- Balance latency vs. resource usage

### Step 3: Create the TOML Configuration

The TOML file defines your program's metadata and control interface. See the [TOML Configuration Guide](toml-config-guide.md) for complete details on program metadata, parameter definitions, and formatting requirements.

### Step 4: Implement the VHDL

Create your main architecture file following this structure:

**Header Section:**

```vhdl

-- Include GPL license header (see existing programs)

-- Add detailed comments:

--   - Program name and description

--   - Architecture breakdown

--   - Pipeline stages and latency

--   - Register map

--   - Submodule descriptions

```

**Libraries and Architecture:**

```vhdl

library ieee;

use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

library work;

use work.core_pkg.all;

use work.video_timing_pkg.all;

architecture your_program of program_yuv444 is

    -- Constants

    constant C_LATENCY_CLKS : integer := ...;

    -- Signals for pipeline stages

    -- ...

begin

    -- Register mapping

    -- Pipeline processes

    -- Output assignments

end architecture;

```

**Register Mapping:**

```vhdl

-- Extract control values from registers_in array

s_param1 <= unsigned(registers_in(0));  -- Register 0

s_enable <= registers_in(1)(0);         -- Register 1, bit 0

```

**Pipeline Implementation:**

```vhdl

-- Label your processes descriptively

p_stage1 : process(clk)

begin

    if rising_edge(clk) then

        -- Stage 1 processing

        -- ...

    end if;

end process p_stage1;

-- Add detailed comments for complex operations

p_stage2 : process(clk)

begin

    if rising_edge(clk) then

        -- Stage 2 processing

        -- ...

    end if;

end process p_stage2;

```

**Delay Line for Sync Signals:**

```vhdl

-- Delay sync signals to match video processing latency

p_sync_delay : process(clk)

    type t_sync_delay is array (0 to C_LATENCY_CLKS - 1) of std_logic;

    variable v_hsync : t_sync_delay := (others => '1');

    -- ... similar for vsync, field

begin

    if rising_edge(clk) then

        v_hsync := data_in.hsync_n & v_hsync(0 to C_LATENCY_CLKS - 2);

        -- Shift other signals

        data_out.hsync_n <= v_hsync(C_LATENCY_CLKS - 1);

        -- Output other delayed signals

    end if;

end process p_sync_delay;

```

### Step 5: Add Python Hook (Optional)

You can optionally create a Python script that runs automatically during the build process, before any FPGA synthesis begins. This is useful for:

- Generating lookup tables or coefficient files
- Preprocessing data or configuration files
- Performing validation checks
- Creating derived VHDL components

**Creating the Hook:**

Create a Python script named `your_program.py` in your program directory:

```python
#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Your Program - Build Hook

Description of what this hook does.
"""

if __name__ == "__main__":
    # Your preprocessing code here
    print("Generating lookup tables...")
    # Generate files, validate configs, etc.
    print("Done!")
```

**Key Points:**

- The script must be named exactly `your_program.py` (matching your program name)
- It will be executed once per program build, before any hardware-specific synthesis
- If the script fails (returns non-zero exit code), the build will stop
- The script runs in the context where OSS CAD Suite environment is loaded
- Use standard Python 3 - the system Python interpreter is used

### Step 6: Build and Test

```bash

./build_programs.sh your_program

```

Creates bitstreams, config binary, and `.vmprog` package. Test on hardware.

## Examples

- `programs/passthru` - Minimal reference (1 clock latency)

- `programs/yuv_amplifier` - Multi-stage pipeline with submodules

## Reference

- [TOML Configuration Guide](toml-config-guide.md)

- [VMPROG Format](vmprog-format.md)

- [ABI Format](abi-format.md)

- [Package Signing](package-signing-guide.md)

