# Videomancer Program Package Format (`.vmprog`)

**Version:** 1.0  
**Status:** Production  
**Canonical Reference:** [src/lzx/videomancer/vmprog_format.hpp](../src/lzx/videomancer/vmprog_format.hpp)  
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

Binary container for FPGA programs with cryptographic verification (Ed25519 + SHA-256), hardware compatibility checking, ABI management, and user parameter configuration.

**Properties:** Version 1.0 | 1 MB max | Little-endian | Packed structures | UTF-8 strings  
**Extension:** `.vmprog` | MIME: `application/x-vmprog` (proposed)

---

## 2. File Structure

### 2.1 Layout Overview

```text
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
│ Payload: Program Config (7368 bytes)    │
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

```text
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
- **Maximum file size:** 1,048,576 bytes (1 MB)
- **Program config:** Fixed 7,240 bytes
- **Signed descriptor:** Fixed 332 bytes
- **Ed25519 signature:** Fixed 64 bytes

---

## 3. Data Types and Enumerations

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
- `max_file_size` = 1048576u (1 MB)
- `default_version_major` = 1
- `default_version_minor` = 0
- `struct_size` = 64



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



### 4.3 Artifact Hash

**Structure:** `vmprog_artifact_hash_v1_0` (36 bytes)

Used in signed descriptors to link artifacts:

| Offset | Type | Field | Size | Description |
|-------:|------|-------|-----:|-------------|
| 0 | uint32_t | type | 4 | Artifact type |
| 4 | uint8_t[32] | sha256 | 32 | SHA-256 hash |

**Constants:**

- `struct_size` = 36



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

**Notes:** Signed by Ed25519. Signature stored as separate TOC entry.

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
| 14 | int16_t | display_min_value | 2 | Display range minimum |
| 16 | int16_t | display_max_value | 2 | Display range maximum |
| 18 | uint8_t | display_float_digits | 1 | Decimal places for display |
| 19 | uint8_t | value_label_count | 1 | Number of value labels |
| 20 | uint8_t[2] | reserved_pad | 2 | Reserved padding |
| 22 | char[32] | name_label | 32 | Parameter name |
| 54 | char\[16\]\[32\] | value_labels | 512 | Value label strings |
| 566 | char[4] | suffix_label | 4 | Unit suffix (e.g., "°") |
| 570 | uint8_t[2] | reserved | 2 | Reserved |

**Constants:**

- `name_label_max_length` = 32
- `value_label_max_length` = 32
- `suffix_label_max_length` = 4
- `max_value_labels` = 16
- `struct_size` = 572



### 4.6 Program Configuration

**Structure:** `vmprog_program_config_v1_0` (7368 bytes)

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
| 370 | char[128] | url | 128 | Project or documentation URL |
| 498 | uint16_t | parameter_count | 2 | Number of parameters |
| 500 | uint16_t | reserved_pad | 2 | Reserved padding |
| 502 | param[12] | parameters | 6864 | Parameter configs (12×572) |
| 7366 | uint8_t[2] | reserved | 2 | Reserved |

**Constants:**

- `program_id_max_length` = 64
- `program_name_max_length` = 32
- `author_max_length` = 64
- `license_max_length` = 32
- `category_max_length` = 32
- `description_max_length` = 128
- `url_max_length` = 128
- `num_parameters` = 12
- `struct_size` = 7368



---

## 5. Validation Functions

All validation functions are inline and return `vmprog_validation_result`.

### 5.1 Individual Structure Validation

```cpp
vmprog_validation_result validate_vmprog_header_v1_0(const vmprog_header_v1_0& header, uint32_t file_size);
vmprog_validation_result validate_vmprog_toc_entry_v1_0(const vmprog_toc_entry_v1_0& entry, uint32_t file_size);
vmprog_validation_result validate_vmprog_artifact_hash_v1_0(const vmprog_artifact_hash_v1_0& artifact);
vmprog_validation_result validate_vmprog_signed_descriptor_v1_0(const vmprog_signed_descriptor_v1_0& descriptor);
vmprog_validation_result validate_vmprog_parameter_config_v1_0(const vmprog_parameter_config_v1_0& param);
vmprog_validation_result validate_vmprog_program_config_v1_0(const vmprog_program_config_v1_0& config);
```

Validates individual structures. Returns `ok` or error code.

### 5.2 Comprehensive Package Validation

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

### 6.1 Hash Functions

```cpp
bool calculate_config_sha256(const vmprog_program_config_v1_0& config, uint8_t* out_hash);
bool calculate_package_sha256(const uint8_t* file_data, uint32_t file_size, uint8_t* out_hash);
bool verify_package_sha256(const uint8_t* file_data, uint32_t file_size);
bool verify_payload_hash(const uint8_t* payload_data, uint32_t payload_size, const uint8_t expected_hash[32]);
vmprog_validation_result verify_all_payload_hashes(const uint8_t* file_data, uint32_t file_size, const vmprog_header_v1_0& header);
void calculate_data_hash(const uint8_t* data, uint32_t size, uint8_t out_hash[32]);
```

SHA-256 hashing and verification. All `out_hash` buffers must be 32 bytes.

### 6.2 Signature Functions

```cpp
bool verify_ed25519_signature(const uint8_t signature[64], const uint8_t public_key[32], const vmprog_signed_descriptor_v1_0& signed_descriptor);
bool verify_with_builtin_keys(const uint8_t signature[64], const vmprog_signed_descriptor_v1_0& signed_descriptor, size_t* out_key_index = nullptr);
constexpr size_t get_public_key_count();
```

Ed25519 signature verification. `verify_with_builtin_keys` tries all built-in keys.



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

### 9.1 Validation Levels

**Basic:** `validate_vmprog_package(data, size, false, false)` - Structure only  
**Integrity:** `validate_vmprog_package(data, size, true, false)` - Structure + hashes  
**Authenticated:** `validate_vmprog_package(data, size, true, true, pubkey)` - Full verification

### 9.2 Compatibility Check

```cpp
bool is_compatible(const vmprog_program_config_v1_0& config, 
                   uint16_t fw_abi_maj, uint16_t fw_abi_min, 
                   vmprog_hardware_flags_v1_0 device_hw) {
    // ABI range check
    if (fw_abi_maj < config.abi_min_major || fw_abi_maj >= config.abi_max_major) return false;
    if (fw_abi_maj == config.abi_min_major && fw_abi_min < config.abi_min_minor) return false;
    if (fw_abi_maj == config.abi_max_major && fw_abi_min >= config.abi_max_minor) return false;
    
    // Hardware check
    return (config.hw_mask & device_hw) != vmprog_hardware_flags_v1_0::none;
}
```

### 9.3 Trust Levels

| Verification | Classification | Use |
|--------------|----------------|-----|
| Valid signature (built-in key) | Official | High trust |
| Valid signature (user key) | Verified | Medium trust |
| No signature, valid hashes | Unsigned | Low trust |
| Invalid signature/hash | Reject | Do not use |

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

**Implementation:** [vmprog_format.hpp](../src/lzx/videomancer/vmprog_format.hpp) | [vmprog_crypto.hpp](../src/lzx/videomancer/vmprog_crypto.hpp) | [vmprog_public_keys.hpp](../src/lzx/videomancer/vmprog_public_keys.hpp)

**Standards:** SHA-256 (FIPS 180-4) | Ed25519 (RFC 8032) | Monocypher 4.x

**Version:** 1.0 (2024-2025) - Initial production release
