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

All Videomancer programs implement architectures of the `program_top` entity:

```vhdl
entity program_top is
    port (
        clk             : in std_logic;                    -- Pixel clock
        registers_in    : in t_spi_ram;                    -- Control registers via SPI
        data_in         : in t_video_stream_yuv444_30b;    -- Input video stream
        data_out        : out t_video_stream_yuv444_30b    -- Output video stream
    );
end entity program_top;
```

**Key Points:**
- **Clock**: 74.25 MHz pixel clock (HD) or 13.5 MHz pixel clock (SD)
- **Registers**: Control registers 0-7 for parameters, register 8 for video timing ID
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

1. **Main VHDL file**: Implements an architecture of `program_top`
2. **TOML config**: Defines program metadata and register mappings

## Development Workflow

### Step 1: Concept and Planning

Define your program's functionality:
- What effect will it create?
- Which [categories](program-categories.md) does it belong to? (up to 8 tags)
- Is it a *processing* program (transforms input video) or a *synthesis* program (generates output from scratch)?
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
- **`C_PROCESSING_DELAY_CLKS`** must equal the **total** `program_top` latency from
  `data_in` to `data_out`, including IO-align register stages. This value is packed
  into vmprog as `processing_delay_clks` and drives Sync Out phase advance (SPI 0x09).
  It must be **divisible by 4** (pad with extra IO-align stages when needed).

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

architecture your_program of program_top is
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
-- Registers 0-7: parameter controls (10-bit, 0-1023)
s_param1 <= unsigned(registers_in(0));  -- Register 0: rotary_potentiometer_1
s_enable <= registers_in(1)(0);         -- Register 1, bit 0

-- Register 8: video timing ID (4-bit, in bits [3:0])
s_timing_id <= registers_in(8)(3 downto 0);
```

**Timing-Aware Programming:**

The firmware writes the active video timing ID to `registers_in(8)(3 downto 0)` at program load and whenever the video standard changes. Programs can compare this value against the constants defined in `video_timing_pkg.vhd` to adapt their processing.

```vhdl
library work;
use work.video_timing_pkg.all;

-- In your architecture:
signal s_timing_id : std_logic_vector(3 downto 0);
signal s_is_sd     : std_logic;

-- Extract timing ID from register 8
s_timing_id <= registers_in(8)(3 downto 0);

-- Example: detect SD modes (NTSC, PAL, 480p, 576p)
s_is_sd <= '1' when s_timing_id = C_NTSC
                  or s_timing_id = C_PAL
                  or s_timing_id = C_480P
                  or s_timing_id = C_576P
           else '0';

-- Example: look up frame dimensions from video_sync_pkg
use work.video_sync_pkg.all;
signal s_frame_width  : unsigned(15 downto 0);
signal s_frame_height : unsigned(15 downto 0);

s_frame_width  <= C_VIDEO_SYNC_CONFIG_ARRAY(
    to_integer(unsigned(s_timing_id))).frame_width;
s_frame_height <= C_VIDEO_SYNC_CONFIG_ARRAY(
    to_integer(unsigned(s_timing_id))).frame_height;
```

See [ABI Format — Video Timing ID](abi-format.md#video-timing-id-0x08) for the complete table of timing ID values and frame dimensions.

> **Note**: Most programs do not need timing awareness — they process pixels
> identically regardless of resolution. Use `registers_in(8)` only when your
> algorithm needs to scale delay depths, buffer sizes, or spatial parameters
> relative to the frame dimensions.

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

Bitstream payloads are DEFLATE-compressed by default, reducing `.vmprog`
file size by approximately 60%. The firmware decompresses transparently
during FPGA configuration. Use `--no-compress` to disable compression
if needed. See [Bitstream Compression](bitstream-compression.md).

### Step 7: Verify With the VHDL Image Tester

The **VHDL Image Tester** (`tools/vhdl-image-tester/`) lets you run any
Videomancer program as an **authentic GHDL simulation** on a still image and
inspect the processed result — no FPGA hardware required. It works both from
a standalone SDK checkout and from within the Videomancer firmware repository.

The tester analyses every SDK package and your program's VHDL source files,
elaborates a testbench, and drives the DUT clock-by-clock using a BT.601-
converted pixel stream. Any discrepancy between expected and actual output
indicates a genuine VHDL bug rather than a simulator abstraction artifact.

#### GUI mode (interactive)

```bash
# First-time setup (creates a .venv and installs PyQt6/NumPy/Pillow):
cd tools/vhdl-image-tester
./run.sh --install

# Launch:
./run.sh
```

Or launch without installing:

```bash
python tools/vhdl-image-tester/run.py
```

**Workflow:**
1. Select your program from the dropdown.
2. Select a source image (test images are in `lfs/library/stock/test-images/`).
3. Adjust register sliders to the values you want to test.
4. Press **F5** to simulate. Before/after images appear side-by-side.

Use **Export Regs** (or `lzx-vhdl-cli export-regs`) to save parameter
presets as JSON for reproducible test cases.

#### CLI mode (headless / scriptable)

All GUI features are available without a display server:

```bash
# List programs visible to the tester
lzx-vhdl-cli list

# Show your program's parameter table
lzx-vhdl-cli info your_program

# Run a simulation and save the result
lzx-vhdl-cli simulate your_program \
    --image lfs/library/stock/test-images/kodim23.png \
    --output result.png

# Override specific registers
lzx-vhdl-cli simulate your_program \
    --image lfs/library/stock/test-images/kodim23.png \
    --set rotary_potentiometer_1=800 \
    --set toggle_switch_7=1023 \
    --output result.png

# Export defaults → edit → re-import for reproducible test cases
lzx-vhdl-cli export-regs your_program --output your_program_regs.json
lzx-vhdl-cli simulate your_program \
    --image lfs/library/stock/test-images/kodim23.png \
    --import-regs your_program_regs.json \
    --output result.png
```

The `lzx-vhdl-cli` script is installed automatically with `./run.sh --install`.
Alternatively, the combined `lzx-vhdl-tester` entrypoint detects CLI
sub-commands automatically:

```bash
lzx-vhdl-tester simulate your_program --image photo.png --output result.png
python -m vhdl_image_tester simulate your_program --image photo.png
```

See the full [VHDL Image Tester README](../tools/vhdl-image-tester/README.md)
for all CLI options, installation details, keyboard shortcuts, and
troubleshooting.

## Examples

The SDK includes ten example programs of increasing complexity:

- `programs/passthru` - Minimal pass-through (1 clock latency)
- `programs/yuv_amplifier` - Multi-stage pipeline with submodules
- `programs/colorbars` - Reference color bar generator (EBU/SMPTE)
- `programs/pong` - Classic two-player Pong with AI opponent
- `programs/perlin` - Gradient noise synthesizer with animated palettes
- `programs/mycelium` - Reaction-diffusion organic pattern growth
- `programs/sabattier` - Pseudo-solarization with Mackie line edge glow
- `programs/stic` - Intellivision STIC retro 16-color palette quantizer
- `programs/howler` - Video feedback loop with zoom, decay, and hue rotation
- `programs/kintsugi` - Gold crack-repair edge overlay

## Reference

- [TOML Configuration Guide](toml-config-guide.md)
- [VMPROG Format](vmprog-format.md)
- [Bitstream Compression](bitstream-compression.md)
- [ABI Format](abi-format.md)
- [Package Signing](package-signing-guide.md)
- [VHDL Image Tester](../tools/vhdl-image-tester/README.md)
- [Generating Programs with Claude AI](ai-program-generation-guide.md)

