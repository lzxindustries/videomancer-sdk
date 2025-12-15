# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

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

# Output: Programs packaged in out/ directory (e.g., out/passthru.vmprog)
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

## Creating Your Own Programs

### Program Structure

Each program needs:
- **VHDL file** - FPGA implementation (e.g., `myprogram.vhd`)
- **TOML config** - Parameter definitions (e.g., `myprogram.toml`)

Place in `programs/myprogram/` directory.

### Program Configuration

Program parameters are defined in TOML files. See the [TOML Configuration Guide](docs/toml-config-guide.md) for complete documentation.

```bash
cd examples/templates

# See template.toml for a complete example
cat template.toml
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

### Documentation

- **[toml-config-guide.md](docs/toml-config-guide.md)** - Complete guide to creating TOML configuration files
- **[vmprog-format.md](docs/vmprog-format.md)** - Binary format specification
- **[package-signing-guide.md](docs/package-signing-guide.md)** - Package signing with Ed25519
- **[ed25519-signing.md](docs/ed25519-signing.md)** - Detailed Ed25519 implementation
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines

For tools and examples, see `tools/` and `examples/` directories.

## Project Structure

```
videomancer-sdk/
├── docs/                  # Documentation
│   ├── toml-config-guide.md
│   ├── vmprog-format.md
│   ├── package-signing-guide.md
│   ├── ed25519-signing.md
│   ├── abi-format.md
│   └── schemas/
├── examples/             # Example programs and templates
│   ├── passthru/
│   └── templates/
├── tools/                # Development tools
│   ├── toml-editor/      # Visual TOML configuration editor (HTML)
│   ├── toml-converter/   # TOML to binary converter
│   ├── toml-validator/   # Schema validation tool
│   └── vmprog-packer/    # Package creation tool
├── scripts/              # Build automation
│   ├── setup.sh
│   ├── setup_ed25519_signing.sh
│   └── internal/
├── tests/                # Test suite
├── fpga/                 # FPGA synthesis and RTL
│   ├── Makefile
│   └── rtl/
├── programs/             # Your programs go here
├── src/                  # C++ SDK headers
└── build_programs.sh     # Main build script
```

## Contributing

Maintained by LZX Industries. Bug reports and issues are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

**GPL-3.0-only** - Copyright (C) 2025 LZX Industries LLC

See [LICENSE](LICENSE) for complete terms.

---

**Videomancer** is a trademark of LZX Industries LLC.  
For hardware and support: [lzxindustries.net](https://lzxindustries.net)
