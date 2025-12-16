# Changelog

All notable changes to the Videomancer SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Comprehensive Test Suite Expansion** - Significantly increased test coverage across all SDK headers
  - **vmprog_crypto.hpp**: Added 4 helper function tests (verify_hash, is_hash_zero, secure_compare_hash, is_pubkey_valid)
  - **vmprog_format.hpp**: Added 21 validation and utility tests covering string helpers, enum operators, endianness conversion, TOC validation, descriptor validation, parameter validation, and edge cases
  - **vmprog_stream_reader.hpp**: Added 19 integration tests with mock package setups covering config reading, signed descriptor reading, signature reading, payload verification, and complete package workflows
  - Total test count increased from 60 to 125 tests across 7 test suites
  - All tests achieve 100% pass rate

- **Ed25519 Signature Algorithm Update** - Switched from EdDSA (Blake2b) to standard Ed25519 (SHA-512)
  - Updated vmprog_crypto.hpp to use `crypto_ed25519_check` instead of `crypto_eddsa_check`
  - Implemented RFC 8032 compliant Ed25519 signature verification
  - Added RFC 8032 test vectors to validate implementation correctness
  - Maintains backward compatibility with Monocypher library

- **Integration Test Framework** - Complete mock package testing infrastructure
  - Mock package helpers for creating valid VMProg packages with config, signed descriptors, and signatures
  - End-to-end workflow tests validating entire package reading pipeline
  - Edge case testing for invalid sizes, corrupted data, overflow conditions, and boundary cases
  - Tests all 7 bitstream type variants (SD/HD analog/HDMI/dual, generic)

### Changed

- **Test Organization** - Improved test structure and coverage
  - Systematic method-level coverage analysis ensuring all public APIs tested
  - Added validation tests for all VMProg format structures
  - Enhanced error condition testing for robust SDK behavior
  - Comprehensive testing of string manipulation, cryptographic, and I/O operations

### Fixed

- **Test Coverage Gaps** - Addressed untested methods across SDK headers
  - All cryptographic helper functions now thoroughly tested
  - All format validation functions tested with valid and invalid inputs
  - All stream reading functions tested with mock packages
  - Complete coverage of edge cases, overflow conditions, and error paths

## [0.2.0] - 2025-12-15

### Added

- **TOML Editor** - Browser-based visual editor for program configuration files
  - Live JSON Schema validation with detailed error reporting
  - Dual-view interface: visual form editor and raw TOML text editor
  - Real-time TOML syntax checking with ACE editor integration
  - Embedded dependencies (AJV, ACE Editor) for offline use
  - Light minimal theme optimized for usability
  - Comprehensive documentation in tools/toml-editor/README.md

- **Tool Documentation** - README files for all development tools
  - tools/toml-editor/README.md - Visual editor usage and features
  - tools/toml-converter/README.md - Binary conversion process
  - tools/toml-validator/README.md - Validation tool documentation
  - tools/vmprog-packer/README.md - Package creation and signing

- **toml-config-guide.md** - Comprehensive "how-to" guide for creating TOML configuration files
  - Complete documentation of all program metadata fields
  - Detailed explanation of numeric and label parameter modes
  - All 36 control modes with categorization (linear, stepped, polar, easing)
  - Working examples and validation instructions
  - Tips and best practices for program development

- **toml_schema_validator.py** - Standalone TOML schema validation tool
  - Validates TOML files against JSON Schema
  - Simplifies complex schema patterns for compatibility
  - Clear error reporting with locations and allowed values
  - Deduplicates validation errors for readability

### Changed

#### Documentation Organization

- **Renamed documentation files** for consistency (lowercase-with-hyphens naming)
  - signing-guide.md → package-signing-guide.md
  - toml-program-config-guide.md → toml-config-guide.md
  - vmprog-ed25519-signing.md → ed25519-signing.md
  - All cross-references updated across 13 files

- **Updated documentation content**
  - toml-config-guide.md: Added "Visual Editor (Recommended)" section
  - README.md: Fixed clean_sdk.sh → clean.sh script reference
  - keys/README.md: Corrected script paths (scripts/vmprog_pack → tools/vmprog-packer)

#### Repository Maintenance

- **.gitignore improvements** - Added Python cache patterns
  - `__pycache__/` directories
  - `*.py[cod]` compiled Python files
  - `*.so` shared objects
  - `.Python` metadata

- **Copyright headers** - Added GPL-3.0 license header to tools/toml-editor/toml-editor.html

#### TOML Configuration Format Improvements

- **String enums** - `parameter_id` and `control_mode` now use descriptive strings instead of numeric values
  - Example: `"rotary_potentiometer_1"` instead of `1`
  - Example: `"linear"` instead of `0`
  - More readable and self-documenting configurations

- **Version string formats** - Simplified version specification
  - `program_version` now uses SemVer format (e.g., `"1.2.3"`)
  - `abi_version` uses range notation (e.g., `">=1.0,<2.0"`)
  - Replaces individual numeric fields (`program_version_major`, etc.)
  - Legacy numeric format still supported for backward compatibility

- **Auto-calculated fields** - Reduced manual bookkeeping
  - `parameter_count` automatically calculated from number of `[[parameter]]` sections
  - `value_label_count` automatically calculated from `value_labels` array length
  - These fields should no longer be manually specified in TOML files

- **Signed integer display values** - Support for negative display ranges
  - `display_min_value` and `display_max_value` changed from `uint16_t` to `int16_t`
  - Range: -32768 to 32767 (previously 0 to 65535)
  - Enables display of negative values (e.g., -100 to +100 for brightness)

