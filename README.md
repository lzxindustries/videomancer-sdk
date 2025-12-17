# Videomancer SDK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.en.html)

[![CI](https://github.com/lzxindustries/videomancer-sdk/workflows/CI/badge.svg)](https://github.com/lzxindustries/videomancer-sdk/actions/workflows/ci.yml)

Official SDK for Videomancer FPGA hardware by LZX Industries

## Quick Start

```bash

# Clone and setup

git clone https://github.com/lzxindustries/videomancer-sdk.git

cd videomancer-sdk

bash scripts/setup.sh

# Build programs

bash build_programs.sh

# Output: out/*.vmprog

```

**Requirements:** Linux, WSL2, or macOS | Python 3.7+ | ~2 GB disk space

## Documentation

- [Program Development Guide](docs/program-development-guide.md) - Create VHDL programs

- [TOML Configuration Guide](docs/toml-config-guide.md) - Define parameters

- [VMPROG Format](docs/vmprog-format.md) - Package format spec

- [ABI Format](docs/abi-format.md) - Hardware interface

- [Package Signing](docs/package-signing-guide.md) - Ed25519 signing

## Tools

- `tools/toml-editor/` - Visual TOML editor (browser-based)

- `tools/toml-converter/` - TOML to binary converter

- `tools/toml-validator/` - Configuration validator

- `tools/vmprog-packer/` - Package creator

## Examples

- `programs/passthru/` - Minimal pass-through program

- `programs/yuv_amplifier/` - Multi-parameter processor

## License

GPL-3.0-only - Copyright (C) 2025 LZX Industries LLC

---

[lzxindustries.net](https://lzxindustries.net)

