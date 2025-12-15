# Changelog

All notable changes to the Videomancer SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-14

### Added

#### Core SDK

- Header-only C++ library for `.vmprog` file format v1.0
- `vmprog_format.hpp` - Complete format specification (1,746 lines)
- `vmprog_crypto.hpp` - Cryptographic primitives wrapper (248 lines)
- `vmprog_public_keys.hpp` - Ed25519 public key storage (41 lines)
- Binary structures with 1 MB maximum file size
- Comprehensive validation functions for all structures
- Support for 12 user-configurable parameters
- Hardware compatibility flags (Videomancer Core rev A/B)
- ABI version range management
- 36 parameter control modes (linear, steps, polar, easing curves)

#### Data Structures

- `vmprog_header_v1_0` - 64-byte file header with magic, version, TOC
- `vmprog_toc_entry_v1_0` - 64-byte table of contents entries
- `vmprog_program_config_v1_0` - 7,240-byte program configuration
- `vmprog_signed_descriptor_v1_0` - 332-byte cryptographic descriptor
- `vmprog_parameter_config_v1_0` - 572-byte parameter definitions
- `vmprog_artifact_hash_v1_0` - 36-byte artifact hash entries

#### Cryptography

- Ed25519 digital signature verification via Monocypher
- BLAKE2b-256 hashing (SHA-256 equivalent)
- Secure memory operations (constant-time comparison, zeroing)
- Support for up to 8 signed artifacts per package

#### Tools & Utilities

- `toml_to_config_binary.py` - TOML to binary converter (443 lines)
- Example TOML configuration with 3 parameters
- Comprehensive validation (enum bounds, value ranges, ABI checks)
- Test suite with shell and Python verification scripts
- Python 3.10+ and 3.11+ compatibility (tomli/tomllib)

#### Build System

- CMake 3.13+ with interface library pattern
- Git-based version extraction and generation
- Auto-generated version header from git tags
- Header-only library installation
- Build automation scripts (build.sh, clean.sh)

#### Documentation

- Complete format specification in `docs/vmprog-format.md` (1,167 lines)
- README with quickstart, features, and examples
- CONTRIBUTING guidelines (restrictive, LZX Industries maintained)
- Third-party licenses in `THIRD_PARTY_LICENSES.md`
- CHANGELOG following Keep a Changelog format

### Dependencies

- Monocypher 4.0.2 (BSD-2-Clause OR CC0-1.0) - Ed25519, BLAKE2b

### Technical Specifications

- C++17 minimum (C++20 on non-Windows)
- Little-endian binary format with packed structures
- Maximum file size: 1 MB (1,048,576 bytes)
- Maximum parameters: 12 (rotary pots 1-6, toggle switches 7-11, linear pot 12)
- Maximum value labels: 16 per parameter
- Bitstream variants: 6 types (SD/HD × analog/HDMI/dual)

### Project Metadata

- License: GPL-3.0-only
- Copyright: 2025 LZX Industries LLC
- Repository: <https://github.com/lzxindustries/videomancer-sdk>
- Platform: Videomancer (RP2040 + ICE40HX4K FPGA)

## Release Notes

### Version 0.1.0 - Initial Public Release

First open-source release of the Videomancer SDK, providing a complete specification and reference implementation for the `.vmprog` file format used to package FPGA programs for Videomancer hardware.

**Highlights:**

- **Production-Ready Format Specification** - Complete binary format with cryptographic signing, TOC-based structure, and comprehensive validation
- **Header-Only C++ Library** - Zero runtime dependencies, easy integration, interface library pattern
- **Python Tooling** - TOML to binary converter with full validation and test suite
- **Cryptographic Security** - Ed25519 signatures, BLAKE2b-256 hashing via Monocypher
- **Flexible Parameters** - 12 configurable inputs with 36 control modes and custom labeling
- **Hardware Detection** - Compatibility flags and ABI version ranges
- **Professional Documentation** - 1,167-line format specification, comprehensive API docs

**Target Users:**

- FPGA developers creating Videomancer programs
- Tool developers building authoring software
- Hardware integrators working with .vmprog files

**Stability:**

- Pre-release (0.x) - API may evolve before 1.0
- Binary format is stable and backward compatible
- Breaking changes will bump minor version

**What's Not Included:**

- Runtime firmware (proprietary, runs on Videomancer hardware)
- FPGA toolchain (use vendor tools to generate bitstreams)
- GUI authoring tools (community encouraged to build)

**Known Limitations:**

- 1 MB file size limit (sufficient for ICE40HX4K bitstreams)
- 12 parameter maximum (matches hardware capabilities)
- Single Ed25519 public key (additional keys require SDK update)

[Unreleased]: https://github.com/lzxindustries/videomancer-sdk/compare/0.1.0...HEAD
[0.1.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/0.1.0
