# vmprog_pack - Videomancer Program Package Creator

## Overview

`vmprog_pack.py` is a Python tool that creates fully packaged and verified `.vmprog` files from program configuration binaries and FPGA bitstream binaries. The output is validated against the Videomancer program package format specification.

## Features

- ✅ Creates complete `.vmprog` package files from input directory
- ✅ Supports all six bitstream variants (SD/HD × Analog/HDMI/Dual)
- ✅ Calculates SHA-256 hashes for all payloads
- ✅ Generates proper TOC (Table of Contents) entries
- ✅ Validates package structure against format specification
- ✅ Verifies all hashes after package creation
- ✅ Comprehensive error checking and validation
- ✅ Human-readable validation output

## Requirements

- Python 3.7 or higher
- No external dependencies (uses only standard library)

## Usage

```bash
python vmprog_pack.py <input_dir> <output_file.vmprog>
```

### Example

```bash
# Create passthru.vmprog from build output
python vmprog_pack.py ./build/programs/passthru ./output/passthru.vmprog

# Create yuv_amplifier.vmprog
python vmprog_pack.py ./build/programs/yuv_amplifier ./output/yuv_amplifier.vmprog
```

## Input Directory Structure

The input directory must have the following structure:

```
input_dir/
├── program_config.bin          # Required: 7240 bytes
└── bitstreams/                 # Required directory
    ├── sd_analog.bin           # Optional: SD analog input bitstream
    ├── sd_hdmi.bin             # Optional: SD HDMI input bitstream
    ├── sd_dual.bin             # Optional: SD dual input bitstream
    ├── hd_analog.bin           # Optional: HD analog input bitstream
    ├── hd_hdmi.bin             # Optional: HD HDMI input bitstream
    └── hd_dual.bin             # Optional: HD dual input bitstream
```

**Notes:**
- `program_config.bin` is **required** and must be exactly 7240 bytes
- At least one bitstream file is **required**
- Bitstream files are automatically detected by filename
- Bitstream files can be any size (within the 1MB package limit)

## Output Format

The tool creates a `.vmprog` file with the following structure:

1. **Header** (64 bytes)
   - Magic number: 'VMPG' (0x47504D56)
   - Version: 1.0
   - File size, TOC metadata
   - Package SHA-256 hash

2. **Table of Contents (TOC)**
   - One entry per payload (64 bytes each)
   - Contains type, offset, size, and hash for each payload

3. **Payloads**
   - Program configuration (7240 bytes)
   - FPGA bitstreams (variable size)

## Validation

The tool performs comprehensive validation after package creation:

### Header Validation
- ✓ Magic number verification
- ✓ Version compatibility check
- ✓ Header size validation
- ✓ File size consistency
- ✓ TOC metadata validation

### TOC Validation
- ✓ Entry count matches TOC size
- ✓ All payload offsets within file bounds
- ✓ All payload hashes verified

### Program Config Validation
- ✓ Size exactly 7240 bytes
- ✓ All strings null-terminated
- ✓ ABI version range valid
- ✓ Parameter count within limits (≤12)
- ✓ Reserved fields zeroed

### Package Hash Validation
- ✓ Package-wide SHA-256 hash verified

## Exit Codes

- `0` - Success: Package created and validated
- `1` - Error: Package creation or validation failed

## Example Output

```
======================================================================
Building vmprog package
======================================================================
Input directory: ./build/programs/passthru
Output file: ./output/passthru.vmprog

Loaded program config: 7240 bytes
Found bitstream: sd_analog.bin (104090 bytes)
Found bitstream: sd_hdmi.bin (104090 bytes)
Found bitstream: sd_dual.bin (104090 bytes)
Found bitstream: hd_analog.bin (104090 bytes)
Found bitstream: hd_hdmi.bin (104090 bytes)
Found bitstream: hd_dual.bin (104090 bytes)

TOC Entry 0: CONFIG
  Offset: 512
  Size: 7240
  Hash: a3f2d8e9b1c4...

TOC Entry 1: BITSTREAM_SD_ANALOG
  File: sd_analog.bin
  Offset: 7752
  Size: 104090
  Hash: e7b9c2f1a8d3...

[... additional entries ...]

Total package size: 631932 bytes (617.1 KB)

Package hash: d4c8e3f9a2b7...

======================================================================
Package created successfully: ./output/passthru.vmprog
======================================================================

======================================================================
Validating vmprog package
======================================================================
File: ./output/passthru.vmprog
Verify hashes: True

File size: 631932 bytes (617.1 KB)

--- Header Validation ---
✓ Magic: 0x47504D56 ('VMPG')
✓ Version: 1.0
✓ Header size: 64
✓ File size: 631932
✓ Flags: 0x00000000
✓ TOC: offset=64, bytes=448, count=7
✓ TOC size matches entry count
✓ Package hash: d4c8e3f9a2b7...

--- Package Hash Verification ---
✓ Package hash verified

--- TOC Entries Validation ---

Entry 0: CONFIG
  Type: 1
  Flags: 0x00000000
  Offset: 512
  Size: 7240
  Hash: a3f2d8e9b1c4...
  ✓ Payload within file bounds
  ✓ Payload hash verified
  ✓ Config size correct
  ✓ Config structure validated

[... additional entries ...]

======================================================================
✓ Validation PASSED
======================================================================

✓ Successfully created and validated: ./output/passthru.vmprog
```

## Error Handling

The tool provides detailed error messages for common issues:

- Missing or incorrectly sized `program_config.bin`
- No bitstream files found
- Package exceeds 1MB size limit
- Invalid file structure or corrupted data
- Hash verification failures
- Invalid program configuration fields

## Integration with Build System

This tool can be easily integrated into build scripts:

```bash
#!/bin/bash
# Example build script

# Build FPGA bitstreams
make -C fpga/programs/myprogram

# Convert TOML to binary config
python scripts/toml_to_config_binary/toml_to_config_binary.py \
    fpga/programs/myprogram/myprogram.toml \
    build/programs/myprogram/program_config.bin

# Package everything into .vmprog
python scripts/vmprog_pack/vmprog_pack.py \
    build/programs/myprogram \
    output/myprogram.vmprog

echo "✓ Build complete: output/myprogram.vmprog"
```

## Format Specification

For complete details on the `.vmprog` format, see:
- [docs/vmprog-format.md](../../docs/vmprog-format.md)
- [src/lzx/videomancer/vmprog_format.hpp](../../src/lzx/videomancer/vmprog_format.hpp)

## License

Copyright (C) 2025 LZX Industries LLC  
SPDX-License-Identifier: GPL-3.0-only
