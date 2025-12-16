# Videomancer Program Development Guide

A practical guide to creating video processing programs for Videomancer using the SDK.

## Overview

Videomancer programs are VHDL-based video effects that run on the FPGA hardware. Each program receives a video stream, processes it in real-time, and outputs the modified result. Programs can implement effects like color correction, keying, mixing, geometric transformations, and more.

This guide walks you through the complete process of developing a Videomancer program from concept to deployment.

## What You'll Need

- **Basic VHDL knowledge**: Understanding of entities, architectures, processes, and signals
- **Fixed-point arithmetic**: Video data uses 10-bit unsigned values (0-1023)
- **Pipeline design**: FPGA designs benefit from pipelined architectures
- **The SDK**: Development tools, build scripts, and examples in this repository

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

### Step 5: Build and Test

**Build the program:**
```bash
# From SDK root directory
./build_programs.sh your_program
```

This creates:
- Synthesized bitstreams for all video formats
- Program configuration binary
- Complete `.vmprog` package

**Test on hardware:**
1. Copy the `.vmprog` file to your Videomancer device
2. Load the program and verify basic functionality
3. Test all parameter ranges
4. Verify with different video sources and formats

### Step 6: Documentation and Polish

**Add comprehensive comments:**
- Header documentation (overview, architecture, registers)
- Section headers for major code blocks
- Inline comments for complex logic
- Process labels that describe functionality

**Verify code quality:**
- Consistent signal naming (`s_` prefix, descriptive names)
- Proper indentation and formatting
- No synthesis warnings
- All latencies documented

## Best Practices

### Signal Naming

- `s_` prefix for signals, `C_` for constants, `v_` for variables
- Use descriptive names: `s_contrast_value` not `s_cv`

### Fixed-Point Arithmetic

Video values are 10-bit unsigned (0-1023): Black=0, Gray=512, White=1023
- Use extra bits to prevent overflow in calculations
- Scale results back to 10-bit range with rounding

### Resource Management

- **Multipliers**: Limited, use efficiently
- **Block RAM**: Good for delay lines
- More pipeline stages = higher throughput but more latency

### Testing Strategies

1. **Passthrough test**: Verify video passes cleanly
2. **Extreme values**: Test parameters at min/max
3. **Multiple formats**: Test on both SD and HD sources

## Example Programs

Study these examples in the `programs/` directory:

### passthru
- **Complexity**: Minimal (1 clock latency)
- **Purpose**: Reference implementation and testing baseline

### yuv_amplifier
- **Complexity**: Moderate (14 clock latency)
- **Purpose**: Contrast, brightness, saturation, and fade effects
- **Key concepts**: Multi-stage pipeline, submodule instantiation

## Build System Integration

The SDK handles compilation automatically:

1. **VHDL Synthesis**: Uses open-source tools (Yosys, nextpnr)
2. **Config Processing**: Converts TOML to binary format
3. **Package Creation**: Bundles bitstreams and config into `.vmprog`

No manual FPGA tool configuration needed!

## Troubleshooting

**Video corruption:**
- Verify sync signal delays match video latency exactly
- Check for pipeline bubbles or missing avid propagation

**Wrong colors:**
- Remember: YUV not RGB! U/V neutral = 512
- Check signed/unsigned conversions

**Parameters don't work:**
- Verify TOML register IDs match VHDL mapping
- Check bit field extraction syntax

## Reference Documentation

- **[TOML Configuration Guide](toml-config-guide.md)**: Complete parameter definition reference
- **[VMPROG Format Specification](vmprog-format.md)**: Package file structure
- **[ABI Format Specification](abi-format.md)**: Binary format details
- **[Package Signing Guide](package-signing-guide.md)**: Code signing for distribution

## Next Steps

1. **Study the examples**: Start with `passthru`, then examine `yuv_amplifier`
2. **Sketch your design**: Plan pipeline stages and registers on paper
3. **Start simple**: Implement basic functionality first
4. **Iterate**: Add features incrementally, testing each change
5. **Document**: Add comprehensive comments as you code

Welcome to Videomancer development! The community looks forward to seeing what you create.
