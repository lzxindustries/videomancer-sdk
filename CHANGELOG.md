# Changelog

All notable changes to the Videomancer SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-14

### Added

- Comprehensive `.vmprog` file format specification (v1.0)
- Header-only SDK with cryptographic verification support
- Ed25519 digital signature verification via Monocypher
- SHA-256 hashing for integrity checks
- Complete data structures for program packages:
  - `vmprog_header_v1_0` - File header with metadata
  - `vmprog_toc_entry_v1_0` - Table of contents entries
  - `vmprog_program_config_v1_0` - Program configuration
  - `vmprog_signed_descriptor_v1_0` - Cryptographic descriptor
  - `vmprog_parameter_config_v1_0` - Parameter definitions
- Validation functions for all structures
- CMake build system with version management
- Third-party license documentation
- Comprehensive format specification documentation (1948 lines)

### Documentation

- Complete `.vmprog` format specification in `docs/vmprog-format.md`
- README with project overview, features, and build instructions
- Usage examples for SDK integration
- Third-party licenses documented in `THIRD_PARTY_LICENSES.md`

### Dependencies

- Monocypher cryptographic library (BSD-2-Clause OR CC0-1.0)

### Project Structure

- Header-only library in `src/lzx/sdk/`
- Build configuration via CMake
- Git-based version tracking
- GPL-3.0 license

## Release Notes

### Version 0.1.0

This is the initial public release of the Videomancer SDK. The SDK provides a complete specification and implementation for the `.vmprog` file format, which is used to package and distribute FPGA programs for Videomancer hardware.

**Key Features:**

- Cryptographically signed program packages
- Hardware compatibility detection
- ABI version management
- Support for multiple bitstream variants (SD/HD, analog/HDMI)
- User-configurable parameters (up to 12 parameters)

**Status:** Pre-release (0.x series indicates API may change before 1.0)

[Unreleased]: https://github.com/lzxindustries/videomancer-sdk/compare/0.1.0...HEAD
[0.1.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/0.1.0
