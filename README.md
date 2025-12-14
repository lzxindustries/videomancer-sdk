# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

> Official SDK for Videomancer FPGA hardware by LZX Industries

**Repository:** [github.com/lzxindustries/videomancer-sdk](https://github.com/lzxindustries/videomancer-sdk)

Header-only C++ library for developing, packaging, and deploying FPGA programs with cryptographic verification. Includes `.vmprog` format specification, Ed25519/SHA-256 crypto, and CMake build tools.

## Features

- Cryptographically signed packages (Ed25519 + SHA-256)
- Hardware compatibility and ABI version management  
- User-configurable parameters
- Multiple bitstream variants (SD/HD, analog/HDMI)

## Getting Started

### Prerequisites

- CMake 3.13 or later
- C++17 compatible compiler (C++20 on non-Windows platforms)
- Git

### Building the SDK

```bash
# Clone the repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# Create build directory
mkdir build
cd build

# Configure and build
cmake ..
cmake --build .
```

### Using the SDK in Your Project

The Videomancer SDK is a header-only library. Include it in your CMake project:

```cmake
# Add as subdirectory
add_subdirectory(path/to/videomancer-sdk)

# Link to your target
target_link_libraries(your_target PRIVATE videomancer-sdk)
```

Then include the headers in your code:

```cpp
#include <lzx/sdk/vmprog_format.hpp>
#include <lzx/sdk/vmprog_crypto.hpp>

using namespace lzx;

// Example: Validate a .vmprog file header
void validate_program_file(const uint8_t* file_data, size_t file_size) {
    auto* header = reinterpret_cast<const vmprog_header_v1_0*>(file_data);
    
    auto result = validate_vmprog_header(*header, file_size);
    if (result == vmprog_validation_result::ok) {
        // Header is valid, proceed with loading
    }
}
```

## Documentation

- [Program Package Format](docs/vmprog-format.md) - `.vmprog` file format specification
- [Third Party Licenses](THIRD_PARTY_LICENSES.md) - Monocypher (BSD-2-Clause OR CC0-1.0)

## Project Structure

```text
videomancer-sdk/
├── src/
│   └── lzx/
│       └── sdk/                        # Core SDK headers
│           ├── vmprog_format.hpp       # Program package format
│           ├── vmprog_crypto.hpp       # Cryptographic wrappers
│           ├── vmprog_public_keys.hpp  # Key management
│           └── videomancer_sdk_version.hpp     # Version info (auto-generated)
├── third_party/
│   └── monocypher/                     # Cryptographic library
│       ├── src/                        # Monocypher source files
│       └── CMakeLists.txt
├── docs/
│   └── vmprog-format.md                # Complete format specification
├── scripts/
│   └── videomancer_sdk_version.hpp.in  # Version generation template
├── CMakeLists.txt                      # Build configuration
├── build.sh                            # Build automation script
├── clean.sh                            # Clean build artifacts script
├── .gitignore                          # Git ignore rules
├── README.md                           # This file
├── LICENSE                             # GPL-3.0 license
├── CHANGELOG.md                        # Version history
├── CONTRIBUTING.md                     # Contribution guidelines
└── THIRD_PARTY_LICENSES.md             # Third-party licenses
```

## Contributions

Maintained by LZX Industries. Bug reports welcome. External contributions reviewed case-by-case. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

GPL-3.0 - Copyright (C) 2025 LZX Industries LLC. See [LICENSE](LICENSE).
