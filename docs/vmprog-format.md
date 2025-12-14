# Videomancer Program Package Format (`.vmprog`)

**Version:** 1.0  
**Status:** Production  
**Canonical Reference:** [src/security/vmprog_format.hpp](../src/security/vmprog_format.hpp)  
**Audience:** Firmware developers, FPGA toolchain authors, program authors

---

## Table of Contents

1. [Overview](#1-overview)
2. [File Structure](#2-file-structure)
3. [Data Types and Enumerations](#3-data-types-and-enumerations)
4. [Binary Structures](#4-binary-structures)
5. [Validation Functions](#5-validation-functions)
6. [Cryptographic Functions](#6-cryptographic-functions)
7. [Helper Functions](#7-helper-functions)
8. [Usage Examples](#8-usage-examples)
9. [Verification Procedures](#9-verification-procedures)
10. [Implementation Guidelines](#10-implementation-guidelines)
11. [References](#11-references)

---

## 1. Overview

The `.vmprog` file format is a **binary container** for distributing FPGA programs to Videomancer video synthesis devices. It provides:

- **Structured packaging** of FPGA bitstreams and metadata
- **Cryptographic integrity** via SHA-256 hashing
- **Digital signatures** using Ed25519
- **Hardware compatibility** checking
- **ABI version** management
- **Parameter configuration** for user controls

### 1.1 Key Features

- **Version:** 1.0 (major.minor versioning)
- **Maximum file size:** 64 MB
- **Endianness:** Little-endian for all multi-byte integers
- **Alignment:** All structures are packed (`#pragma pack(1)`)
- **Security:** Built-in public key verification support
- **String encoding:** Null-terminated UTF-8

### 1.2 Format Philosophy

The format prioritizes:

1. **Security** - Cryptographic verification of all content
2. **Compatibility** - Clear hardware and ABI requirements
3. **Simplicity** - Fixed-size structures where possible
4. **Extensibility** - Reserved fields for future versions
5. **Determinism** - Reproducible builds for signing

### 1.3 File Extension

- Primary: `.vmprog`
- MIME type: `application/x-vmprog` (proposed)

---

## 2. File Structure

### 2.1 Layout Overview

```
┌─────────────────────────────────────────┐
│ File Header (64 bytes)                  │
│ - Magic: 'VMPG'                         │
│ - Version: 1.0                          │
│ - File metadata                         │
│ - Package hash (optional)               │
├─────────────────────────────────────────┤
│ Table of Contents (TOC)                 │
│ - N entries × 64 bytes each             │
│ - Type, offset, size, hash per entry    │
├─────────────────────────────────────────┤
│ Payload: Program Config (7240 bytes)    │
│ - Program metadata                      │
│ - 12 parameter configurations           │
├─────────────────────────────────────────┤
│ Payload: Signed Descriptor (332 bytes)  │
│ - Config hash                           │
│ - Artifact hashes (up to 8)             │
│ - Build ID                              │
├─────────────────────────────────────────┤
│ Payload: Signature (64 bytes)           │
│ - Ed25519 signature over descriptor     │
├─────────────────────────────────────────┤
│ Payload: FPGA Bitstream(s)              │
│ - Variable size                         │
│ - Multiple variants supported           │
└─────────────────────────────────────────┘
```

### 2.2 Offset Calculation

All offsets are absolute byte offsets from the start of the file:

```
Header starts at: 0
TOC starts at: header.toc_offset (typically 64)
TOC ends at: header.toc_offset + header.toc_bytes
Payloads start at: TOC end (variable)
File ends at: header.file_size
```

### 2.3 Size Constraints

- **Header:** Fixed 64 bytes
- **TOC entry:** Fixed 64 bytes
- **Maximum TOC count:** 256 entries (recommended limit)
- **Maximum file size:** 67,108,864 bytes (64 MB)
- **Program config:** Fixed 7,240 bytes
- **Signed descriptor:** Fixed 332 bytes
- **Ed25519 signature:** Fixed 64 bytes

---

## 3. Data Types and Enumerations

### 3.1 Validation Result Codes


### 3.1 Validation Result Codes

**Enum:** `vmprog_validation_result` (uint32_t)

All validation functions return one of these codes:

| Value | Name | Description |
|------:|------|-------------|
| 0 | `ok` | Validation succeeded |
| 1 | `invalid_magic` | Magic number incorrect |
| 2 | `invalid_version` | Unsupported version |
| 3 | `invalid_header_size` | Header size mismatch |
| 4 | `invalid_file_size` | File size invalid |
| 5 | `invalid_toc_offset` | TOC offset out of bounds |
| 6 | `invalid_toc_size` | TOC size incorrect |
| 7 | `invalid_toc_count` | TOC count invalid |
| 8 | `invalid_artifact_count` | Artifact count out of range |
| 9 | `invalid_parameter_count` | Parameter count exceeds limit |
| 10 | `invalid_value_label_count` | Value label count too high |
| 11 | `invalid_abi_range` | ABI range invalid |
| 12 | `string_not_terminated` | Required string not null-terminated |
| 13 | `invalid_hash` | Hash verification failed |
| 14 | `invalid_toc_entry` | TOC entry validation failed |
| 15 | `invalid_payload_offset` | Payload offset out of bounds |
| 16 | `invalid_parameter_values` | Parameter value constraints violated |
| 17 | `invalid_enum_value` | Enum value out of valid range |
| 18 | `reserved_field_not_zero` | Reserved field not zeroed |

### 3.2 TOC Entry Types

**Enum:** `vmprog_toc_entry_type_v1_0` (uint32_t)

Identifies the type of payload referenced by a TOC entry:

| Value | Name | Description |
|------:|------|-------------|
| 0 | `none` | Invalid/unused entry |
| 1 | `config` | Program configuration |
| 2 | `signed_descriptor` | Cryptographic descriptor |
| 3 | `signature` | Ed25519 signature (64 bytes) |
| 4 | `fpga_bitstream` | Generic FPGA bitstream |
| 5 | `bitstream_sd_analog` | SD analog input bitstream |
| 6 | `bitstream_sd_hdmi` | SD HDMI input bitstream |
| 7 | `bitstream_sd_dual` | SD dual input bitstream |
| 8 | `bitstream_hd_analog` | HD analog input bitstream |
| 9 | `bitstream_hd_hdmi` | HD HDMI input bitstream |
| 10 | `bitstream_hd_dual` | HD dual input bitstream |

### 3.3 Header Flags

**Enum:** `vmprog_header_flags_v1_0` (uint32_t, bitmask)

Flags indicating package properties:

| Value | Name | Description |
|------:|------|-------------|
| 0x00000000 | `none` | No flags set |
| 0x00000001 | `signed_pkg` | Package is cryptographically signed |

**Bitwise operations supported:** `|`, `&`, `^`, `~`, `|=`, `&=`, `^=`

### 3.4 TOC Entry Flags

**Enum:** `vmprog_toc_entry_flags_v1_0` (uint32_t, bitmask)

Currently reserved for future use:

| Value | Name | Description |
|------:|------|-------------|
| 0x00000000 | `none` | No flags set |

### 3.5 Signed Descriptor Flags

**Enum:** `vmprog_signed_descriptor_flags_v1_0` (uint32_t, bitmask)

Currently reserved for future use:

| Value | Name | Description |
|------:|------|-------------|
| 0x00000000 | `none` | No flags set |

### 3.6 Hardware Compatibility Flags

**Enum:** `vmprog_hardware_flags_v1_0` (uint32_t, bitmask)

Indicates compatible hardware platforms:

| Value | Name | Description |
|------:|------|-------------|
| 0x00000000 | `none` | No hardware specified |
| 0x00000001 | `videomancer_core_rev_a` | Videomancer Core Rev A |
| 0x00000002 | `videomancer_core_rev_b` | Videomancer Core Rev B |

**Usage:** Multiple flags can be combined with bitwise OR.

### 3.7 Parameter Control Modes

**Enum:** `vmprog_parameter_control_mode_v1_0` (uint32_t)

Defines how parameter values are interpreted and displayed:

#### Linear Scaling Modes
| Value | Name | Description |
|------:|------|-------------|
| 0 | `linear` | Linear 1:1 mapping |
| 1 | `linear_half` | Linear × 0.5 |
| 2 | `linear_quarter` | Linear × 0.25 |
| 3 | `linear_double` | Linear × 2.0 |

#### Discrete/Boolean Modes
| Value | Name | Description |
|------:|------|-------------|
| 4 | `boolean` | On/off switch |
| 5 | `steps_4` | 4 discrete steps |
| 6 | `steps_8` | 8 discrete steps |
| 7 | `steps_16` | 16 discrete steps |
| 8 | `steps_32` | 32 discrete steps |
| 9 | `steps_64` | 64 discrete steps |
| 10 | `steps_128` | 128 discrete steps |
| 11 | `steps_256` | 256 discrete steps |

#### Angular/Polar Modes
| Value | Name | Description |
|------:|------|-------------|
| 12 | `polar_degs_90` | 0-90 degrees |
| 13 | `polar_degs_180` | 0-180 degrees |
| 14 | `polar_degs_360` | 0-360 degrees |
| 15 | `polar_degs_720` | 0-720 degrees |
| 16 | `polar_degs_1440` | 0-1440 degrees |
| 17 | `polar_degs_2880` | 0-2880 degrees |

#### Easing Curve Modes
| Value | Name | Description |
|------:|------|-------------|
| 18 | `quad_in` | Quadratic ease-in |
| 19 | `quad_out` | Quadratic ease-out |
| 20 | `quad_in_out` | Quadratic ease-in-out |
| 21 | `sine_in` | Sinusoidal ease-in |
| 22 | `sine_out` | Sinusoidal ease-out |
| 23 | `sine_in_out` | Sinusoidal ease-in-out |
| 24 | `circ_in` | Circular ease-in |
| 25 | `circ_out` | Circular ease-out |
| 26 | `circ_in_out` | Circular ease-in-out |
| 27 | `quint_in` | Quintic ease-in |
| 28 | `quint_out` | Quintic ease-out |
| 29 | `quint_in_out` | Quintic ease-in-out |
| 30 | `quart_in` | Quartic ease-in |
| 31 | `quart_out` | Quartic ease-out |
| 32 | `quart_in_out` | Quartic ease-in-out |
| 33 | `expo_in` | Exponential ease-in |
| 34 | `expo_out` | Exponential ease-out |
| 35 | `expo_in_out` | Exponential ease-in-out |

### 3.8 Parameter IDs

**Enum:** `vmprog_parameter_id_v1_0` (uint32_t)

Maps parameters to physical hardware controls:

| Value | Name | Description |
|------:|------|-------------|
| 0 | `none` | No parameter assigned |
| 1 | `rotary_potentiometer_1` | Rotary pot #1 |
| 2 | `rotary_potentiometer_2` | Rotary pot #2 |
| 3 | `rotary_potentiometer_3` | Rotary pot #3 |
| 4 | `rotary_potentiometer_4` | Rotary pot #4 |
| 5 | `rotary_potentiometer_5` | Rotary pot #5 |
| 6 | `rotary_potentiometer_6` | Rotary pot #6 |
| 7 | `toggle_switch_7` | Toggle switch #7 |
| 8 | `toggle_switch_8` | Toggle switch #8 |
| 9 | `toggle_switch_9` | Toggle switch #9 |
| 10 | `toggle_switch_10` | Toggle switch #10 |
| 11 | `toggle_switch_11` | Toggle switch #11 |
| 12 | `linear_potentiometer_12` | Linear fader #12 |

---

## 4. Binary Structures

All structures use `#pragma pack(push, 1)` for byte-aligned packing.

### 4.1 File Header

**Structure:** `vmprog_header_v1_0` (64 bytes)

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint32_t | magic | 4 | Magic: 0x47504D56 ('VMPG') |
| 4 | uint16_t | version_major | 2 | Major version (1) |
| 6 | uint16_t | version_minor | 2 | Minor version (0) |
| 8 | uint16_t | header_size | 2 | Header size (64) |
| 10 | uint16_t | reserved_pad | 2 | Reserved (zero) |
| 12 | uint32_t | file_size | 4 | Total file size in bytes |
| 16 | uint32_t | flags | 4 | Header flags |
| 20 | uint32_t | toc_offset | 4 | TOC offset from file start |
| 24 | uint32_t | toc_bytes | 4 | TOC size in bytes |
| 28 | uint32_t | toc_count | 4 | Number of TOC entries |
| 32 | uint8_t[32] | sha256_package | 32 | Package hash (optional) |

**Constants:**
- `expected_magic` = 0x47504D56u
- `max_file_size` = 67108864u (64 MB)
- `default_version_major` = 1
- `default_version_minor` = 0
- `struct_size` = 64

**Validation:**
- Magic must equal 0x47504D56
- `version_major` must be 1
- `header_size` must be 64
- `file_size` must be ≥ 64 and ≤ 67108864
- `toc_offset` must be ≥ 64 and < `file_size`
- `toc_bytes` must equal `toc_count × 64`
- `toc_count` must be > 0 and ≤ 256
- `reserved_pad` must be 0

### 4.2 TOC Entry

**Structure:** `vmprog_toc_entry_v1_0` (64 bytes)

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint32_t | type | 4 | Entry type enum |
| 4 | uint32_t | flags | 4 | Entry flags |
| 8 | uint32_t | offset | 4 | Payload offset (absolute) |
| 12 | uint32_t | size | 4 | Payload size in bytes |
| 16 | uint8_t[32] | sha256 | 32 | SHA-256 hash of payload |
| 48 | uint32_t[4] | reserved | 16 | Reserved (zeros) |

**Constants:**
- `struct_size` = 64

**Validation:**
- `type` must not be `none` (0)
- `type` must be ≤ 10 (bitstream_hd_dual)
- `offset` must be ≥ 64 and < file_size
- If `size` > 0: `offset` ≤ file_size - size (overflow check)
- `reserved[0..3]` must all be 0

### 4.3 Artifact Hash

**Structure:** `vmprog_artifact_hash_v1_0` (36 bytes)

Used in signed descriptors to link artifacts:

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint32_t | type | 4 | Artifact type |
| 4 | uint8_t[32] | sha256 | 32 | SHA-256 hash |

**Constants:**
- `struct_size` = 36

**Validation:**
- `type` must be valid TOC entry type (0-10)
- For unused slots: `type` must be `none` (0) and hash must be all zeros

### 4.4 Signed Descriptor

**Structure:** `vmprog_signed_descriptor_v1_0` (332 bytes)

This structure is signed by Ed25519:

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint8_t[32] | config_sha256 | 32 | Hash of program config |
| 32 | uint8_t | artifact_count | 1 | Number of artifacts (0-8) |
| 33 | uint8_t[3] | reserved_pad | 3 | Reserved padding (zeros) |
| 36 | artifact[8] | artifacts | 288 | Artifact hashes (8×36 bytes) |
| 324 | uint32_t | flags | 4 | Descriptor flags |
| 328 | uint32_t | build_id | 4 | Build identifier |

**Constants:**
- `max_artifacts` = 8
- `struct_size` = 332

**Validation:**
- `artifact_count` must be ≤ 8
- `reserved_pad[0..2]` must all be 0
- Artifacts `[0..artifact_count-1]`: Must have valid type (not none)
- Artifacts `[artifact_count..7]`: Must be fully zeroed (type=none, hash=zeros)

**Notes:**
- This entire structure is the input to Ed25519 signature verification
- The signature is stored separately as a TOC entry

### 4.5 Parameter Configuration

**Structure:** `vmprog_parameter_config_v1_0` (572 bytes)

Configures one user-controllable parameter:

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint32_t | parameter_id | 4 | Parameter ID enum |
| 4 | uint32_t | control_mode | 4 | Control mode enum |
| 8 | uint16_t | min_value | 2 | Minimum raw value |
| 10 | uint16_t | max_value | 2 | Maximum raw value |
| 12 | uint16_t | initial_value | 2 | Initial/default value |
| 14 | uint16_t | display_min_value | 2 | Display range minimum |
| 16 | uint16_t | display_max_value | 2 | Display range maximum |
| 18 | uint8_t | display_float_digits | 1 | Decimal places for display |
| 19 | uint8_t | value_label_count | 1 | Number of value labels |
| 20 | uint8_t[2] | reserved_pad | 2 | Reserved padding |
| 22 | char[32] | name_label | 32 | Parameter name |
| 54 | char[16][32] | value_labels | 512 | Value label strings |
| 566 | char[4] | suffix_label | 4 | Unit suffix (e.g., "°") |
| 570 | uint8_t[2] | reserved | 2 | Reserved |

**Constants:**
- `name_label_max_length` = 32
- `value_label_max_length` = 32
- `suffix_label_max_length` = 4
- `max_value_labels` = 16
- `struct_size` = 572

**Validation:**
- `parameter_id` must be ≤ 12
- `control_mode` must be ≤ 35 (expo_in_out)
- `value_label_count` must be ≤ 16
- `min_value` ≤ `max_value`
- `initial_value` must be in range [min_value, max_value]
- `display_min_value` ≤ `display_max_value`
- `name_label` must be null-terminated
- `suffix_label` must be null-terminated
- Each value_label `[0..value_label_count-1]` must be null-terminated
- `reserved_pad[0..1]` and `reserved[0..1]` must be 0

### 4.6 Program Configuration

**Structure:** `vmprog_program_config_v1_0` (7240 bytes)

Main program metadata structure:

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | char[64] | program_id | 64 | Unique program ID |
| 64 | uint16_t | program_version_major | 2 | Program version major |
| 66 | uint16_t | program_version_minor | 2 | Program version minor |
| 68 | uint16_t | program_version_patch | 2 | Program version patch |
| 70 | uint16_t | abi_min_major | 2 | Min ABI major version |
| 72 | uint16_t | abi_min_minor | 2 | Min ABI minor version |
| 74 | uint16_t | abi_max_major | 2 | Max ABI major (exclusive) |
| 76 | uint16_t | abi_max_minor | 2 | Max ABI minor (exclusive) |
| 78 | uint32_t | hw_mask | 4 | Hardware compatibility mask |
| 82 | char[32] | program_name | 32 | Display name |
| 114 | char[64] | author | 64 | Author name |
| 178 | char[32] | license | 32 | License identifier |
| 210 | char[32] | category | 32 | Program category |
| 242 | char[128] | description | 128 | Program description |
| 370 | uint16_t | parameter_count | 2 | Number of parameters |
| 372 | uint16_t | reserved_pad | 2 | Reserved padding |
| 374 | param[12] | parameters | 6864 | Parameter configs (12×572) |
| 7238 | uint8_t[2] | reserved | 2 | Reserved |

**Constants:**
- `program_id_max_length` = 64
- `program_name_max_length` = 32
- `author_max_length` = 64
- `license_max_length` = 32
- `category_max_length` = 32
- `description_max_length` = 128
- `num_parameters` = 12
- `struct_size` = 7240

**Validation:**
- `parameter_count` must be ≤ 12
- `abi_min_major` > 0 and `abi_max_major` > 0
- `abi_min_major` < `abi_max_major`, OR
  (`abi_min_major` == `abi_max_major` AND `abi_min_minor` < `abi_max_minor`)
- `hw_mask` must not be `none` (0)
- `program_id` must be null-terminated and non-empty
- `program_name` must be null-terminated and non-empty
- `author`, `license`, `category`, `description` must be null-terminated
- `reserved_pad` must be 0
- `reserved[0..1]` must be 0
- Each parameter `[0..parameter_count-1]` must pass validation

---

## 5. Validation Functions

All validation functions are inline and return `vmprog_validation_result`.

### 5.1 Header Validation

```cpp
vmprog_validation_result validate_vmprog_header_v1_0(
    const vmprog_header_v1_0& header,
    uint32_t file_size
);
```

**Checks:**
- Magic number (0x47504D56)
- Version (major must be 1)
- Header size (must be 64)
- File size (≥ 64, ≤ 64MB, matches header.file_size)
- TOC offset (≥ 64, < file_size)
- TOC size (must equal toc_count × 64, fits in file)
- TOC count (> 0, ≤ 256)

**Returns:** `ok` or specific error code

### 5.2 TOC Entry Validation

```cpp
vmprog_validation_result validate_vmprog_toc_entry_v1_0(
    const vmprog_toc_entry_v1_0& entry,
    uint32_t file_size
);
```

**Checks:**
- Entry type is not `none` (0)
- Offset is ≥ 64 and < file_size
- Size doesn't cause offset overflow
- Reserved fields are zeroed

**Returns:** `ok` or specific error code

### 5.3 Artifact Hash Validation

```cpp
vmprog_validation_result validate_vmprog_artifact_hash_v1_0(
    const vmprog_artifact_hash_v1_0& artifact
);
```

**Checks:**
- Type is valid (≤ 10)

**Returns:** `ok` or specific error code

### 5.4 Signed Descriptor Validation

```cpp
vmprog_validation_result validate_vmprog_signed_descriptor_v1_0(
    const vmprog_signed_descriptor_v1_0& descriptor
);
```

**Checks:**
- Artifact count ≤ 8
- Reserved padding is zeroed
- Used artifacts [0..count-1] have valid types
- Unused artifacts [count..7] are fully zeroed

**Returns:** `ok` or specific error code

### 5.5 Parameter Configuration Validation

```cpp
vmprog_validation_result validate_vmprog_parameter_config_v1_0(
    const vmprog_parameter_config_v1_0& param
);
```

**Checks:**
- Parameter ID ≤ 12
- Control mode ≤ 35
- Value label count ≤ 16
- Value ranges (min ≤ max, initial in range)
- Display ranges (min ≤ max)
- String null-termination
- Reserved fields zeroed

**Returns:** `ok` or specific error code

### 5.6 Program Configuration Validation

```cpp
vmprog_validation_result validate_vmprog_program_config_v1_0(
    const vmprog_program_config_v1_0& config
);
```

**Checks:**
- Parameter count ≤ 12
- ABI range validity
- Hardware mask not zero
- Required strings non-empty and null-terminated
- Reserved fields zeroed
- All parameters [0..count-1] valid

**Returns:** `ok` or specific error code

### 5.7 Comprehensive Package Validation

```cpp
vmprog_validation_result validate_vmprog_package(
    const uint8_t* file_data,
    uint32_t file_size,
    bool verify_hashes = true,
    bool verify_signature = false,
    const uint8_t* public_key = nullptr
);
```

**Performs:**
1. Header validation
2. All TOC entry validation
3. Optional: All payload hash verification
4. Optional: Package hash verification
5. Config validation (if present)
6. Signed descriptor validation (if present)
7. Optional: Ed25519 signature verification

**Parameters:**
- `file_data` - Complete file contents
- `file_size` - File size in bytes
- `verify_hashes` - If true, verify all hashes
- `verify_signature` - If true, verify Ed25519 signature
- `public_key` - Public key for signature (32 bytes, optional)

**Returns:** First error encountered, or `ok` if all checks pass

**Usage:**
```cpp
// Quick structural validation
auto result = validate_vmprog_package(data, size, false, false);

// Full validation with hash checking
auto result = validate_vmprog_package(data, size, true, false);

// Complete validation with signature
auto result = validate_vmprog_package(
    data, size, true, true, 
    lzx::vmprog_public_keys[0]
);
```

---

## 6. Cryptographic Functions

All cryptographic functions use the monocypher library (BLAKE2b-256 for hashing, Ed25519 for signatures).

### 6.1 Config Hash Calculation

```cpp
bool calculate_config_sha256(
    const vmprog_program_config_v1_0& config, 
    uint8_t* out_hash
);
```

Computes the SHA-256 hash of the program configuration. Creates a copy with all reserved fields zeroed before hashing.

**Parameters:**
- `config` - Program configuration to hash
- `out_hash` - Output buffer (must be 32 bytes)

**Returns:** `true` on success

**Notes:**
- Only hashes used parameters [0..parameter_count-1]
- Ensures deterministic hashing by zeroing reserved fields

### 6.2 Package Hash Calculation

```cpp
bool calculate_package_sha256(
    const uint8_t* file_data,
    uint32_t file_size,
    uint8_t* out_hash
);
```

Computes SHA-256 of entire file with `sha256_package` field zeroed.

**Parameters:**
- `file_data` - Complete file contents
- `file_size` - File size in bytes
- `out_hash` - Output buffer (must be 32 bytes)

**Returns:** `true` on success, `false` if file too small

**Algorithm:**
1. Hash bytes [0..31] (before sha256_package field)
2. Hash 32 zero bytes (in place of sha256_package)
3. Hash bytes [64..file_size-1] (after sha256_package)


### 6.3 Package Hash Verification

```cpp
bool verify_package_sha256(
    const uint8_t* file_data,
    uint32_t file_size
);
```

Verifies that `sha256_package` field in header matches computed hash.

**Parameters:**
- `file_data` - Complete file contents
- `file_size` - File size in bytes

**Returns:** `true` if hash matches, `false` otherwise

### 6.4 Ed25519 Signature Verification

```cpp
bool verify_ed25519_signature(
    const uint8_t signature[64],
    const uint8_t public_key[32],
    const vmprog_signed_descriptor_v1_0& signed_descriptor
);
```

Verifies Ed25519 signature over signed descriptor.

**Parameters:**
- `signature` - Ed25519 signature (64 bytes)
- `public_key` - Ed25519 public key (32 bytes)
- `signed_descriptor` - Descriptor structure (332 bytes)

**Returns:** `true` if signature valid, `false` otherwise

### 6.5 Payload Hash Verification

```cpp
bool verify_payload_hash(
    const uint8_t* payload_data,
    uint32_t payload_size,
    const uint8_t expected_hash[32]
);
```

Verifies payload data matches expected hash from TOC entry.

**Parameters:**
- `payload_data` - Payload bytes
- `payload_size` - Payload size in bytes
- `expected_hash` - Expected SHA-256 hash

**Returns:** `true` if hash matches

### 6.6 All Payload Hash Verification

```cpp
vmprog_validation_result verify_all_payload_hashes(
    const uint8_t* file_data,
    uint32_t file_size,
    const vmprog_header_v1_0& header
);
```

Verifies all TOC entry payload hashes in one pass.

**Parameters:**
- `file_data` - Complete file contents
- `file_size` - File size in bytes
- `header` - Validated header structure

**Returns:** `ok` if all hashes valid, error code otherwise

### 6.7 Arbitrary Data Hashing

```cpp
void calculate_data_hash(
    const uint8_t* data,
    uint32_t size,
    uint8_t out_hash[32]
);
```

Computes SHA-256 hash of arbitrary data.

**Parameters:**
- `data` - Data to hash
- `size` - Size in bytes
- `out_hash` - Output buffer (32 bytes)

### 6.8 Built-in Public Key Verification

```cpp
bool verify_with_builtin_keys(
    const uint8_t signature[64],
    const vmprog_signed_descriptor_v1_0& signed_descriptor,
    size_t* out_key_index = nullptr
);
```

Tries to verify signature against all built-in public keys.

**Parameters:**
- `signature` - Ed25519 signature (64 bytes)
- `signed_descriptor` - Descriptor to verify
- `out_key_index` - Optional output for which key succeeded

**Returns:** `true` if any built-in key verifies signature

**Usage:**
```cpp
size_t key_index;
if (verify_with_builtin_keys(sig, descriptor, &key_index)) {
    printf("Verified with key %zu\n", key_index);
}
```

### 6.9 Get Public Key Count

```cpp
constexpr size_t get_public_key_count();
```

Returns the number of built-in public keys.

**Returns:** Count of keys in `vmprog_public_keys` array

---

## 7. Helper Functions

### 7.1 String Helpers

#### Safe String Copy

```cpp
void safe_strncpy(char* dest, const char* src, size_t size);
```

Safely copies string with guaranteed null-termination and zero-padding.

**Parameters:**
- `dest` - Destination buffer
- `src` - Source null-terminated string
- `size` - Size of destination including null terminator

**Behavior:**
- Copies up to `size-1` characters
- Always null-terminates
- Zeros remaining bytes for determinism

#### String Termination Check

```cpp
bool is_string_terminated(const char* str, size_t size);
```

Checks if fixed-size buffer contains null-terminated string.

**Returns:** `true` if null terminator found within size

#### Safe String Length

```cpp
size_t safe_strlen(const char* str, size_t size);
```

Gets string length in fixed-size buffer.

**Returns:** Length without null terminator, or size if not terminated

#### String Empty Check

```cpp
bool is_string_empty(const char* str, size_t size);
```

Checks if string is empty (first char is null).

**Returns:** `true` if empty or invalid

#### Safe String Compare

```cpp
bool safe_strcmp(
    const char* str1, size_t size1,
    const char* str2, size_t size2
);
```

Safely compares two strings in fixed-size buffers.

**Returns:** `true` if strings are equal

### 7.2 TOC Helpers

#### Find TOC Entry

```cpp
const vmprog_toc_entry_v1_0* find_toc_entry(
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    vmprog_toc_entry_type_v1_0 type,
    uint32_t* out_index = nullptr
);
```

Finds first TOC entry of specified type.

**Parameters:**
- `toc` - TOC array pointer
- `toc_count` - Number of TOC entries
- `type` - Entry type to find
- `out_index` - Optional output for entry index

**Returns:** Pointer to entry if found, `nullptr` otherwise

#### Check TOC Entry Exists

```cpp
bool has_toc_entry(
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    vmprog_toc_entry_type_v1_0 type
);
```

Checks if TOC contains entry of specified type.

**Returns:** `true` if entry exists

#### Count TOC Entries

```cpp
uint32_t count_toc_entries(
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    vmprog_toc_entry_type_v1_0 type
);
```

Counts entries of specified type.

**Returns:** Number of matching entries

### 7.3 Package Integrity Helpers

#### Check if Signed

```cpp
bool is_package_signed(const vmprog_header_v1_0& header);
```

Checks if package has signed_pkg flag set.

**Returns:** `true` if package claims to be signed

#### Validation Result String

```cpp
const char* validation_result_string(vmprog_validation_result result);
```

Converts validation result code to human-readable string.

**Returns:** String description of error

**Example output:**
- `ok` → "OK"
- `invalid_magic` → "Invalid magic number"
- `invalid_hash` → "Invalid hash"

### 7.4 Structure Initialization Helpers

#### Initialize Header

```cpp
void init_vmprog_header(vmprog_header_v1_0& header);
```

Initializes header with default values:
- Magic: 0x47504D56
- Version: 1.0
- Header size: 64
- Flags: none
- All other fields: 0

#### Initialize Config

```cpp
void init_vmprog_config(vmprog_program_config_v1_0& config);
```

Initializes program config with defaults:
- Version: 1.0.0
- ABI range: [1.0, 2.0)
- Hardware: videomancer_core_rev_a
- Parameter count: 0

#### Initialize Signed Descriptor

```cpp
void init_signed_descriptor(vmprog_signed_descriptor_v1_0& descriptor);
```

Initializes descriptor with defaults:
- All fields: 0
- Flags: none
- Artifact count: 0

#### Initialize TOC Entry

```cpp
void init_toc_entry(vmprog_toc_entry_v1_0& entry);
```

Initializes TOC entry with defaults:
- Type: none
- Flags: none
- All other fields: 0

#### Initialize Parameter

```cpp
void init_parameter_config(vmprog_parameter_config_v1_0& param);
```

Initializes parameter with defaults:
- ID: none
- Control mode: linear
- Range: [0, 65535]
- Initial: 0
- Display range: [0, 100]
- Float digits: 0
- Value label count: 0

### 7.5 Endianness Conversion

#### 32-bit Conversion

```cpp
uint32_t to_little_endian_32(uint32_t value);
uint32_t from_little_endian_32(uint32_t value);
```

Converts 32-bit values to/from little-endian.

**Notes:**
- No-op on little-endian systems (x86, ARM)
- Byte-swaps on big-endian systems
- Symmetric operation (to and from are identical)

#### 16-bit Conversion

```cpp
uint16_t to_little_endian_16(uint16_t value);
uint16_t from_little_endian_16(uint16_t value);
```

Converts 16-bit values to/from little-endian.

---

## 8. Usage Examples

### 8.1 Example 1: Creating a Package

```cpp
// Initialize program configuration
lzx::vmprog_program_config_v1_0 config = {};

// Set string fields
lzx::safe_strncpy(config.program_id, "com.example.test", 
                  sizeof(config.program_id));
lzx::safe_strncpy(config.program_name, "My Test Program", 
                  sizeof(config.program_name));
lzx::safe_strncpy(config.author, "Test Author", 
                  sizeof(config.author));
lzx::safe_strncpy(config.description, "A simple test program", 
                  sizeof(config.description));

// Set version and ABI fields
config.program_version_major = 1;
config.program_version_minor = 0;
config.program_version_patch = 0;
config.abi_min_major = 1;
config.abi_min_minor = 0;
config.abi_max_major = 2;  // Exclusive upper bound
config.abi_max_minor = 0;

// Set hardware compatibility
config.hw_mask = lzx::vmprog_hardware_flags_v1_0::videomancer_core_rev_a;
config.parameter_count = 0; // No parameters for this example

// Validate configuration
auto result = lzx::validate_vmprog_program_config_v1_0(config);
if (result != lzx::vmprog_validation_result::ok) {
    printf("Config validation failed: %s\n", 
           lzx::validation_result_string(result));
    return;
}

// Create signed descriptor
lzx::vmprog_signed_descriptor_v1_0 descriptor = {};
lzx::calculate_config_sha256(config, descriptor.config_sha256);
descriptor.artifact_count = 1; // One FPGA bitstream
descriptor.artifacts[0].type = lzx::vmprog_toc_entry_type_v1_0::fpga_bitstream;
// ... set artifact hash ...

// Build complete package file (pseudo-code):
// 1. Write header with magic, version, sizes
// 2. Write TOC entries
// 3. Write signed descriptor
// 4. Write program config
// 5. Write signature (if signed)
// 6. Write FPGA bitstream payload
// 7. Calculate and update sha256_package in header
```

### 8.2 Example 2: Validating with Signature

```cpp
// Load file into memory
std::vector<uint8_t> file_data = load_vmprog_file("program.vmprog");

// Comprehensive validation with built-in public key
auto result = lzx::validate_vmprog_package(
    file_data.data(),
    file_data.size(),
    true,  // verify_hashes
    true,  // verify_signature
    lzx::vmprog_public_keys[0]  // Use first built-in public key
);

if (result != lzx::vmprog_validation_result::ok) {
    printf("Validation failed: %s\n", 
           lzx::validation_result_string(result));
    return;
}

// Package is valid and signature verified - safe to use
const auto* header = reinterpret_cast<const lzx::vmprog_header_v1_0*>(
    file_data.data());
const auto* toc = reinterpret_cast<const lzx::vmprog_toc_entry_v1_0*>(
    file_data.data() + header->toc_offset);

// Extract program configuration
const lzx::vmprog_toc_entry_v1_0* config_entry = lzx::find_toc_entry(
    toc, header->toc_count, lzx::vmprog_toc_entry_type_v1_0::config);

if (config_entry) {
    const auto* config = reinterpret_cast<const lzx::vmprog_program_config_v1_0*>(
        file_data.data() + config_entry->offset);
    // Use validated config...
    printf("Program: %s\n", config->program_name);
    printf("Author: %s\n", config->author);
}
```

### 8.3 Example 3: Manual Signature Verification

```cpp
// Load package
std::vector<uint8_t> file_data = load_vmprog_file("program.vmprog");
const auto* header = reinterpret_cast<const lzx::vmprog_header_v1_0*>(
    file_data.data());
const auto* toc = reinterpret_cast<const lzx::vmprog_toc_entry_v1_0*>(
    file_data.data() + header->toc_offset);

// Check if package is signed
if (!lzx::is_package_signed(*header)) {
    printf("Package is not signed\n");
    return;
}

// Find signed descriptor and signature entries
const lzx::vmprog_toc_entry_v1_0* desc_entry = lzx::find_toc_entry(
    toc, header->toc_count, 
    lzx::vmprog_toc_entry_type_v1_0::signed_descriptor);
const lzx::vmprog_toc_entry_v1_0* sig_entry = lzx::find_toc_entry(
    toc, header->toc_count, 
    lzx::vmprog_toc_entry_type_v1_0::signature);

if (!desc_entry || !sig_entry) {
    printf("Missing descriptor or signature\n");
    return;
}

const auto* descriptor = reinterpret_cast<const lzx::vmprog_signed_descriptor_v1_0*>(
    file_data.data() + desc_entry->offset);
const uint8_t* signature = file_data.data() + sig_entry->offset;

// Try each built-in public key
size_t key_index;
if (lzx::verify_with_builtin_keys(signature, *descriptor, &key_index)) {
    printf("Signature verified with public key %zu\n", key_index);
} else {
    printf("Signature verification failed\n");
    return;
}
```

### 8.4 Example 4: Working with Parameters

```cpp
// Load and validate package
std::vector<uint8_t> file_data = load_vmprog_file("program.vmprog");
auto result = lzx::validate_vmprog_package(file_data.data(), file_data.size());
if (result != lzx::vmprog_validation_result::ok) return;

// Get config
const auto* header = reinterpret_cast<const lzx::vmprog_header_v1_0*>(
    file_data.data());
const auto* toc = reinterpret_cast<const lzx::vmprog_toc_entry_v1_0*>(
    file_data.data() + header->toc_offset);
const auto* config_entry = lzx::find_toc_entry(
    toc, header->toc_count, lzx::vmprog_toc_entry_type_v1_0::config);
const auto* config = reinterpret_cast<const lzx::vmprog_program_config_v1_0*>(
    file_data.data() + config_entry->offset);

// Enumerate parameters
for (uint32_t i = 0; i < config->parameter_count; ++i) {
    const auto& param = config->parameters[i];
    
    printf("Parameter %u:\n", i);
    printf("  Name: %s\n", param.name_label);
    printf("  ID: %u\n", static_cast<uint32_t>(param.parameter_id));
    printf("  Range: [%u, %u]\n", param.min_value, param.max_value);
    printf("  Initial: %u\n", param.initial_value);
    printf("  Control mode: %u\n", static_cast<uint32_t>(param.control_mode));
    
    // Print value labels if any
    if (param.value_label_count > 0) {
        printf("  Value labels:\n");
        for (uint32_t j = 0; j < param.value_label_count; ++j) {
            printf("    %u: %s\n", j, param.value_labels[j]);
        }
    }
    
    if (param.suffix_label[0] != '\0') {
        printf("  Suffix: %s\n", param.suffix_label);
    }
}
```

---

## 9. Verification Procedures

### 9.1 Basic Validation Checklist

**Before trusting any package data:**

1. ✓ Verify magic number (0x47504D56)
2. ✓ Verify version (major must be 1)
3. ✓ Verify header size (must be 64)
4. ✓ Verify file size matches filesystem
5. ✓ Verify TOC is within file bounds
6. ✓ Verify all TOC entries are within file bounds
7. ✓ Verify all required TOC entries are present

**Use:** `validate_vmprog_header_v1_0()` for items 1-6

### 9.2 Integrity Verification Checklist

**For tamper detection:**

1. ✓ Compute SHA-256 of each payload
2. ✓ Compare with TOC entry hash
3. ✓ Reject if any hash mismatch
4. ✓ If sha256_package present, verify package hash
5. ✓ Verify config structure
6. ✓ Verify signed descriptor structure

**Use:** `validate_vmprog_package()` with `verify_hashes=true`

### 9.3 Signature Verification Checklist

**For authentication:**

1. ✓ Check `signed_pkg` flag in header
2. ✓ Locate `signed_descriptor` TOC entry (type 2)
3. ✓ Locate `signature` TOC entry (type 3)
4. ✓ Verify descriptor size (must be 332 bytes)
5. ✓ Verify signature size (must be 64 bytes)
6. ✓ Verify descriptor hash from TOC matches
7. ✓ Verify Ed25519 signature with public key
8. ✓ Verify all artifact hashes in descriptor match TOC
9. ✓ Verify config hash in descriptor matches actual config

**Use:** `validate_vmprog_package()` with `verify_signature=true`

**Recommended public key verification:**
```cpp
// Try all built-in keys
bool verified = lzx::verify_with_builtin_keys(signature, descriptor);

// Or use specific key
bool verified = lzx::verify_ed25519_signature(
    signature, 
    lzx::vmprog_public_keys[0], 
    descriptor
);
```

### 9.4 Compatibility Verification Checklist

**Before loading program:**

1. ✓ Read `abi_min_major/minor` and `abi_max_major/minor`
2. ✓ Check firmware ABI is in range: `abi_min ≤ firmware_abi < abi_max`
3. ✓ Read `hw_mask` from config
4. ✓ Check hardware match: `(hw_mask & device_hw_flags) != 0`
5. ✓ Verify all referenced bitstream types are available

**Example:**
```cpp
bool is_compatible(const lzx::vmprog_program_config_v1_0& config) {
    // Check ABI
    uint16_t fw_abi_major = 1;
    uint16_t fw_abi_minor = 5;
    
    if (fw_abi_major < config.abi_min_major) return false;
    if (fw_abi_major == config.abi_min_major && 
        fw_abi_minor < config.abi_min_minor) return false;
    if (fw_abi_major >= config.abi_max_major) return false;
    if (fw_abi_major == config.abi_max_major && 
        fw_abi_minor >= config.abi_max_minor) return false;
    
    // Check hardware
    auto device_hw = lzx::vmprog_hardware_flags_v1_0::videomancer_core_rev_a;
    if ((config.hw_mask & device_hw) == lzx::vmprog_hardware_flags_v1_0::none) {
        return false;
    }
    
    return true;
}
```

### 9.5 Program Classification

Based on verification results, classify packages:

| Verification Status | Classification | Trust Level |
|---------------------|----------------|-------------|
| Valid signature from built-in key | **Official Verified** | ✓✓✓ High |
| Valid signature from user key | **Community Verified** | ✓✓ Medium |
| No signature, valid hashes | **Community Unsigned** | ✓ Low |
| Invalid signature | **Tampered/Malicious** | ✗ Reject |
| Invalid hashes | **Corrupted** | ✗ Reject |
| Invalid structure | **Malformed** | ✗ Reject |

**Recommended UI indicators:**
- Official Verified: Green checkmark, "Official"
- Community Verified: Blue checkmark, "Verified"
- Community Unsigned: Yellow caution, "Unsigned"
- Tampered: Red X, "Invalid Signature - DO NOT USE"
- Corrupted: Red X, "File Corrupted"

---

## 10. Implementation Guidelines

### 10.1 Structure Packing

**Critical:** All structures use `#pragma pack(1)`:

```cpp
#pragma pack(push, 1)
struct vmprog_header_v1_0 {
    // fields...
};
#pragma pack(pop)
```

**Verification:**
```cpp
static_assert(sizeof(vmprog_header_v1_0) == 64, "Size mismatch");
static_assert(offsetof(vmprog_header_v1_0, magic) == 0, "Offset mismatch");
```

### 10.2 Endianness

**All multi-byte integers are little-endian:**

- Use provided conversion functions on big-endian systems
- `to_little_endian_32()` and `to_little_endian_16()`
- No-op on little-endian systems (x86, ARM)

### 10.3 Reserved Fields

**Rules for reserved fields:**

- **Writing:** Must set to zero
- **Reading:** Should ignore (don't fail if non-zero)
- **Future:** May be assigned meaning in minor version updates

**Example:**
```cpp
config.reserved[0] = 0;
config.reserved[1] = 0;
config.reserved_pad = 0;
```

### 10.4 String Handling

**All strings must be:**

- Null-terminated UTF-8
- Use `safe_strncpy()` for setting
- Validate with `is_string_terminated()`
- Unused bytes should be zeroed

**Example:**
```cpp
// Correct
lzx::safe_strncpy(config.program_name, "My Program", 
                  sizeof(config.program_name));

// Wrong - may not null-terminate
strncpy(config.program_name, "My Program", sizeof(config.program_name));
```

### 10.5 Hash Calculation Order

**When creating packages:**

1. Build all payloads (config, bitstreams)
2. Calculate config hash → put in descriptor
3. Calculate payload hashes → put in TOC
4. Calculate descriptor hash → put in TOC
5. Sign descriptor → create signature payload
6. Calculate package hash → put in header

### 10.6 TOC Entry Ordering

**Recommended order for determinism:**

1. `config` (type 1)
2. `signed_descriptor` (type 2)
3. `signature` (type 3)
4. Bitstreams (types 4-10, sorted by type)

**Note:** Order is not enforced, but consistency aids reproducibility.

### 10.7 Error Handling

**Validation failures:**

```cpp
auto result = lzx::validate_vmprog_package(data, size);
if (result != lzx::vmprog_validation_result::ok) {
    fprintf(stderr, "Validation failed: %s\n", 
            lzx::validation_result_string(result));
    // Log error, display to user, reject package
    return false;
}
```

**Cryptographic failures:**

```cpp
if (!lzx::verify_package_sha256(data, size)) {
    // Package tampered or corrupted
    return false;
}

if (!lzx::verify_with_builtin_keys(sig, descriptor)) {
    // Unknown or invalid signature
    return false;
}
```

### 10.8 Memory Safety

**Buffer safety:**

- All fixed-size string buffers include space for null terminator
- Use `safe_strlen()` instead of `strlen()` on untrusted data
- Always validate bounds before pointer arithmetic
- Use provided validation functions before trusting struct contents

**Example:**
```cpp
// Safe
if (lzx::is_string_terminated(config.program_name, 
                               sizeof(config.program_name))) {
    printf("%s\n", config.program_name);
}

// Unsafe - untrusted data might not be null-terminated
printf("%s\n", config.program_name);  // DANGEROUS
```

### 10.9 Deterministic Builds

**For reproducible signing:**

1. Sort TOC entries in canonical order
2. Zero all reserved and padding fields
3. Use fixed timestamps (or omit)
4. Use deterministic bitstream generation
5. Verify `calculate_config_sha256()` gives same result

### 10.10 Performance Considerations

**Optimization tips:**

- Validate structure before hash verification (cheaper)
- Cache validation results for repeated access
- Use `mmap()` for large files on systems that support it
- Validate TOC entries on-demand, not all at once
- Skip hash verification for development/testing (but never production)

---

## 11. References

### 11.1 Canonical Implementation

- **Header file:** [src/security/vmprog_format.hpp](../src/security/vmprog_format.hpp)
- **Crypto wrapper:** [src/security/vmprog_crypto.hpp](../src/security/vmprog_crypto.hpp)
- **Public keys:** [src/security/vmprog_public_keys.hpp](../src/security/vmprog_public_keys.hpp)

### 11.2 Cryptographic Standards

- **SHA-256:** FIPS 180-4 (using BLAKE2b-256 as equivalent)
- **Ed25519:** RFC 8032 (EdDSA signature scheme)
- **Cryptographic library:** Monocypher 4.x

### 11.3 Related Documentation

- **ABI Specification:** [docs/fpga-kernel-abi.md](fpga-kernel-abi.md)
- **Key Management:** [docs/keys.md](keys.md)
- **Compatibility:** [docs/abi-and-compatibility.md](abi-and-compatibility.md)

### 11.4 Tools

- **Package creator:** `scripts/pack_vmprog/`
- **Signature tools:** `scripts/gen_signed_descriptor/`
- **Verification tools:** Built into firmware

### 11.5 Static Assertions

The header file contains comprehensive compile-time checks:

- Structure sizes (must match `struct_size` constants)
- Field offsets (must match binary layout)
- Alignment (must be 32-bit aligned)
- Array dimensions (must match constants)
- Enum sizes (must be uint32_t)
- Magic numbers (must be correct values)
- String buffer sizes (must match constants)

**Example:**
```cpp
static_assert(sizeof(vmprog_header_v1_0) == 64, 
              "Header size mismatch");
static_assert(offsetof(vmprog_header_v1_0, magic) == 0, 
              "Magic must be at offset 0");
```

### 11.6 Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2024-2025 | Initial production release |

**Version numbering:**
- **Major:** Breaking changes (incompatible format changes)
- **Minor:** Backward-compatible additions (new optional features)
- **Patch:** Bug fixes (no format changes)

**Compatibility policy:**
- Readers must support their own major version
- Readers should gracefully handle newer minor versions
- Readers must reject different major versions

---

## Appendix A: Structure Size Summary

| Structure | Size (bytes) | Alignment |
|-----------|-------------:|-----------|
| `vmprog_header_v1_0` | 64 | 4-byte |
| `vmprog_toc_entry_v1_0` | 64 | 4-byte |
| `vmprog_artifact_hash_v1_0` | 36 | 4-byte |
| `vmprog_signed_descriptor_v1_0` | 332 | 4-byte |
| `vmprog_parameter_config_v1_0` | 572 | 4-byte |
| `vmprog_program_config_v1_0` | 7240 | 4-byte |
| Ed25519 signature | 64 | - |
| Ed25519 public key | 32 | - |
| SHA-256 hash | 32 | - |

**Total fixed overhead (minimum):**
- Header: 64 bytes
- Config TOC entry: 64 bytes  
- Descriptor TOC entry: 64 bytes
- Signature TOC entry: 64 bytes
- Bitstream TOC entry: 64 bytes (minimum 1)
- Config payload: 7240 bytes
- Descriptor payload: 332 bytes
- Signature payload: 64 bytes

**Minimum viable package:** ~8,016 bytes + bitstream(s)

---

## Appendix B: Quick Reference

### Magic Numbers

```
File header:  0x47504D56  ('VMPG' little-endian)
```

### Version Check

```cpp
if (header.magic != 0x47504D56u) return error;
if (header.version_major != 1) return error;
```

### Quick Validation

```cpp
auto result = lzx::validate_vmprog_package(data, size, true, true, pubkey);
if (result != lzx::vmprog_validation_result::ok) return error;
```

### Find Config

```cpp
auto* config_entry = lzx::find_toc_entry(toc, count, 
    lzx::vmprog_toc_entry_type_v1_0::config);
auto* config = (vmprog_program_config_v1_0*)(data + config_entry->offset);
```

### Verify Signature

```cpp
bool ok = lzx::verify_with_builtin_keys(signature, descriptor);
```

---

**Document Version:** 2.0  
**Last Updated:** 2025-01-14  
**Maintainer:** LZX Industries LLC

| Offset | Size | Type     | Field              | Description                                           |
| -----: | ---: | -------- | ------------------ | ----------------------------------------------------- |
|   0x00 |    4 | uint32_t | magic              | Magic number `0x47504D56` (`'VMPG'`)                  |
|   0x04 |    2 | uint16_t | version            | Format version (1)                                    |
|   0x06 |    2 | uint16_t | header_size        | Header size in bytes (64)                             |
|   0x08 |    4 | uint32_t | file_size          | Total size of .vmprog file in bytes                   |
|   0x0C |    4 | uint32_t | flags              | Header flags (see Header Flags)                       |
|   0x10 |    4 | uint32_t | toc_offset         | Byte offset to TOC from file start                    |
|   0x14 |    4 | uint32_t | toc_bytes          | Size of TOC in bytes                                  |
|   0x18 |    4 | uint32_t | toc_count          | Number of TOC entries                                 |
|   0x1C |   32 | uint8_t  | sha256_package[32] | Optional SHA-256 of entire file (with this field = 0) |
|   0x3C |    4 | uint32_t | reserved           | Reserved for future use (must be 0)                   |

### 2.2 Header Flags: `vmprog_header_flags_v1`

| Value      | Name       | Description                         |
| ---------: | ---------- | ----------------------------------- |
| 0x00000000 | none       | No flags set                        |
| 0x00000001 | signed_pkg | Package is cryptographically signed |

---

## 3. Table of Contents (TOC)

### 3.1 Structure: `vmprog_toc_entry_v1` (64 bytes)

Each TOC entry describes one payload item.

| Offset | Size | Type     | Field         | Description                       |
| -----: | ---: | -------- | ------------- | --------------------------------- |
|   0x00 |    4 | uint32_t | type          | Entry type (see TOC Entry Types)  |
|   0x04 |    4 | uint32_t | flags         | Entry flags                       |
|   0x08 |    4 | uint32_t | offset        | Byte offset to payload from start |
|   0x0C |    4 | uint32_t | size          | Size of payload in bytes          |
|   0x10 |   32 | uint8_t  | sha256[32]    | SHA-256 hash of payload           |
|   0x30 |   16 | uint32_t | reserved[4]   | Reserved for future use (zeros)   |

### 3.2 TOC Entry Types: `vmprog_toc_entry_type_v1`

| Value | Name                  | Description                |
| ----: | --------------------- | -------------------------- |
|     0 | none                  | Invalid/empty entry        |
|     1 | config                | Program configuration      |
|     2 | signed_descriptor     | Signature descriptor       |
|     3 | signature             | Ed25519 signature          |
|     4 | bitstream_sd_analog   | SD analog input bitstream  |
|     5 | bitstream_sd_hdmi     | SD HDMI input bitstream    |
|     6 | bitstream_sd_dual     | SD dual input bitstream    |
|     7 | bitstream_hd_analog   | HD analog input bitstream  |
|     8 | bitstream_hd_hdmi     | HD HDMI input bitstream    |
|     9 | bitstream_hd_dual     | HD dual input bitstream    |

### 3.3 TOC Entry Flags: `vmprog_toc_entry_flags_v1`

| Value      | Name | Description  |
| ---------: | ---- | ------------ |
| 0x00000000 | none | No flags set |

---

## 4. Program Configuration (512 bytes)

### 4.1 Structure: `vmprog_config_v1`

The program configuration is a fixed-size binary structure containing program metadata.

| Field             | Type            | Size  | Description                         |
| ----------------- | --------------- | ----: | ----------------------------------- |
| manifest_version  | uint32_t        |     4 | Manifest format version             |
| program_name      | char[]          |    64 | Display name                        |
| program_id        | char[]          |    64 | Unique program identifier           |
| program_version   | char[]          |    16 | Version string                      |
| author            | char[]          |    64 | Author name                         |
| license           | char[]          |    32 | License identifier                  |
| category          | char[]          |    24 | Program category                    |
| description       | char[]          |   128 | Program description                 |
| hardware          | char[4][24]     |    96 | Compatible hardware list (max 4)    |
| hardware_count    | uint32_t        |     4 | Number of hardware entries          |
| kernel_abi        | char[]          |    24 | Required kernel ABI                 |
| video_modes       | char[8][16]     |   128 | Supported video modes (max 8)       |
| video_modes_count | uint32_t        |     4 | Number of video mode entries        |
| bram_kbits        | uint32_t        |     4 | BRAM usage in kilobits              |
| dsp_blocks        | uint32_t        |     4 | DSP block usage                     |
| max_fclk_mhz      | uint32_t        |     4 | Maximum FCLK in MHz                 |
| latency_frames    | uint32_t        |     4 | Processing latency in frames        |
| linear            | uint32_t        |     4 | Number of linear controls           |
| boolean           | uint32_t        |     4 | Number of boolean controls          |
| lin_labels        | char[8][16]     |   128 | Linear control labels (max 8)       |
| lin_labels_count  | uint32_t        |     4 | Number of linear labels             |
| bool_labels       | char[8][16]     |   128 | Boolean control labels (max 8)      |
| bool_labels_count | uint32_t        |     4 | Number of boolean labels            |
| bitstream_path    | char[]          |    64 | Original bitstream file path        |
| icon_path         | char[]          |    64 | Original icon file path             |
| readme_path       | char[]          |    64 | Original readme file path           |
| signed_flag       | bool            |     1 | Indicates if package should be signed |
| signature_path    | char[]          |    64 | Original signature file path        |
| descriptor_path   | char[]          |    64 | Original descriptor file path       |

**Total Size:** 512 bytes

All string fields are null-terminated UTF-8. Unused array entries must be zeroed.

---

## 5. Signed Descriptor (432 bytes)

### 5.1 Structure: `vmprog_signed_descriptor_v1`

The signed descriptor is a **deterministic binary structure** that is cryptographically signed. It contains the authoritative identity and compatibility information for the program.

| Offset | Size | Type            | Field            | Description                              |
| -----: | ---: | --------------- | ---------------- | ---------------------------------------- |
|   0x00 |    4 | uint32_t        | magic            | Magic number `0x44534D56` (`'VMSD'`)     |
|   0x04 |    2 | uint16_t        | version          | Descriptor version (1)                   |
|   0x06 |    2 | uint16_t        | reserved[1]      | Reserved (must be 0)                     |
|   0x08 |   64 | char[]          | program_id       | Unique program identifier                |
|   0x48 |   16 | char[]          | program_version  | Version string                           |
|   0x58 |    2 | uint16_t        | abi_min_major    | Minimum ABI major version                |
|   0x5A |    2 | uint16_t        | abi_min_minor    | Minimum ABI minor version                |
|   0x5C |    2 | uint16_t        | abi_max_major    | Maximum ABI major version (exclusive)    |
|   0x5E |    2 | uint16_t        | abi_max_minor    | Maximum ABI minor version (exclusive)    |
|   0x60 |    4 | uint32_t        | hw_mask          | Compatible hardware mask                 |
|   0x64 |    1 | uint8_t         | artifact_count   | Number of valid artifacts (0-8)          |
|   0x65 |    3 | uint8_t         | reserved_pad[3]  | Reserved padding                         |
|   0x68 |  320 | artifact_hash[] | artifacts[8]     | Array of artifact hashes (8×40 bytes)    |
|  0x1A8 |    4 | uint32_t        | flags            | Descriptor flags                         |
|  0x1AC |    4 | uint32_t        | build_id         | Build identifier                         |

**Total Size:** 432 bytes

### 5.2 Signed Descriptor Constants

- **Magic:** `0x44534D56` (`'VMSD'` in little-endian)
- **Version:** `1`
- **Max Artifacts:** `8`
- **Size:** `432` bytes (fixed)

### 5.3 Artifact Hash Entry: `vmprog_artifact_hash_v1` (40 bytes)

Each artifact hash entry links a TOC entry to its expected hash.

| Offset | Size | Type     | Field         | Description               |
| -----: | ---: | -------- | ------------- | ------------------------- |
|   0x00 |    4 | uint32_t | type          | Artifact type (TOC type)  |
|   0x04 |   32 | uint8_t  | sha256[32]    | SHA-256 hash of artifact  |
|   0x24 |    4 | uint32_t | reserved[1]   | Reserved (must be 0)      |

**Note:** Only entries `[0..artifact_count-1]` are valid. Entries `[artifact_count..7]` must be zeroed.

### 5.4 Hardware Flags: `vmprog_hardware_flags_v1`

| Value      | Name                     | Description             |
| ---------: | ------------------------ | ----------------------- |
| 0x00000000 | none                     | No hardware specified   |
| 0x00000001 | videomancer_core_rev_a   | Videomancer Core Rev A  |
| 0x00000002 | videomancer_core_rev_b   | Videomancer Core Rev B  |

### 5.5 Signed Descriptor Flags: `vmprog_signed_descriptor_flags_v1`

| Value      | Name | Description  |
| ---------: | ---- | ------------ |
| 0x00000000 | none | No flags set |

---

## 6. Signature

### 6.1 Format

- **Algorithm:** Ed25519
- **Size:** Exactly 64 bytes
- **Signature covers:** The entire `vmprog_signed_descriptor_v1` structure (432 bytes)

The signature is stored as a TOC entry of type `signature` (3).

---

## 7. Integrity and Authentication

### 7.1 Per-Item Integrity

Each TOC entry includes a SHA-256 hash of its payload. Readers **must verify** these hashes before using payload data.

### 7.2 Package-Level Integrity

The optional `sha256_package` field in the header contains the SHA-256 hash of the entire file, computed with this field set to all zeros.

### 7.3 Cryptographic Signing

For signed packages:

1. The `signed_pkg` flag (0x00000001) is set in the header
2. A `signed_descriptor` TOC entry (type 2) contains the descriptor
3. A `signature` TOC entry (type 3) contains the Ed25519 signature
4. The signature is verified against the descriptor bytes
5. Descriptor artifact hashes are compared against TOC entry hashes

---

## 8. Verification Procedure

### 8.1 Basic Validation

1. Verify magic number is `0x47504D56`
2. Verify version is `1`
3. Verify header_size is `64`
4. Verify file_size matches actual file size
5. Verify TOC offset and size are within file bounds
6. Verify all TOC entry offsets and sizes are within file bounds

### 8.2 Integrity Verification

1. For each required TOC entry:
   - Read payload at specified offset
   - Compute SHA-256 hash
   - Compare to hash in TOC entry
   - Reject if mismatch

### 8.3 Signature Verification (if signed_pkg flag set)

1. Locate `signed_descriptor` TOC entry (type 2)
2. Locate `signature` TOC entry (type 3)
3. Read and verify descriptor hash from TOC
4. Read signature (must be exactly 64 bytes)
5. Verify Ed25519 signature over descriptor
6. For each artifact in descriptor:
   - Find matching TOC entry by type
   - Verify TOC hash matches descriptor hash
7. Reject package if signature or hashes invalid

### 8.4 Compatibility Verification

1. Read descriptor `abi_min_major` and `abi_max_major`
2. Verify firmware ABI is within range: `abi_min <= firmware_abi < abi_max`
3. Verify hardware compatibility: `(hw_mask & device_hw_flags) != 0`
4. Reject if incompatible

### 8.5 Program Classification

Based on verification results:

- **Official Verified:** Signed package with valid signature from trusted key
- **Community Unsigned:** Valid package without signature
- **Tampered/Invalid:** Signature present but verification failed

---

## 9. Implementation Notes

### 9.1 Struct Packing

All structures use `#pragma pack(push, 1)` for byte-aligned packing with no padding.

### 9.2 Reserved Fields

All reserved fields **must** be set to zero when creating packages and **should** be ignored when reading packages.

### 9.3 String Encoding

All string fields are null-terminated UTF-8. Unused portions of fixed-size string fields must be zeroed.

### 9.4 Determinism

Signed packages must be deterministic:

- TOC entries in canonical order
- All padding and reserved fields zeroed
- Descriptor bytes are canonical

Identical source inputs must produce identical binary outputs.

---

## 10. References

- **Canonical Implementation:** [src/security/vmprog_format.hpp](../src/security/vmprog_format.hpp)
- **SHA-256:** FIPS 180-4
- **Ed25519:** RFC 8032
- **Cryptographic Library:** Monocypher

---

## 11. Version History

| Version | Date       | Description                  |
| ------: | ---------- | ---------------------------- |
|     1.0 | 2024-2025  | Initial stable specification |
