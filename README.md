# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html)
[![CI](https://github.com/lzxindustries/videomancer-sdk/workflows/CI/badge.svg)](https://github.com/lzxindustries/videomancer-sdk/actions/workflows/ci.yml)
[![Documentation](https://github.com/lzxindustries/videomancer-sdk/workflows/Documentation/badge.svg)](https://github.com/lzxindustries/videomancer-sdk/actions/workflows/docs.yml)

> Official SDK for Videomancer FPGA hardware by LZX Industries

**Repository:** [github.com/lzxindustries/videomancer-sdk](https://github.com/lzxindustries/videomancer-sdk)

## Overview

The Videomancer SDK provides a complete toolchain for building FPGA programs for Videomancer hardware. Includes FPGA synthesis tools, RTL libraries, and packaging utilities.

## Building Programs

### Quick Start

Build FPGA programs in three steps:

```bash
# 1. Clone repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# 2. One-time setup: Install FPGA toolchain (OSS CAD Suite)
bash scripts/setup.sh

# 3. Build all FPGA programs
bash build_programs.sh

# Output: Programs packaged in out/ directory (e.g., out/passthru.vmprog, out/yuv_amplifier.vmprog)
```

### Prerequisites

- **System:** Linux (Ubuntu/Debian recommended), WSL2 on Windows, or macOS (Intel or Apple Silicon)
- **macOS only:** [Homebrew](https://brew.sh/) package manager
- **FPGA Build:** OSS CAD Suite (installed by `setup.sh`)
- **Python:** Python 3.7+
- **Disk Space:** ~2 GB for OSS CAD Suite toolchain

#### Windows: Setting up WSL2

1. Open PowerShell as Administrator and run:
   ```powershell
   wsl --install
   ```
2. Restart your computer when prompted
3. Launch Ubuntu from the Start menu and create a user account
4. Update packages: `sudo apt update && sudo apt upgrade`

For more details, see [Microsoft's WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install).

#### macOS: Installing Homebrew

Run this command in Terminal:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to complete setup. More info at [brew.sh](https://brew.sh/).

### What Gets Built

The build process:
1. Synthesizes 6 FPGA bitstream variants (SD/HD × analog/HDMI/dual)
2. Converts TOML configuration to binary format
3. Packages everything into a `.vmprog` file

### Building Specific Programs

```bash
# Build a single program instead of all programs
./build_programs.sh passthru
```

### Building Programs from External Directories

You can organize your programs in separate directories outside the SDK using environment variables:

```bash
# Set up external directory structure
export VIDEOMANCER_SDK_ROOT="/path/to/videomancer-sdk"
export VIDEOMANCER_PROGRAMS_DIR="/path/to/my-programs/"
export VIDEOMANCER_BUILD_DIR="/path/to/my-build/"
export VIDEOMANCER_OUT_DIR="/path/to/my-output/"

# Build programs from external directory
cd /path/to/videomancer-sdk
./build_programs.sh
```

**Complete Example:**

```bash
# Create external programs directory
mkdir -p ~/my-videomancer-programs/my-effect
cd ~/my-videomancer-programs/my-effect

# Create your program files
cat > my-effect.vhd << 'EOF'
-- Your VHDL implementation
library ieee;
use ieee.std_logic_1164.all;
-- ... implementation ...
EOF

cat > my-effect.toml << 'EOF'
[program]
program_id = "com.example.my-effect"
program_name = "My Effect"
program_version = "1.0.0"
abi_version = ">=1.0,<2.0"
# ... configuration ...
EOF

# Set environment variables and build
export VIDEOMANCER_SDK_ROOT=~/videomancer-sdk
export VIDEOMANCER_PROGRAMS_DIR=~/my-videomancer-programs/
export VIDEOMANCER_BUILD_DIR=~/my-videomancer-programs/build/
export VIDEOMANCER_OUT_DIR=~/my-videomancer-programs/out/

cd ~/videomancer-sdk
./build_programs.sh

# Your packaged program will be at:
# ~/my-videomancer-programs/out/my-effect.vmprog
```

**Environment Variables:**
- `VIDEOMANCER_SDK_ROOT` - SDK installation path (default: script directory)
- `VIDEOMANCER_PROGRAMS_DIR` - Directory containing program subdirectories (default: `programs/`)
- `VIDEOMANCER_BUILD_DIR` - Build artifacts output (default: `build/programs/`)
- `VIDEOMANCER_OUT_DIR` - Final `.vmprog` packages output (default: `out/`)
- `VIDEOMANCER_KEYS_DIR` - Ed25519 signing keys directory (default: `keys/`)

## Creating Your Own Programs

For a complete guide to developing VHDL programs for Videomancer, see the **[Program Development Guide](docs/program-development-guide.md)**.

### Program Structure

Each program needs:
- **VHDL file** - FPGA implementation (e.g., `myprogram.vhd`)
- **TOML config** - Parameter definitions (e.g., `myprogram.toml`)

Place in `programs/myprogram/` directory.

### Program Configuration

Program parameters are defined in TOML files. See the [TOML Configuration Guide](docs/toml-config-guide.md) for complete documentation.

**Example Programs:**
- **passthru** - Simple pass-through program (minimal example)
- **yuv_amplifier** - Multi-parameter video processor with gain/offset controls (advanced example)

```bash
cd examples/templates

# See template.toml for a complete example
cat template.toml

# View working examples
cat programs/passthru/passthru.toml
cat programs/yuv_amplifier/yuv_amplifier.toml
```

## SDK Components

### Build Scripts

- **[scripts/setup.sh](scripts/setup.sh)** - Downloads and installs OSS CAD Suite (Yosys, nextpnr, GHDL)
- **[build_programs.sh](build_programs.sh)** - Builds all programs (FPGA synthesis → packaging)
- **[clean.sh](clean.sh)** - Removes build artifacts

### RTL Libraries

VHDL components for video processing (in `fpga/rtl/`):
- Video sync generation and timing
- YUV format converters
- SPI peripheral for RP2040 communication

### Development Tools

- **[toml-editor/](tools/toml-editor/)** - Browser-based visual editor for TOML configuration files
- **[toml-converter/](tools/toml-converter/)** - Converts TOML files to binary configuration format
- **[toml-validator/](tools/toml-validator/)** - Validates TOML files against JSON schema
- **[vmprog-packer/](tools/vmprog-packer/)** - Creates and signs `.vmprog` packages
- **[binary-to-header/](tools/binary-to-header/)** - Converts binary files to C++ header/source files

### Documentation

- **[program-development-guide.md](docs/program-development-guide.md)** - Complete guide to developing VHDL programs
- **[toml-config-guide.md](docs/toml-config-guide.md)** - Complete guide to creating TOML configuration files
- **[vmprog-format.md](docs/vmprog-format.md)** - Binary format specification
- **[package-signing-guide.md](docs/package-signing-guide.md)** - Package signing with Ed25519
- **[ed25519-signing.md](docs/ed25519-signing.md)** - Detailed Ed25519 implementation
- **[abi-format.md](docs/abi-format.md)** - ABI versioning specification
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines

## Project Structure

```
videomancer-sdk/
├── docs/                  # Documentation
│   ├── program-development-guide.md
│   ├── toml-config-guide.md
│   ├── vmprog-format.md
│   ├── package-signing-guide.md
│   ├── ed25519-signing.md
│   ├── abi-format.md
│   └── schemas/
├── examples/             # Configuration templates
│   └── templates/
├── programs/             # Example FPGA programs
│   ├── passthru/         # Simple pass-through example
│   └── yuv_amplifier/    # Advanced multi-parameter example
├── tools/                # Development tools
│   ├── toml-editor/      # Visual TOML configuration editor (HTML)
│   ├── toml-converter/   # TOML to binary converter
│   ├── toml-validator/   # Schema validation tool
│   ├── vmprog-packer/    # Package creation and signing tool
│   └── binary-to-header/ # Binary to C++ header/source converter
├── scripts/              # Build automation
│   ├── setup.sh
│   ├── setup_ed25519_signing.sh
│   └── internal/
├── tests/                # Test suite
├── fpga/                 # FPGA synthesis and RTL
│   ├── Makefile
│   └── rtl/
├── src/                  # C++ SDK headers
├── keys/                 # Ed25519 signing keys (optional)
├── build_programs.sh     # Main build script
└── build_sdk.sh          # SDK library build script
```

## Contributing

Maintained by LZX Industries. Bug reports and issues are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

**GPL-3.0-only** - Copyright (C) 2025 LZX Industries LLC

See [LICENSE](LICENSE) for complete terms.

---

**Videomancer** is a trademark of LZX Industries LLC.
For hardware and support: [lzxindustries.net](https://lzxindustries.net)
