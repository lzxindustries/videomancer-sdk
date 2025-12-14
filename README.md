# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

> Official FPGA development kit for Videomancer hardware

Videomancer by LZX Industries is a real-time video processing device built on the Raspberry Pi RP2040 microcontroller and the Lattice ICE40HX4K FPGA. It provides a flexible platform for creating custom video effects with hardware description languages.

**Repository:** [github.com/lzxindustries/videomancer-sdk](https://github.com/lzxindustries/videomancer-sdk)

## Overview

The Videomancer SDK is the **official development kit maintained by LZX Industries** for developing, packaging, and deploying FPGA programs to Videomancer hardware. This SDK includes:

- **Program Package Format (`.vmprog`)** - Secure container format for FPGA bitstreams with cryptographic verification
- **Cryptographic Libraries** - Ed25519 signing and SHA-256 hashing for program integrity
- **Hardware Abstraction** - APIs for FPGA configuration and parameter management
- **Build Tools** - CMake-based build system for cross-platform development

## Features

- ✅ Cryptographically signed FPGA program packages
- ✅ Ed25519 digital signatures for authenticity verification
- ✅ SHA-256 content hashing for integrity checks
- ✅ Hardware compatibility detection
- ✅ ABI version management
- ✅ User-configurable program parameters
- ✅ Support for multiple bitstream variants (SD/HD, analog/HDMI)

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

- **[Program Package Format](docs/vmprog-format.md)** - Complete specification of the `.vmprog` file format
- **[Third Party Licenses](THIRD_PARTY_LICENSES.md)** - Licenses for included dependencies

## Third Party Libraries

This project includes the following third-party libraries:

| Library | Version | License | Purpose |
|---------|---------|---------|---------|
| [Monocypher](https://monocypher.org/) | Latest | BSD-2-Clause OR CC0-1.0 | Cryptographic operations (Ed25519, SHA-256) |

See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for complete license texts.

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

### Third Party Components

Third-party libraries included in this project retain their original licenses. See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for details.

## Support and Contributions

### Maintenance

This SDK is **actively maintained by LZX Industries LLC**. Development priorities are aligned with our hardware roadmap and customer needs.

### Bug Reports

Community bug reports are welcome and appreciated. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting issues.

### Feature Requests

While we prioritize features based on our internal roadmap, we're interested in hearing about use cases from the Videomancer community. Please understand that implementation is subject to our product priorities.

### External Contributions

This project is primarily developed internally by LZX Industries. External contributions are reviewed on a case-by-case basis. Please discuss significant changes with maintainers before investing effort.

For more information, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Commercial Support

For commercial support, custom development, or partnership inquiries, please contact LZX Industries directly.

## License

This project is licensed under the GNU General Public License v3.0 or later - see the [LICENSE](LICENSE) file for details.

**Copyright (C) 2025 LZX Industries LLC**

This is a commercially maintained open-source project. While the source code is freely available under GPL-3.0, active development and support are provided by LZX Industries.
