# vmprog_pack - Videomancer Program Package Creator

## Overview

`vmprog_pack.py` is a Python tool that creates fully packaged and verified `.vmprog` files from program configuration binaries and FPGA bitstream binaries. The output is validated against the Videomancer program package format specification.

## Features

- ✅ Creates complete `.vmprog` package files from input directory
- ✅ Supports all six bitstream variants (SD/HD × Analog/HDMI/Dual)
- ✅ **Ed25519 cryptographic signing** with automatic key loading
- ✅ Calculates SHA-256 hashes for all payloads
- ✅ Generates proper TOC (Table of Contents) entries
- ✅ Validates package structure against format specification
- ✅ Verifies all hashes after package creation
- ✅ Comprehensive error checking and validation
- ✅ Human-readable validation output

## Requirements

- Python 3.7 or higher
- Standard library (no dependencies for basic functionality)
- **Optional:** `cryptography` library for Ed25519 signing
- **Configuration:** TOML files defining program parameters (see [TOML Configuration Guide](../../docs/toml-program-config-guide.md))
  ```bash
  # Ubuntu/Debian/WSL2 (recommended)
  sudo apt install python3-cryptography
  
  # macOS or if system allows pip
  pip3 install cryptography
  
  # If you get "externally-managed-environment" error
  pip3 install --user cryptography
  ```

## Usage

### Basic Usage

```bash
python vmprog_pack.py <input_dir> <output_file.vmprog>
```

### Command-Line Options

```bash
python vmprog_pack.py [-h] [--no-sign] [--keys-dir KEYS_DIR] input_dir output_file

positional arguments:
  input_dir             Input directory containing program_config.bin and bitstreams/
  output_file           Output .vmprog file path

optional arguments:
  -h, --help            Show help message
  --no-sign             Do not sign the package (create unsigned package)
  --keys-dir KEYS_DIR   Directory containing Ed25519 keys (default: ./keys)
```

### Examples

```bash
# Create signed package (default behavior)
python vmprog_pack.py ./build/programs/passthru ./output/passthru.vmprog

# Create unsigned package
python vmprog_pack.py --no-sign ./build/programs/passthru ./output/passthru.vmprog

# Use keys from custom directory
python vmprog_pack.py --keys-dir ./my_keys ./build/programs/passthru ./output/passthru.vmprog

# Create yuv_amplifier.vmprog
python vmprog_pack.py ./build/programs/yuv_amplifier ./output/yuv_amplifier.vmprog
```
Ed25519 Cryptographic Signing

The tool supports Ed25519 digital signatures for package authentication and integrity verification.

### Key Management

Ed25519 keys are stored as raw binary files (32 bytes each):
- `lzx_official_signed_descriptor_priv.bin` - Private key (keep secret!)
- `lzx_official_signed_descriptor_pub.bin` - Public key (safe to share)

Default key location: `./keys/` (relative to SDK root)

### Generating Keys

Use the provided key generation script:

```bash
# Generate keys in default location (../../keys from vmprog_pack)
python generate_ed25519_keys.py --output-dir ../../keys

# Or use the setup script
cd ../
./setup_ed25519_signing.sh   # Linux/macOS/WSL2
```

⚠️ **Security Notice:** Keep private keys secure. Do NOT commit them to version control!

### Signing Process

When signing is enabled (default), the tool:
1. Loads the private key from the keys directory
2. Creates a signed descriptor containing hashes of all package contents
3. Generates an Ed25519 signature over the descriptor
4. Includes the signature as a TOC entry in the package
5. Sets the `signed_pkg` flag in the package header

The signature is verified by Videomancer firmware using the embedded public key.

### Signed vs. Unsigned Packages

**Signed packages** (default):
- Include a SIGNATURE TOC entry (64 bytes)
- Have the `signed_pkg` flag set in header
- Can be verified by firmware for authenticity
- Recommended for production use

**Unsigned packages** (`--no-sign`):
- Do not include a signature
- Do not have the `signed_pkg` flag set
- Useful for testing and development
- Will work on firmware that accepts unsigned packages

## Output Format

The tool creates a `.vmprog` file with the following structure:

1. **Header** (64 bytes)
   - Magic number: 'VMPG' (0x47504D56)
   - Version: 1.0
   - File size, TOC metadata
   - Package SHA-256 hash
   - Flags (including `signed_pkg` if signed)

2. **Table of Contents (TOC)**
   - One entry per payload (64 bytes each)
   - Contains type, offset, size, and hash for each payload

3. **Payloads**
   - Program configuration (7368 bytes)
   - Signed descriptor (332 bytes)
   - Ed25519 signature (64 bytes, if signed

**Notes:**
- `program_config.bin` is **required** and must be exactly 7368 bytes
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
   - Program configuration (7368 bytes)
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
- ✓ Size exactly 7368 bytes
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

Loaded program config: 7368 bytes
Found bitstream: sd_analog.bin (104090 bytes)
Found bitstream: sd_hdmi.bin (104090 bytes)
Found bitstream: sd_dual.bin (104090 bytes)
Found bitstream: hd_analog.bin (104090 bytes)
Found bitstream: hd_hdmi.bin (104090 bytes)
Found bitstream: hd_dual.bin (104090 bytes)

TOC Entry 0: CONFIG
  Offset: 512
  Size: 7368
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
  Size: 7368
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
