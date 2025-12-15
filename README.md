# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

> Official SDK for Videomancer FPGA hardware by LZX Industries

Header-only C++ SDK for the `.vmprog` file format - cryptographically signed FPGA program packages for Videomancer hardware. Includes complete format specification, Ed25519/BLAKE2b cryptography, and Python TOML converter.

**Repository:** [github.com/lzxindustries/videomancer-sdk](https://github.com/lzxindustries/videomancer-sdk)

## Overview

The Videomancer SDK provides a complete toolchain for creating, building, packaging, and distributing FPGA programs for Videomancer hardware. Includes format specification, cryptographic verification, FPGA build chain integration, RTL libraries, and automated packaging workflows.

**Key Features:**

- **Complete Build Chain:** FPGA synthesis toolchain (OSS CAD Suite) with automated build scripts
- **Binary Format:** Distribute FPGA programs up to 1 MB with cryptographic signing
- **Ed25519 Signing:** Complete signing toolchain with key generation and package signing
- **RTL Libraries:** VHDL components for video processing, sync generation, and YUV conversion
- **Python Tooling:** TOML converter and `.vmprog` packaging tool with signature support
- **Cryptographic Security:** Ed25519 signature verification and BLAKE2b-256 hashing
- **Parameter System:** 12 user-configurable parameters with 36 control modes
- **Hardware Compatibility:** Rev A/B detection flags and ABI version management

## Getting Started

### Quick Start (Complete Workflow)

Build everything with these three commands:

```bash
# 1. Clone repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# 2. One-time setup: Install FPGA toolchain (OSS CAD Suite)
bash setup.sh

# 3. (Optional) Set up Ed25519 signing for cryptographically signed packages
bash scripts/setup_ed25519_signing.sh

# 4. Build all FPGA programs (synthesizes bitstreams and creates .vmprog packages)
bash build_programs.sh

# Output: All programs packaged in out/ directory
# Example: out/passthru.vmprog (signed if keys were generated in step 3)
```

**What this does:**
- `setup.sh` - Downloads and installs OSS CAD Suite (Yosys, nextpnr, GHDL) to `build/oss-cad-suite/`
- `setup_ed25519_signing.sh` - (Optional) Installs cryptography library and generates Ed25519 keys for signing
- `build_programs.sh` - For each program in `programs/`:
  - Synthesizes 6 FPGA bitstream variants (SD/HD × analog/HDMI/dual)
  - Converts TOML config to binary format
  - Packages everything into a signed `.vmprog` file (if keys exist)

### Prerequisites

- **System:** Linux (Ubuntu/Debian recommended) or WSL2
- **SDK Build:** CMake 3.13+, C++17 compiler (C++20 on non-Windows), Git
- **FPGA Build:** OSS CAD Suite (installed by `setup.sh`)
- **Python:** Python 3.7+ (standard library only)
- **Ed25519 Signing (optional):** `cryptography` library
  ```bash
  # Ubuntu/Debian (recommended)
  sudo apt install python3-cryptography
  
  # Or using pip (if system allows)
  pip3 install cryptography
  ```
- **Disk Space:** ~2 GB for OSS CAD Suite toolchain

### Building SDK Headers Only

If you only need the SDK headers without FPGA build capability:

```bash
# Build SDK headers and configure CMake
./build_sdk.sh

# Or manually
mkdir build && cd build
cmake ..
cmake --build .
cmake --install . --prefix install
```

### Building Specific Programs

```bash
# Build a single program instead of all programs
./build_programs.sh passthru

# Output: out/passthru.vmprog
```

### Using in Your Project

Add to your CMakeLists.txt:

```cmake
add_subdirectory(videomancer-sdk)
target_link_libraries(your_target PRIVATE videomancer-sdk)
```

## Usage Examples

### Validating a .vmprog File

```cpp
#include <lzx/videomancer/vmprog_format.hpp>
#include <lzx/videomancer/vmprog_crypto.hpp>
#include <lzx/videomancer/vmprog_public_keys.hpp>

using namespace lzx;

bool validate_program_package(const uint8_t* data, size_t size) {
    // Check file size
    if (size > vmprog_header_v1_0::max_file_size) {
        return false;
    }
    
    // Validate header
    auto* header = reinterpret_cast<const vmprog_header_v1_0*>(data);
    if (validate_vmprog_header(*header, size) != vmprog_validation_result::ok) {
        return false;
    }
    
    // Verify signature if present
    if ((header->flags & vmprog_header_flags_v1_0::signed_pkg) != 
        vmprog_header_flags_v1_0::none) {
        // Extract signature and signed descriptor from TOC
        // Verify using vmprog_ed25519_verify()
        // See docs/vmprog-format.md for complete implementation
    }
    
    return true;
}
```

### Creating Program Configurations

Use the Python TOML converter to create binary program configurations:

```bash
cd scripts/toml_to_config_binary

# Create TOML configuration
cat > my_program.toml << 'EOF'
[program]
program_id = "com.example.myprogram"
program_name = "My FPGA Program"
author = "Your Name"
program_version_major = 1
program_version_minor = 0
program_version_patch = 0

[[parameter]]
parameter_id = 1  # rotary_potentiometer_1
name_label = "Frequency"
# ... (see example_program_config.toml for full template)
EOF

# Convert to binary (produces 7,240-byte file)
python3 toml_to_config_binary.py my_program.toml my_program_config.bin
```

### Packaging Complete Programs

Create complete `.vmprog` packages from bitstreams and configuration:

```bash
cd scripts/vmprog_pack

# Package program with cryptographic signature (default if keys exist)
python3 vmprog_pack.py ../../build/programs/passthru ../../out/passthru.vmprog

# Or create unsigned package
python3 vmprog_pack.py --no-sign ../../build/programs/passthru ../../out/passthru.vmprog

# Input directory structure:
#   build/programs/passthru/
#     program_config.bin (7,240 bytes)
#     bitstreams/
#       sd_analog.bin, sd_hdmi.bin, sd_dual.bin
#       hd_analog.bin, hd_hdmi.bin, hd_dual.bin
```

### Ed25519 Package Signing

Generate Ed25519 keys and sign packages:

```bash
# Install cryptography library (required for signing)
# Ubuntu/Debian/WSL2:
sudo apt install python3-cryptography

# Or if pip is allowed:
pip3 install cryptography

# One-time setup: Generate Ed25519 key pair
cd scripts/vmprog_pack
python3 generate_ed25519_keys.py --output-dir ../../keys

# Keys are created at:
#   keys/lzx_official_signed_descriptor_priv.bin (32 bytes, keep secret!)
#   keys/lzx_official_signed_descriptor_pub.bin (32 bytes, safe to share)

# Create signed package (default behavior)
python3 vmprog_pack.py ../../build/programs/passthru ../../out/passthru.vmprog

# Test signing functionality
python3 test_ed25519_signing.py

# See docs/vmprog-ed25519-signing.md for complete documentation
```

## SDK Components

### Core Headers

- **[vmprog_format.hpp](src/lzx/videomancer/vmprog_format.hpp)** - Complete `.vmprog` format specification with all data structures and validation functions
- **[vmprog_crypto.hpp](src/lzx/videomancer/vmprog_crypto.hpp)** - Ed25519 signature verification and BLAKE2b-256 hashing
- **[vmprog_public_keys.hpp](src/lzx/videomancer/vmprog_public_keys.hpp)** - Ed25519 public key storage

### Build Scripts

- **[setup.sh](setup.sh)** - One-time setup script that downloads and extracts OSS CAD Suite (Yosys, nextpnr, GHDL)
- **[build_sdk.sh](build_sdk.sh)** - Builds SDK headers and configures CMake
- **[clean_sdk.sh](clean_sdk.sh)** - Removes build artifacts
- **[build_programs.sh](build_programs.sh)** - Complete FPGA build workflow: synthesizes bitstreams for all 6 variants, generates config binary, packages into `.vmprog` files

### Python Tools

- **[toml_to_config_binary.py](scripts/toml_to_config_binary/toml_to_config_binary.py)** - Converts TOML configuration files to 7,240-byte binary format with comprehensive validation
- **[vmprog_pack.py](scripts/vmprog_pack/vmprog_pack.py)** - Creates complete `.vmprog` packages from bitstreams and configuration with SHA-256 verification and Ed25519 signing
- **[generate_ed25519_keys.py](scripts/vmprog_pack/generate_ed25519_keys.py)** - Generates Ed25519 key pairs for package signing
- **[test_ed25519_signing.py](scripts/vmprog_pack/test_ed25519_signing.py)** - Test suite for Ed25519 signing functionality
- **[example_program_config.toml](scripts/toml_to_config_binary/example_program_config.toml)** - Template with 3 parameters demonstrating the configuration format

### FPGA Build System

- **[Makefile](fpga/Makefile)** - FPGA synthesis workflow using Yosys (GHDL plugin), nextpnr-ice40, and icepack
- Supports all 6 bitstream variants with configurable resolution and frequency
- Automatically includes program-specific VHDL, RTL libraries, and hardware constraints

### RTL Libraries (VHDL)

- **[top.vhd](fpga/rtl/top.vhd)** - Top-level entity connecting RP2040, SPI, and video pipeline
- **[core.vhd](fpga/rtl/core.vhd)** - Core video processing module (program integration point)
- **[video_sync_generator.vhd](fpga/rtl/video_sync_generator.vhd)** - Configurable video timing generation
- **[video_timing_pkg.vhd](fpga/rtl/video_timing_pkg.vhd)** - Standard video timing definitions (480i, 480p, 720p, 1080i)
- **[yuv422_to_yuv444.vhd](fpga/rtl/yuv422_to_yuv444.vhd)** / **[yuv444_to_yuv422.vhd](fpga/rtl/yuv444_to_yuv422.vhd)** - YUV format converters
- **[spi_peripheral.vhd](fpga/rtl/spi_peripheral.vhd)** - SPI interface for RP2040 communication
- **[blanking_yuv444.vhd](fpga/rtl/blanking_yuv444.vhd)** - Blanking signal insertion
- **[program_yuv444.vhd](fpga/rtl/program_yuv444.vhd)** - Program logic wrapper interface

### Example Programs

- **[passthru](programs/passthru/)** - Simple passthrough program demonstrating minimal FPGA implementation with no parameters

### Documentation

- **[vmprog-format.md](docs/vmprog-format.md)** - Complete binary format specification with diagrams, validation procedures, and implementation guidelines
- **[vmprog-ed25519-signing.md](docs/vmprog-ed25519-signing.md)** - Ed25519 signing implementation, key management, and security guidelines
- **[vmprog_pack README](scripts/vmprog_pack/README.md)** - Detailed documentation for the program packaging tool
- **[SIGNING_GUIDE.md](scripts/vmprog_pack/SIGNING_GUIDE.md)** - Quick reference for Ed25519 signing
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and development information
- **[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)** - Monocypher and SiliconBlue ICE40 licensing information

## Technical Specifications

### Binary Format

- **Architecture:** Little-endian, packed structures, UTF-8 strings
- **Maximum File Size:** 1 MB (1,048,576 bytes)
- **File Extension:** `.vmprog`
- **MIME Type:** `application/x-vmprog` (proposed)
- **Structure:** Header (64 bytes) + Table of Contents + Artifacts

### Cryptography

- **Signatures:** Ed25519 (64-byte signatures, 32-byte public keys)
- **Hashing:** BLAKE2b-256 (SHA-256 equivalent, 32-byte output)
- **Library:** Monocypher 4.0.2 (BSD-2-Clause OR CC0-1.0)
- **Security:** Constant-time operations, secure memory wiping

### Parameter System

- **12 Parameters Total:** 6 rotary potentiometers, 5 toggle switches, 1 linear slide
- **36 Control Modes:** Linear, stepped, polar, easing curves (sine, quadratic, cubic, exponential)
- **Configuration:** Custom labels, value ranges, display formatting with float precision
- **Binary Size:** 572 bytes per parameter, 7,240 bytes total configuration

### Bitstream Variants

Six variant types for different resolutions and output formats:

- `bitstream_sd_analog` - SD resolution, analog output
- `bitstream_sd_hdmi` - SD resolution, HDMI output
- `bitstream_sd_dual` - SD resolution, dual output
- `bitstream_hd_analog` - HD resolution, analog output
- `bitstream_hd_hdmi` - HD resolution, HDMI output
- `bitstream_hd_dual` - HD resolution, dual output

## Project Structure

```text
videomancer-sdk/
├── src/lzx/videomancer/                   # Core SDK headers
│   ├── vmprog_format.hpp                  # Format specification (1,746 lines)
│   ├── vmprog_crypto.hpp                  # Cryptographic wrappers (248 lines)
│   └── vmprog_public_keys.hpp             # Ed25519 public keys (41 lines)
├── fpga/                                  # FPGA development
│   ├── Makefile                           # FPGA synthesis workflow
│   ├── rtl/                               # VHDL RTL libraries (12 modules)
│   │   ├── top.vhd, core.vhd, spi_peripheral.vhd
│   │   ├── video_sync_generator.vhd, video_timing_pkg.vhd
│   │   └── yuv422_to_yuv444.vhd, yuv444_to_yuv422.vhd, ...
│   └── constraints/                       # Pin/timing constraints
│       ├── videomancer_core_rev_a/
│       └── videomancer_core_rev_b/
├── programs/                              # FPGA program examples
│   └── passthru/                          # Passthrough test program
│       ├── passthru.vhd                   # FPGA implementation
│       └── passthru.toml                  # Configuration
├── scripts/
│   ├── setup_ed25519_signing.sh           # Ed25519 signing setup (Linux/Mac)
│   ├── setup_ed25519_signing.bat          # Ed25519 signing setup (Windows)
│   ├── toml_to_config_binary/             # TOML → binary converter
│   │   ├── toml_to_config_binary.py       # Converter (443 lines)
│   │   ├── example_program_config.toml
│   │   └── test_conversion.sh
│   ├── vmprog_pack/                       # .vmprog packager
│   │   ├── vmprog_pack.py                 # Packager (900 lines, with signing)
│   │   ├── generate_ed25519_keys.py       # Key generation utility
│   │   ├── test_ed25519_signing.py        # Signing test suite
│   │   ├── README.md                      # Tool documentation
│   │   ├── SIGNING_GUIDE.md               # Quick reference
│   │   └── test_vmprog_pack.sh
│   └── videomancer_sdk_version/           # CMake version generation
├── third_party/
│   ├── monocypher/                        # Cryptography (BSD-2-Clause OR CC0-1.0)
│   └── SiliconBlue/                       # ICE40 FPGA primitives (Lattice)
├── docs/
│   ├── vmprog-format.md                   # Format specification (1,167 lines)
│   └── vmprog-ed25519-signing.md          # Ed25519 signing documentation
├── keys/                                  # Ed25519 signing keys (user-generated)
│   ├── README.md                          # Key management guide
│   ├── .gitignore                         # Protects private keys
│   └── *.bin                              # Keys (generated by setup script)
├── build/                                 # Build output (created by scripts)
│   ├── oss-cad-suite/                     # FPGA toolchain (Yosys, nextpnr, GHDL)
│   └── programs/                          # Built program artifacts
├── out/                                   # Final .vmprog packages
├── setup.sh                               # Download/install OSS CAD Suite
├── build_sdk.sh                           # Build SDK headers
├── clean_sdk.sh                           # Clean build artifacts
├── build_programs.sh                      # Build all programs → .vmprog
└── CMakeLists.txt                         # CMake configuration
```

## Development Status

**Version 0.1.0** (Released 2025-12-14) provides a complete FPGA development and packaging toolchain:

✅ **Complete:**
- `.vmprog` format specification and SDK headers
- Full FPGA build chain (OSS CAD Suite integration)
- Ed25519 signature generation and verification toolchain
- RTL VHDL component libraries for video processing
- Python packaging tools (TOML converter, vmprog_pack with signing)
- Automated build scripts for complete workflow
- Example program (passthru) demonstrating full development cycle

🔄 **In Progress:**
- Additional example programs demonstrating video effects

**Current capabilities:** Complete FPGA program development from VHDL → bitstream → signed `.vmprog` package.

## Contributing

Maintained by LZX Industries. Bug reports and issues are welcome. External code contributions are reviewed on a case-by-case basis - see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

**GPL-3.0-only** - Copyright (C) 2025 LZX Industries LLC

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3. See [LICENSE](LICENSE) for complete terms.

**Third-Party Components:**

- **Monocypher 4.0.2:** BSD-2-Clause OR CC0-1.0
- **SiliconBlue ICE40 Components:** Proprietary (Lattice Semiconductor)

See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for complete third-party license information.

---

**Videomancer** is a trademark of LZX Industries LLC.  
For hardware, support, and more information: [lzxindustries.net](https://lzxindustries.net)
