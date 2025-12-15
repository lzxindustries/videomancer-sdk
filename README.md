# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

> Official SDK for Videomancer FPGA hardware by LZX Industries

**Repository:** [github.com/lzxindustries/videomancer-sdk](https://github.com/lzxindustries/videomancer-sdk)

Header-only C++ SDK for the `.vmprog` file format - cryptographically signed FPGA program packages for Videomancer hardware. Includes complete format specification, Ed25519/BLAKE2b cryptography, CMake build system, and Python TOML converter.

## ⚠️ Repository Status - Partial Release

**This repository is currently incomplete.** Version 0.1.0 provides the core `.vmprog` format specification and packaging tools, but additional components are under development and will be released in future versions.

**Currently Available:**

- ✅ `.vmprog` binary format specification
- ✅ C++ SDK with cryptographic verification
- ✅ Python TOML to binary converter
- ✅ Documentation and build system

**Coming in Future Releases:**

- ⏳ **FPGA Build Chain** - Toolchain integration for ICE40HX4K
- ⏳ **Example FPGA Programs** - Reference designs and templates
- ⏳ **RTL VHDL Libraries** - Reusable hardware components
- ⏳ **RTL Constraints** - Timing and pin constraints for Videomancer hardware
- ⏳ **VMProg Packaging Tools** - Complete workflow from bitstream to signed package

**Current Use Cases:**

- Understanding the `.vmprog` format
- Building tools that read/validate `.vmprog` files
- Preparing program configurations in TOML format
- Contributing to format specification discussions

For FPGA development, check back for future releases.

## What's Inside

### Core SDK (C++17/20)

- `vmprog_format.hpp` - Complete `.vmprog` format specification (1,746 lines)
- `vmprog_crypto.hpp` - Cryptographic primitives (248 lines)
- `vmprog_public_keys.hpp` - Ed25519 key storage (41 lines)
- Comprehensive validation functions for all structures
- Support for 7,240-byte program configurations

### Python Tools

- `toml_to_config_binary.py` - TOML to binary converter (443 lines)
- Example TOML with 3 parameters (frequency, amplitude, waveform)
- Test suite with shell and Python verification scripts
- Python 3.10+ and 3.11+ compatible (tomli/tomllib)

### Documentation

- [vmprog-format.md](docs/vmprog-format.md) - 1,167-line format specification
- Complete API documentation in header files
- Usage examples and code snippets
- Third-party license documentation

## Getting Started

### Prerequisites

- CMake 3.13+
- C++17 compiler (C++20 on non-Windows)
- Git (for version extraction)
- Python 3.10+ (for TOML converter)

### Building the SDK

```bash
# Clone repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# Build (creates build/ directory)
./build.sh

# Or manually
mkdir build && cd build
cmake ..
cmake --build .
cmake --install . --prefix install
```

### Using in Your CMake Project

```cmake
# Add as subdirectory
add_subdirectory(videomancer-sdk)

# Link to your target
target_link_libraries(your_target PRIVATE videomancer-sdk)
```

### Basic Usage Example

```cpp
#include <lzx/sdk/vmprog_format.hpp>
#include <lzx/sdk/vmprog_crypto.hpp>
#include <lzx/sdk/vmprog_public_keys.hpp>

using namespace lzx;

// Validate a complete .vmprog file
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

### Creating Program Configurations (Python)

```bash
cd scripts/toml_to_config_binary

# Create/edit TOML configuration
cat > my_program.toml << 'EOF'
[program]
program_id = "com.example.myprogram"
program_name = "My FPGA Program"
author = "Your Name"
program_version_major = 1
program_version_minor = 0
program_version_patch = 0
# ... (see example_program_config.toml)

[[parameter]]
parameter_id = 1  # rotary_potentiometer_1
name_label = "Frequency"
# ...
EOF

# Convert to binary
python3 toml_to_config_binary.py my_program.toml my_program_config.bin

# Verify output (7,240 bytes)
ls -lh my_program_config.bin
```

## Documentation & Resources

- **[vmprog-format.md](docs/vmprog-format.md)** - Complete binary format specification
- **API Documentation** - Inline in header files (`vmprog_format.hpp`, `vmprog_crypto.hpp`)
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines
- **[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)** - Monocypher licensing

## Requirements

**Build:**

- CMake 3.13+
- C++17 compiler (C++20 on non-Windows)
- Git (for version extraction)

**Python Tools:**

- Python 3.10+ (tomli) or 3.11+ (tomllib built-in)

**Runtime:**

- None (header-only library)

## Technical Details

**Binary Format:**

- Little-endian, packed structures
- Maximum file size: 1 MB (1,048,576 bytes)
- Table of contents (TOC) based architecture
- SHA-256 checksums for all artifacts

**Cryptography:**

- Ed25519 signatures (Monocypher 4.0.2)
- BLAKE2b-256 hashing (SHA-256 equivalent)
- Constant-time operations for security

**Parameter System:**

- 12 parameters (6 rotary, 5 toggle, 1 linear)
- 36 control modes (linear, steps, polar, easing)
- Custom labels and value ranges
- Display formatting with float precision

**Bitstream Variants:**

- `bitstream_sd_analog` - SD resolution, analog output
- `bitstream_sd_hdmi` - SD resolution, HDMI output
- `bitstream_sd_dual` - SD resolution, dual output
- `bitstream_hd_analog` - HD resolution, analog output
- `bitstream_hd_hdmi` - HD resolution, HDMI output
- `bitstream_hd_dual` - HD resolution, dual output

## Project Structure

```text
videomancer-sdk/
├── src/lzx/sdk/                         # Core SDK headers
│   ├── vmprog_format.hpp                # Format specification (1,746 lines)
│   ├── vmprog_crypto.hpp                # Crypto wrappers (248 lines)
│   ├── vmprog_public_keys.hpp           # Ed25519 keys (41 lines)
│   └── videomancer_sdk_version.hpp      # Version (auto-generated)
├── scripts/
│   ├── toml_to_config_binary/           # Python converter tool
│   │   ├── toml_to_config_binary.py     # TOML → binary (443 lines)
│   │   ├── example_program_config.toml  # Example with 3 parameters
│   │   ├── test_converter.py            # Python test suite
│   │   └── test_conversion.sh           # Shell test script
│   └── videomancer_sdk_version/
│       └── videomancer_sdk_version.hpp.in  # CMake template
├── third_party/monocypher/              # Cryptographic library
│   └── src/                             # Monocypher source files
├── docs/
│   └── vmprog-format.md                 # Format spec (1,167 lines)
├── CMakeLists.txt                       # Build configuration
├── build.sh / clean.sh                  # Build automation
├── CHANGELOG.md                         # Version history
├── CONTRIBUTING.md                      # Contribution policy
└── THIRD_PARTY_LICENSES.md              # Third-party licenses
```

## Contributing

Maintained by LZX Industries. Bug reports and issues welcome. External code contributions reviewed case-by-case - see [CONTRIBUTING.md](CONTRIBUTING.md) for policy.

## License

**GPL-3.0-only** - Copyright (C) 2025 LZX Industries LLC

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

See [LICENSE](LICENSE) for full terms.

**Third-Party:**

- Monocypher 4.0.2: BSD-2-Clause OR CC0-1.0 (see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md))

**Videomancer** is a trademark of LZX Industries LLC.  
For hardware, support, and more: [lzxindustries.net](https://lzxindustries.net)
