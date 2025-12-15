# Changelog

All notable changes to the Videomancer SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-14

Initial public release of the Videomancer SDK. Complete FPGA development toolchain including format specification, C++ SDK, FPGA build chain, RTL libraries, and automated packaging workflow for cryptographically signed `.vmprog` packages.

### Added

#### Core SDK Components

- **vmprog_format.hpp** - Complete `.vmprog` v1.0 format specification with binary structures and validation functions
- **vmprog_crypto.hpp** - Ed25519 signature verification and BLAKE2b-256 hashing wrappers
- **vmprog_public_keys.hpp** - Ed25519 public key storage
- Header-only C++ library (C++17/20) with zero runtime dependencies

#### Binary Format Structures

- `vmprog_header_v1_0` - 64-byte file header (magic: 'VMPG', version, TOC metadata)
- `vmprog_toc_entry_v1_0` - 64-byte table of contents entries
- `vmprog_program_config_v1_0` - 7,240-byte program configuration
- `vmprog_signed_descriptor_v1_0` - 332-byte cryptographic descriptor
- `vmprog_parameter_config_v1_0` - 572-byte parameter definitions (12 parameters total)
- `vmprog_artifact_hash_v1_0` - 36-byte artifact hash entries

#### Features

- Maximum file size: 1 MB (1,048,576 bytes)
- 12 user-configurable parameters (6 rotary, 5 toggle, 1 linear)
- 36 parameter control modes (linear, stepped, polar, easing curves)
- Hardware compatibility flags (Videomancer Core rev A/B)
- ABI version range management
- 6 bitstream variants (SD/HD × analog/HDMI/dual output)
- Little-endian packed structures with UTF-8 strings

#### Cryptography

- Ed25519 digital signatures (64-byte signatures, 32-byte public keys)
- BLAKE2b-256 hashing (SHA-256 equivalent security)
- Constant-time operations and secure memory wiping
- Support for up to 8 signed artifacts per package
- Monocypher 4.0.2 cryptographic library (BSD-2-Clause OR CC0-1.0)

#### FPGA Build Chain

- **OSS CAD Suite Integration** - Yosys (with GHDL plugin), nextpnr-ice40, icepack
- **Makefile** - Automated FPGA synthesis workflow for Lattice ICE40HX4K
- Support for all 6 bitstream variants with configurable frequency
- Automatic inclusion of program VHDL, RTL libraries, and constraints
- ICE40HX4K target with TQ144 package

#### RTL VHDL Libraries

- **top.vhd** - Top-level entity (RP2040 SPI interface, video pipeline integration)
- **core.vhd** - Core video processing module (program integration point)
- **video_sync_generator.vhd** - Configurable video timing generation
- **video_timing_pkg.vhd** - Standard video timing constants (480i, 480p, 720p, 1080i)
- **video_field_detector.vhd** - Field detection for interlaced video
- **yuv422_to_yuv444.vhd** / **yuv444_to_yuv422.vhd** - YUV format converters
- **blanking_yuv444.vhd** - Blanking signal insertion
- **program_yuv444.vhd** - Program logic wrapper interface
- **spi_peripheral.vhd** - SPI peripheral for RP2040 communication
- **sync_slv.vhd** - Clock domain crossing synchronizer
- **core_pkg.vhd** - Core package with type definitions

#### Hardware Constraints

- Pin mapping for Videomancer Core rev A and rev B
- Timing constraints for SD (30 MHz) and HD (80 MHz) modes
- ICE40HX4K-TQ144 specific PCF files

#### Build Scripts

- **setup.sh** - One-time setup: downloads and installs OSS CAD Suite (20250523 release)
- **build_sdk.sh** - Builds SDK headers, configures CMake, generates version info
- **clean_sdk.sh** - Removes all build artifacts
- **build_programs.sh** - Complete workflow: synthesizes all 6 bitstream variants, generates config binary, packages `.vmprog` files

#### Python Tools

- **toml_to_config_binary.py** - TOML to binary converter with comprehensive validation (enum bounds, value ranges, ABI checks)
- **vmprog_pack.py** - Complete `.vmprog` packager (creates TOC, calculates SHA-256 hashes, validates output)
- **test_converter.py** / **test_conversion.sh** - Test suite for TOML converter
- **test_vmprog_pack.sh** - Test suite for packaging tool
- Example TOML configuration demonstrating 3 parameters
- Python 3.7+ compatibility (standard library only)

#### Example Programs

- **passthru** - Simple passthrough program with no parameters
  - passthru.vhd - Minimal FPGA implementation (data passthrough)
  - passthru.toml - Configuration with zero parameters
  - Demonstrates complete development workflow from VHDL to `.vmprog`

#### Build System

- CMake 3.13+ with interface library pattern
- Git-based version extraction and auto-generation
- Header-only library installation with CMake integration
- Automatic dependency management for Monocypher

#### Documentation

- **vmprog-format.md** - Complete binary format specification with diagrams and validation procedures
- **vmprog_pack README.md** - Detailed documentation for packaging tool with usage examples
- README with quickstart guide, complete toolchain documentation, and examples
- CONTRIBUTING guidelines (LZX Industries maintained, external contributions case-by-case)
- THIRD_PARTY_LICENSES documentation (Monocypher, SiliconBlue ICE40 components)

### Project Information

- **License:** GPL-3.0-only
- **Copyright:** 2025 LZX Industries LLC
- **Platform:** Videomancer (RP2040 + Lattice ICE40HX4K FPGA)
- **Repository:** <https://github.com/lzxindustries/videomancer-sdk>

### Notes

**Scope of v0.1.0:**
- Complete FPGA development toolchain (setup → build → package)
- Format specification and SDK headers (complete)
- RTL VHDL libraries for video processing (complete)
- Python configuration and packaging tools (complete)
- Automated build scripts for full workflow (complete)
- Example program demonstrating complete development cycle (passthru)

**Stability:**
- Pre-release (0.x series) - API may evolve before 1.0
- Binary format is stable and maintains backward compatibility
- Breaking changes will increment minor version
- FPGA build chain tested with OSS CAD Suite 20250523

**Known Limitations:**
- 1 MB file size limit (sufficient for ICE40HX4K bitstreams + metadata)
- 12 parameter maximum (matches Videomancer hardware interface)
- Single Ed25519 public key (additional keys require SDK update)
- Signature generation not included (verification only)

[Unreleased]: https://github.com/lzxindustries/videomancer-sdk/compare/0.1.0...HEAD
[0.1.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/0.1.0