- **Optional fields with defaults** - Reduced TOML verbosity
  - Program fields: `author`, `license`, `category`, `description`, `url` now optional (default: empty string)
  - Parameter numeric fields: `min_value` (default: 0), `max_value` (default: 1023), `initial_value` (default: 512)
  - Parameter display fields: `display_min_value` (default: `min_value`), `display_max_value` (default: `max_value`), `display_float_digits` (default: 0)
  - Minimal valid configuration requires only `program_id`, `program_name`, version fields

#### Binary Format Changes

- **vmprog_program_config_v1_0** structure increased from 7240 to 7368 bytes
  - Added `url` field (128 bytes) for project/documentation links
  - Adjusted offsets: parameters now start at byte 502 (previously 374)
  - Updated `struct_size` constant to 7368

- **Display value storage** - Changed to signed integers
  - `display_min_value` and `display_max_value` use `int16_t` (signed)
  - Struct packing format changed from `'<H'` (unsigned) to `'<h'` (signed)

#### Validation and Constraints

- **Enhanced validation** in `toml_to_config_binary.py`
  - Unique `parameter_id` enforcement across all parameters
  - Mutual exclusivity: `value_labels` mode vs numeric fields
  - Mutual exclusivity: `value_labels` mode vs `control_mode`
  - Constraint: `min_value` < `max_value` (strictly less than)
  - Constraint: `min_value`, `max_value`, `initial_value` within 0-1023 range
  - Automatic default application for optional fields

- **JSON Schema updates** in `vmprog_program_config_schema_v1_0.json`
  - Enum validation for string-based `parameter_id` and `control_mode`
  - Pattern validation for SemVer and range notation version strings
  - Removed `hw_mask` from required fields (static value in converter)
  - Updated field descriptions to document optional fields and defaults
  - Added mutual exclusivity constraints using `if`/`then`/`not` patterns

#### Removed Fields

- **hw_mask** removed from TOML format
  - Static value `0x00000003` (rev A/B support) set automatically in converter
  - No longer user-configurable

### Fixed

- **TOML Editor bugs**
  - Fixed input focus loss on every keystroke in text fields
  - Fixed raw TOML view disappearing after view switching
  - Improved ACE editor initialization and state management

- **control_mode defaults** - Automatically set to `0` (linear) when omitted or when using `value_labels` mode
- **Schema validation compatibility** - Simplified `$data` references for broader JSON Schema library support

### Documentation

- Updated **vmprog-format.md** with new structure size, offsets, and signed integer types
- Updated **example_program_config.toml** demonstrating all new features
- Updated **passthru.toml** to use new string formats

## [0.1.0] - 2025-12-14

Initial public release of the Videomancer SDK. Complete FPGA development toolchain including format specification, C++ SDK, FPGA build chain, RTL libraries, Ed25519 package signing, and automated packaging workflow for cryptographically signed `.vmprog` packages.

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
- **vmprog_pack.py** - Complete `.vmprog` packager with Ed25519 signing support (creates TOC, calculates SHA-256 hashes, validates output)
- **generate_ed25519_keys.py** - Generate Ed25519 key pairs for package signing (32-byte raw keys)
- **test_ed25519_signing.py** - Test suite for Ed25519 signing functionality
- **test_converter.py** / **test_conversion.sh** - Test suite for TOML converter
- **test_vmprog_pack.sh** - Test suite for packaging tool
- **setup_ed25519_signing.sh** - One-step signing setup script (Linux/macOS/WSL2)
- Example TOML configuration demonstrating 3 parameters
- Python 3.7+ compatibility (standard library only)
- Python `cryptography` library integration for Ed25519 operations

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
- **ed25519-signing.md** - Complete Ed25519 signing implementation documentation
- **vmprog_pack README.md** - Detailed documentation for packaging tool with Ed25519 signing examples
- **SIGNING_GUIDE.md** - Quick reference for daily Ed25519 usage
- **keys/README.md** - Key management and security guidelines
- README with quickstart guide, complete toolchain documentation, and Ed25519 signing examples
- CONTRIBUTING guidelines (LZX Industries maintained, external contributions case-by-case)
- THIRD_PARTY_LICENSES documentation (Monocypher, SiliconBlue ICE40 components)

### Security

- Private keys protected by `.gitignore` in `keys/` directory
- Automatic file permissions (600) set on private keys (Unix-like systems)
- Interactive confirmation required before overwriting existing keys
- Clear security warnings and documentation throughout
- Ed25519 signature generation over 332-byte signed descriptor structure
- `signed_pkg` header flag automatically set for signed packages
- Graceful fallback when `cryptography` library unavailable

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
- Python configuration and packaging tools with Ed25519 signing (complete)
- Automated build scripts for full workflow with signing integration (complete)
- Example program demonstrating complete development cycle (passthru)

**Stability:**
- Pre-release (0.x series) - API may evolve before 1.0
- Binary format is stable and maintains backward compatibility
- Breaking changes will increment minor version
- FPGA build chain tested with OSS CAD Suite 20250523

**Known Limitations:**
- 1 MB file size limit (sufficient for ICE40HX4K bitstreams + metadata)
- 12 parameter maximum (matches Videomancer hardware interface)
- Single Ed25519 public key for verification (additional keys require SDK update)
- Signature generation requires optional `cryptography` Python library

[0.2.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/0.2.0
[0.1.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/0.1.0

