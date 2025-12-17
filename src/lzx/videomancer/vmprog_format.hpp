// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_format.hpp - VMProg Package Format Specification
// License: GNU General Public License v3.0
// https://github.com/lzxindustries/videomancer-sdk
//
// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//
// Format Overview:
//   - Version 1.0 specification (.vmprog file extension)
//   - Structure: 64-byte header + variable-length TOC + payload sections
//   - All multi-byte integers are little-endian
//   - All structures are packed with #pragma pack(1)
//   - Maximum recommended file size: 64 MB
//
// Magic Number:
//   - Package header: 'VMPG' = 0x47504D56 (little-endian)
//
// Versioning Strategy:
//   - Format versions use major.minor numbering (currently 1.0)
//   - Backward compatible changes increment minor version (e.g., 1.0 → 1.1)
//   - Breaking changes increment major version (e.g., 1.x → 2.0)
//   - Readers must check version_major matches; may support older minor versions
//
// Security:
//   - SHA-256 hashes provide integrity checking
//   - config_sha256: Hash of entire vmprog_program_config_v1_0 struct (with reserved fields zeroed)
//   - sha256 (TOC entry): Hash of payload data at specified offset/size
//   - sha256_package (header): Hash of entire file with this field zeroed
//   - Signature format: Ed25519 (64 bytes), signs the signed_descriptor
//
// String Handling:
//   - All char[] fields must be null-terminated
//   - If string fills buffer, last byte must be '\0' (truncate content by 1)
//   - Use provided safe_strncpy() helper to set strings
//
// Validation:
//   - Use validate_*() functions before trusting struct data
//   - All count fields (artifact_count, parameter_count, etc.) have defined maximums

#pragma once

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <type_traits>

#include "vmprog_crypto.hpp"
#include "vmprog_public_keys.hpp"

namespace lzx {

    // =============================================================================
    // Validation Result Codes
    // =============================================================================

    enum class vmprog_validation_result : uint32_t
    {
        ok = 0,
        invalid_magic = 1,
        invalid_version = 2,
        invalid_header_size = 3,
        invalid_file_size = 4,
        invalid_toc_offset = 5,
        invalid_toc_size = 6,
        invalid_toc_count = 7,
        invalid_artifact_count = 8,
        invalid_parameter_count = 9,
        invalid_value_label_count = 10,
        invalid_abi_range = 11,
        string_not_terminated = 12,
        invalid_hash = 13,
        invalid_toc_entry = 14,
        invalid_payload_offset = 15,
        invalid_parameter_values = 16,
        invalid_enum_value = 17,
        reserved_field_not_zero = 18,
    };

    // =============================================================================
    // Enumerations
    // =============================================================================

    // TOC entry type identifiers
    enum class vmprog_toc_entry_type_v1_0 : uint32_t
    {
        none = 0,
        config = 1,
        signed_descriptor = 2,
        signature = 3,
        fpga_bitstream = 4,  // Generic FPGA bitstream (use when variant doesn't matter)
        bitstream_sd_analog = 5,
        bitstream_sd_hdmi = 6,
        bitstream_sd_dual = 7,
        bitstream_hd_analog = 8,
        bitstream_hd_hdmi = 9,
        bitstream_hd_dual = 10,
    };

    // Package header flags
    enum class vmprog_header_flags_v1_0 : uint32_t
    {
        none = 0x00000000,
        signed_pkg = 0x00000001,
    };

    // TOC entry flags
    enum class vmprog_toc_entry_flags_v1_0 : uint32_t
    {
        none = 0x00000000
    };

    // Signed descriptor flags
    enum class vmprog_signed_descriptor_flags_v1_0 : uint32_t
    {
        none = 0x00000000
    };

    // Hardware compatibility flags
    enum class vmprog_hardware_flags_v1_0 : uint32_t
    {
        none = 0x00000000,
        rev_a = 0x00000001,
        rev_b = 0x00000002,
    };

    // Core architecture identifiers
    enum class vmprog_core_id_v1_0 : uint32_t
    {
        none = 0,
        yuv444_30b = 1,
        yuv422_20b = 2,
    };

    // Parameter control mode - defines how parameter values are interpreted and displayed
    // Categories:
    //   - Linear scaling: linear, linear_half, linear_quarter, linear_double
    //   - Discrete/boolean: boolean, steps_4, steps_8, steps_16, steps_32, steps_64, steps_128, steps_256
    //   - Angular (polar): polar_degs_90, polar_degs_180, polar_degs_360, polar_degs_720, polar_degs_1440, polar_degs_2880
    //   - Easing curves: quad_in/out/in_out, sine_in/out/in_out, circ_in/out/in_out, quint_in/out/in_out, quart_in/out/in_out, expo_in/out/in_out
    enum class vmprog_parameter_control_mode_v1_0 : uint32_t
    {
        linear = 0,
        linear_half = 1,
        linear_quarter = 2,
        linear_double = 3,
        boolean = 4,
        steps_4 = 5,
        steps_8 = 6,
        steps_16 = 7,
        steps_32 = 8,
        steps_64 = 9,
        steps_128 = 10,
        steps_256 = 11,
        polar_degs_90 = 12,
        polar_degs_180 = 13,
        polar_degs_360 = 14,
        polar_degs_720 = 15,
        polar_degs_1440 = 16,
        polar_degs_2880 = 17,
        quad_in = 18,
        quad_out = 19,
        quad_in_out = 20,
        sine_in = 21,
        sine_out = 22,
        sine_in_out = 23,
        circ_in = 24,
        circ_out = 25,
        circ_in_out = 26,
        quint_in = 27,
        quint_out = 28,
        quint_in_out = 29,
        quart_in = 30,
        quart_out = 31,
        quart_in_out = 32,
        expo_in = 33,
        expo_out = 34,
        expo_in_out = 35
    };

    enum class vmprog_parameter_id_v1_0 : uint32_t
    {
        none = 0,
        rotary_potentiometer_1 = 1,
        rotary_potentiometer_2 = 2,
        rotary_potentiometer_3 = 3,
        rotary_potentiometer_4 = 4,
        rotary_potentiometer_5 = 5,
        rotary_potentiometer_6 = 6,
        toggle_switch_7 = 7,
        toggle_switch_8 = 8,
        toggle_switch_9 = 9,
        toggle_switch_10 = 10,
        toggle_switch_11 = 11,
        linear_potentiometer_12 = 12
    };

    // =============================================================================
    // Bitwise Operators for Flag Enums (Template)
    // =============================================================================

    // Generic bitwise operators for enum class flags
    template<typename E>
    struct enable_bitmask_operators {
        static constexpr bool enable = false;
    };

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E>::type
        operator|(E lhs, E rhs) {
        using underlying = typename std::underlying_type<E>::type;
        return static_cast<E>(static_cast<underlying>(lhs) | static_cast<underlying>(rhs));
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E>::type
        operator&(E lhs, E rhs) {
        using underlying = typename std::underlying_type<E>::type;
        return static_cast<E>(static_cast<underlying>(lhs) & static_cast<underlying>(rhs));
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E>::type
        operator^(E lhs, E rhs) {
        using underlying = typename std::underlying_type<E>::type;
        return static_cast<E>(static_cast<underlying>(lhs) ^ static_cast<underlying>(rhs));
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E>::type
        operator~(E flags) {
        using underlying = typename std::underlying_type<E>::type;
        return static_cast<E>(~static_cast<underlying>(flags));
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E&>::type
        operator|=(E& lhs, E rhs) {
        return lhs = lhs | rhs;
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E&>::type
        operator&=(E& lhs, E rhs) {
        return lhs = lhs & rhs;
    }

    template<typename E>
    constexpr typename std::enable_if<enable_bitmask_operators<E>::enable, E&>::type
        operator^=(E& lhs, E rhs) {
        return lhs = lhs ^ rhs;
    }

    // Enable bitmask operators for flag enums
    template<> struct enable_bitmask_operators<vmprog_header_flags_v1_0> { static constexpr bool enable = true; };
    template<> struct enable_bitmask_operators<vmprog_toc_entry_flags_v1_0> { static constexpr bool enable = true; };
    template<> struct enable_bitmask_operators<vmprog_signed_descriptor_flags_v1_0> { static constexpr bool enable = true; };
    template<> struct enable_bitmask_operators<vmprog_hardware_flags_v1_0> { static constexpr bool enable = true; };

    // =============================================================================
    // Binary Format Structures
    // =============================================================================

    // Artifact hash entry for signed descriptor (64 bytes)
#pragma pack(push, 1)
    struct vmprog_artifact_hash_v1_0
    {
        static constexpr uint32_t struct_size = 36;

        vmprog_toc_entry_type_v1_0 type;   // Artifact type
        uint8_t sha256[32];               // SHA-256 hash of artifact payload
    };
#pragma pack(pop)

#pragma pack(push, 1)
    struct vmprog_header_v1_0
    {
        static constexpr uint32_t expected_magic = 0x47504D56u;  // 'VMPG' (4 ASCII chars, little-endian)
        static constexpr uint32_t max_file_size = 1048576u;       // 1 MB maximum file size
        static constexpr uint16_t default_version_major = 1;
        static constexpr uint16_t default_version_minor = 0;
        static constexpr uint16_t struct_size = 64;

        uint32_t magic;                 // 'VMPG'
        uint16_t version_major;         // Major version
        uint16_t version_minor;         // Minor version
        uint16_t header_size;           // 64
        uint16_t reserved_pad;          // Reserved padding
        uint32_t file_size;             // Total size of .vmprog file in bytes
        vmprog_header_flags_v1_0 flags;   // Header flags
        uint32_t toc_offset;            // Byte offset to TOC from file start
        uint32_t toc_bytes;             // Size of TOC in bytes
        uint32_t toc_count;             // Number of TOC entries
        uint8_t  sha256_package[32];    // Optional SHA-256 hash of entire .vmprog file (with this field zeroed)
    };
#pragma pack(pop)

#pragma pack(push, 1)
    struct vmprog_toc_entry_v1_0
    {
        static constexpr uint32_t struct_size = 64;

        vmprog_toc_entry_type_v1_0 type;      // Entry type
        vmprog_toc_entry_flags_v1_0 flags;    // Entry flags
        uint32_t offset;                    // Byte offset to payload from file start
        uint32_t size;                      // Size of payload in bytes
        uint8_t  sha256[32];                // SHA-256 hash of payload
        uint32_t reserved[4];               // Reserved for future use (16 bytes)
    };
#pragma pack(pop)

#pragma pack(push, 1)
    struct vmprog_signed_descriptor_v1_0 {
        static constexpr uint32_t max_artifacts = 8;
        static constexpr uint32_t struct_size = 332;

        uint8_t config_sha256[32];   // SHA-256 hash of program config
        uint8_t  artifact_count;      // Number of valid artifact entries (must be 0-8, entries [0..count-1] are valid)
        uint8_t  reserved_pad[3];     // Reserved padding to maintain alignment
        vmprog_artifact_hash_v1_0 artifacts[max_artifacts];  // Artifact hash array
        // Note: Entries [0..artifact_count-1] contain valid artifact hashes
        //       Entries [artifact_count..7] must be zeroed (type=none, hash=zeros)
        vmprog_signed_descriptor_flags_v1_0 flags;
        uint32_t build_id;            // Build identifier
    };
#pragma pack(pop)


#pragma pack(push, 1)
    struct vmprog_parameter_config_v1_0
    {
        static constexpr uint32_t name_label_max_length = 32;
        static constexpr uint32_t value_label_max_length = 32;
        static constexpr uint32_t suffix_label_max_length = 4;
        static constexpr uint32_t max_value_labels = 16;
        static constexpr uint32_t struct_size = 572;

        vmprog_parameter_id_v1_0 parameter_id;
        vmprog_parameter_control_mode_v1_0 control_mode;
        uint16_t min_value; // Minimum raw value (hardware-dependent)
        uint16_t max_value; // Maximum raw value (hardware-dependent)
        uint16_t initial_value; // Must be between min_value and max_value
        int16_t display_min_value;
        int16_t display_max_value;
        uint8_t display_float_digits;
        uint8_t value_label_count; // Number of valid value labels (0 to max_value_labels)
        uint8_t  reserved_pad[2];     // Reserved padding
        // All string fields must be null-terminated
        char name_label[name_label_max_length];
        char value_labels[max_value_labels][value_label_max_length];
        char suffix_label[suffix_label_max_length];
        uint8_t reserved[2];  // Padding to 32-bit boundary
    };

#pragma pack(pop)

#pragma pack(push, 1)
    struct vmprog_program_config_v1_0
    {
        static constexpr uint32_t program_id_max_length = 64;
        static constexpr uint32_t program_name_max_length = 32;
        static constexpr uint32_t author_max_length = 64;
        static constexpr uint32_t license_max_length = 32;
        static constexpr uint32_t category_max_length = 32;
        static constexpr uint32_t description_max_length = 128;
        static constexpr uint32_t url_max_length = 128;
        static constexpr uint32_t num_parameters = 12;
        static constexpr uint32_t struct_size = 7372;

        // All string fields must be null-terminated
        char program_id[program_id_max_length];      // Unique program identifier
        uint16_t program_version_major;    // Program version major
        uint16_t program_version_minor;    // Program version minor
        uint16_t program_version_patch;    // Program version patch
        uint16_t abi_min_major;       // Minimum ABI major version
        uint16_t abi_min_minor;       // Minimum ABI minor version
        uint16_t abi_max_major;       // Maximum ABI major version (exclusive)
        uint16_t abi_max_minor;       // Maximum ABI minor version (exclusive)
        vmprog_hardware_flags_v1_0 hw_mask;  // Compatible hardware mask
        vmprog_core_id_v1_0 core_id;         // Core architecture identifier
        char program_name[program_name_max_length];
        char author[author_max_length];
        char license[license_max_length];
        char category[category_max_length];
        char description[description_max_length];
        char url[url_max_length];
        uint16_t parameter_count;  // Number of valid parameters (0 to num_parameters)
        uint16_t reserved_pad;  // Padding
        vmprog_parameter_config_v1_0 parameters[num_parameters];
        uint8_t reserved[2];  // Padding to 32-bit boundary
    };

#pragma pack(pop)

    static_assert(sizeof(vmprog_artifact_hash_v1_0) == vmprog_artifact_hash_v1_0::struct_size,
        "vmprog_artifact_hash_v1_0 size mismatch - check struct packing and alignment");

    static_assert(sizeof(vmprog_header_v1_0) == vmprog_header_v1_0::struct_size,
        "vmprog_header_v1_0 size mismatch - check struct packing and alignment");

    static_assert(sizeof(vmprog_toc_entry_v1_0) == vmprog_toc_entry_v1_0::struct_size,
        "vmprog_toc_entry_v1_0 size mismatch - check struct packing and alignment");

    static_assert(sizeof(vmprog_signed_descriptor_v1_0) == vmprog_signed_descriptor_v1_0::struct_size,
        "vmprog_signed_descriptor_v1_0 size mismatch - check struct packing and alignment");

    static_assert(sizeof(vmprog_parameter_config_v1_0) == vmprog_parameter_config_v1_0::struct_size,
        "vmprog_parameter_config_v1_0 size mismatch - check struct packing and alignment");

    static_assert(sizeof(vmprog_program_config_v1_0) == vmprog_program_config_v1_0::struct_size,
        "vmprog_program_config_v1_0 size mismatch - check struct packing and alignment");

    // Additional static assertions for array bounds
    static_assert(vmprog_signed_descriptor_v1_0::max_artifacts == 8,
        "max_artifacts must be 8 - this is part of the format specification");

    static_assert(vmprog_parameter_config_v1_0::max_value_labels == 16,
        "max_value_labels must be 16 - this is part of the format specification");

    static_assert(vmprog_program_config_v1_0::num_parameters == 12,
        "num_parameters must be 12 - this is part of the format specification");

    // Enum underlying type checks - all enums must be uint32_t for binary compatibility
    static_assert(std::is_same<std::underlying_type<vmprog_validation_result>::type, uint32_t>::value,
        "vmprog_validation_result must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_toc_entry_type_v1_0>::type, uint32_t>::value,
        "vmprog_toc_entry_type_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_header_flags_v1_0>::type, uint32_t>::value,
        "vmprog_header_flags_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_toc_entry_flags_v1_0>::type, uint32_t>::value,
        "vmprog_toc_entry_flags_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_signed_descriptor_flags_v1_0>::type, uint32_t>::value,
        "vmprog_signed_descriptor_flags_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_hardware_flags_v1_0>::type, uint32_t>::value,
        "vmprog_hardware_flags_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_core_id_v1_0>::type, uint32_t>::value,
        "vmprog_core_id_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_parameter_control_mode_v1_0>::type, uint32_t>::value,
        "vmprog_parameter_control_mode_v1_0 must use uint32_t as underlying type");

    static_assert(std::is_same<std::underlying_type<vmprog_parameter_id_v1_0>::type, uint32_t>::value,
        "vmprog_parameter_id_v1_0 must use uint32_t as underlying type");

    // Magic number validation - ensure correct little-endian byte order for "VMPG"
    static_assert(vmprog_header_v1_0::expected_magic == 0x47504D56u,
        "expected_magic must be 0x47504D56 (little-endian 'VMPG')");

    // File size limit validation - ensure max_file_size is 1 MB
    static_assert(vmprog_header_v1_0::max_file_size == 1048576u,
        "max_file_size must be 1048576 (1 MB)");

    static_assert(vmprog_header_v1_0::max_file_size == (1u * 1024u * 1024u),
        "max_file_size calculation mismatch");

    // String buffer size validations
    static_assert(vmprog_program_config_v1_0::program_id_max_length == 64,
        "program_id_max_length must be 64 bytes");

    static_assert(vmprog_program_config_v1_0::program_name_max_length == 32,
        "program_name_max_length must be 32 bytes");

    static_assert(vmprog_program_config_v1_0::author_max_length == 64,
        "author_max_length must be 64 bytes");

    static_assert(vmprog_program_config_v1_0::license_max_length == 32,
        "license_max_length must be 32 bytes");

    static_assert(vmprog_program_config_v1_0::category_max_length == 32,
        "category_max_length must be 32 bytes");

    static_assert(vmprog_program_config_v1_0::description_max_length == 128,
        "description_max_length must be 128 bytes");

    static_assert(vmprog_parameter_config_v1_0::name_label_max_length == 32,
        "name_label_max_length must be 32 bytes");

    static_assert(vmprog_parameter_config_v1_0::value_label_max_length == 32,
        "value_label_max_length must be 32 bytes");

    static_assert(vmprog_parameter_config_v1_0::suffix_label_max_length == 4,
        "suffix_label_max_length must be 4 bytes");

    // Field offset validations for critical structures (ensures binary layout)
    static_assert(offsetof(vmprog_header_v1_0, magic) == 0,
        "vmprog_header_v1_0::magic must be at offset 0");

    static_assert(offsetof(vmprog_header_v1_0, version_major) == 4,
        "vmprog_header_v1_0::version_major must be at offset 4");

    static_assert(offsetof(vmprog_header_v1_0, sha256_package) == 32,
        "vmprog_header_v1_0::sha256_package must be at offset 32");

    static_assert(offsetof(vmprog_toc_entry_v1_0, type) == 0,
        "vmprog_toc_entry_v1_0::type must be at offset 0");

    static_assert(offsetof(vmprog_toc_entry_v1_0, sha256) == 16,
        "vmprog_toc_entry_v1_0::sha256 must be at offset 16");

    static_assert(offsetof(vmprog_signed_descriptor_v1_0, config_sha256) == 0,
        "vmprog_signed_descriptor_v1_0::config_sha256 must be at offset 0");

    static_assert(offsetof(vmprog_signed_descriptor_v1_0, artifact_count) == 32,
        "vmprog_signed_descriptor_v1_0::artifact_count must be at offset 32");

    static_assert(offsetof(vmprog_program_config_v1_0, program_id) == 0,
        "vmprog_program_config_v1_0::program_id must be at offset 0");

    static_assert(offsetof(vmprog_program_config_v1_0, program_version_major) == 64,
        "vmprog_program_config_v1_0::program_version_major must be at offset 64");

    // Calculated size validations - verify struct size calculations are correct
    static_assert(vmprog_program_config_v1_0::struct_size ==
        vmprog_program_config_v1_0::program_id_max_length +  // 64
        sizeof(uint16_t) * 8 +                               // 16 (8 uint16_t fields)
        sizeof(vmprog_hardware_flags_v1_0) +                 // 4
        sizeof(vmprog_core_id_v1_0) +                        // 4
        vmprog_program_config_v1_0::program_name_max_length + // 32
        vmprog_program_config_v1_0::author_max_length +       // 64
        vmprog_program_config_v1_0::license_max_length +      // 32
        vmprog_program_config_v1_0::category_max_length +     // 32
        vmprog_program_config_v1_0::description_max_length +  // 128
        vmprog_program_config_v1_0::url_max_length +          // 128
        2 +                                                   // 2 (parameter_count + reserved_pad)
        sizeof(vmprog_parameter_config_v1_0) * vmprog_program_config_v1_0::num_parameters + // 6864
        2,  // reserved padding
        "vmprog_program_config_v1_0::struct_size calculation mismatch");

    static_assert(vmprog_signed_descriptor_v1_0::struct_size ==
        32 +  // config_sha256
        4 +   // artifact_count (1 byte) + reserved_pad (3 bytes)
        (vmprog_signed_descriptor_v1_0::max_artifacts * vmprog_artifact_hash_v1_0::struct_size) + // 288
        sizeof(vmprog_signed_descriptor_flags_v1_0) + // 4
        sizeof(uint32_t),  // build_id
        "vmprog_signed_descriptor_v1_0::struct_size calculation mismatch");

    // Alignment checks - ensure proper 32-bit alignment
    static_assert(sizeof(vmprog_header_v1_0) % 4 == 0,
        "vmprog_header_v1_0 must be 32-bit aligned");

    static_assert(sizeof(vmprog_toc_entry_v1_0) % 4 == 0,
        "vmprog_toc_entry_v1_0 must be 32-bit aligned");

    static_assert(sizeof(vmprog_signed_descriptor_v1_0) % 4 == 0,
        "vmprog_signed_descriptor_v1_0 must be 32-bit aligned");

    static_assert(sizeof(vmprog_parameter_config_v1_0) % 4 == 0,
        "vmprog_parameter_config_v1_0 must be 32-bit aligned");

    static_assert(sizeof(vmprog_program_config_v1_0) % 4 == 0,
        "vmprog_program_config_v1_0 must be 32-bit aligned");

    // Hash field size validations - all SHA-256 hashes must be 32 bytes
    static_assert(sizeof(vmprog_header_v1_0::sha256_package) == 32,
        "SHA-256 hash in header must be 32 bytes");

    static_assert(sizeof(vmprog_toc_entry_v1_0::sha256) == 32,
        "SHA-256 hash in TOC entry must be 32 bytes");

    static_assert(sizeof(vmprog_artifact_hash_v1_0::sha256) == 32,
        "SHA-256 hash in artifact must be 32 bytes");

    static_assert(sizeof(vmprog_signed_descriptor_v1_0::config_sha256) == 32,
        "SHA-256 hash in signed descriptor must be 32 bytes");

    // Array dimension validations
    static_assert(sizeof(vmprog_signed_descriptor_v1_0::artifacts) / sizeof(vmprog_artifact_hash_v1_0) ==
        vmprog_signed_descriptor_v1_0::max_artifacts,
        "artifacts array size mismatch");

    static_assert(sizeof(vmprog_parameter_config_v1_0::value_labels) / sizeof(char[32]) ==
        vmprog_parameter_config_v1_0::max_value_labels,
        "value_labels array size mismatch");

    static_assert(sizeof(vmprog_program_config_v1_0::parameters) / sizeof(vmprog_parameter_config_v1_0) ==
        vmprog_program_config_v1_0::num_parameters,
        "parameters array size mismatch");

    // =============================================================================
    // String Helper Functions
    // =============================================================================

    /**
     * @brief Safely copy a string to a fixed-size character array with null-termination.
     *
     * Ensures the destination array is always null-terminated, even if the source
     * string is longer than the available space. Clears any remaining bytes in the
     * destination with zeros for deterministic binary output.
     *
     * @param dest Destination character array (must be at least size bytes)
     * @param src Source null-terminated string
     * @param size Size of destination array including null terminator
     *
     * Example:
     *   char name[64];
     *   safe_strncpy(name, "My Program", sizeof(name));
     *   // Result: "My Program\0\0\0..." (54 bytes of zeros follow)
     */
    inline void safe_strncpy(char* dest, const char* src, size_t size) {
        if (size == 0) return;

        // Copy up to size-1 characters
        size_t i = 0;
        while (i < size - 1 && src[i] != '\0') {
            dest[i] = src[i];
            ++i;
        }

        // Null-terminate and clear remaining bytes
        while (i < size) {
            dest[i] = '\0';
            ++i;
        }
    }

    /**
     * @brief Check if a fixed-size character array is properly null-terminated.
     *
     * @param str Character array to check
     * @param size Size of the array
     * @return true if string is null-terminated within size bytes
     */
    inline bool is_string_terminated(const char* str, size_t size) {
        for (size_t i = 0; i < size; ++i) {
            if (str[i] == '\0') return true;
        }
        return false;
    }

    /**
     * @brief Get the length of a string in a fixed-size buffer.
     *
     * Returns the length of the string, or size if not null-terminated.
     *
     * @param str Character array to measure
     * @param size Size of the array
     * @return Length of string (without null terminator), or size if not terminated
     */
    inline size_t safe_strlen(const char* str, size_t size) {
        for (size_t i = 0; i < size; ++i) {
            if (str[i] == '\0') return i;
        }
        return size;
    }

    /**
     * @brief Check if a string buffer is empty (first char is null).
     *
     * @param str Character array to check
     * @param size Size of the array
     * @return true if empty or invalid
     */
    inline bool is_string_empty(const char* str, size_t size) {
        return size == 0 || str[0] == '\0';
    }

    /**
     * @brief Safely compare two strings in fixed-size buffers.
     *
     * @param str1 First string
     * @param size1 Size of first buffer
     * @param str2 Second string
     * @param size2 Size of second buffer
     * @return true if strings are equal
     */
    inline bool safe_strcmp(const char* str1, size_t size1, const char* str2, size_t size2) {
        size_t len1 = safe_strlen(str1, size1);
        size_t len2 = safe_strlen(str2, size2);

        if (len1 != len2) return false;

        for (size_t i = 0; i < len1; ++i) {
            if (str1[i] != str2[i]) return false;
        }

        return true;
    }

    // =============================================================================
    // Validation Helper Functions
    // =============================================================================

    /**
     * @brief Validate a vmprog_header_v1_0 structure.
     *
     * Checks:
     * - Magic number is correct (0x47504D56 = "VMPG")
     * - Version fields are supported (major == 1)
     * - File size is within valid range (>= header size, <= 64MB)
     * - TOC offset and size are valid
     * - TOC entry count is reasonable
     *
     * @param header Header structure to validate
     * @param file_size Total file size in bytes (from filesystem)
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_header_v1_0(
        const vmprog_header_v1_0& header,
        uint32_t file_size
    ) {
        // Check magic number
        if (header.magic != vmprog_header_v1_0::expected_magic) {
            return vmprog_validation_result::invalid_magic;
        }

        // Check version (only major version 1 supported)
        if (header.version_major != 1) {
            return vmprog_validation_result::invalid_version;
        }

        // Check header size
        if (header.header_size != sizeof(vmprog_header_v1_0)) {
            return vmprog_validation_result::invalid_header_size;
        }

        // Check file size
        if (file_size < sizeof(vmprog_header_v1_0) ||
            file_size > vmprog_header_v1_0::max_file_size ||
            file_size != header.file_size) {
            return vmprog_validation_result::invalid_file_size;
        }

        // Check TOC count (reasonable limit) - check first to prevent overflow
        if (header.toc_count == 0 || header.toc_count > 256) {
            return vmprog_validation_result::invalid_toc_count;
        }

        // Check TOC offset (must be after header)
        if (header.toc_offset < sizeof(vmprog_header_v1_0) ||
            header.toc_offset >= file_size) {
            return vmprog_validation_result::invalid_toc_offset;
        }

        // Check TOC size (safe from overflow after count validation)
        uint32_t toc_size = header.toc_count * sizeof(vmprog_toc_entry_v1_0);
        if (header.toc_bytes != toc_size ||
            header.toc_offset + toc_size > file_size) {
            return vmprog_validation_result::invalid_toc_size;
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Validate a vmprog_toc_entry_v1_0 structure.
     *
     * Checks:
     * - Entry type is valid (not none for actual entries)
     * - Offset and size don't overflow
     * - Payload is within file bounds
     * - Reserved fields are zeroed
     *
     * @param entry TOC entry to validate
     * @param file_size Total file size in bytes
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_toc_entry_v1_0(
        const vmprog_toc_entry_v1_0& entry,
        uint32_t file_size
    ) {
        // Check entry type is valid
        if (entry.type == vmprog_toc_entry_type_v1_0::none) {
            return vmprog_validation_result::invalid_toc_entry;
        }

        // Check offset is within valid range
        if (entry.offset < sizeof(vmprog_header_v1_0) || entry.offset >= file_size) {
            return vmprog_validation_result::invalid_payload_offset;
        }

        // Check for overflow and bounds in offset + size calculation
        if (entry.size > 0 && (entry.offset > file_size - entry.size)) {
            return vmprog_validation_result::invalid_payload_offset;
        }

        // Verify reserved fields are zeroed
        for (uint32_t i = 0; i < 4; ++i) {
            if (entry.reserved[i] != 0) {
                return vmprog_validation_result::reserved_field_not_zero;
            }
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Validate a vmprog_artifact_hash_v1_0 structure.
     *
     * Checks:
     * - Artifact type is valid
     *
     * @param artifact Artifact hash to validate
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_artifact_hash_v1_0(
        const vmprog_artifact_hash_v1_0& artifact
    ) {
        // Check artifact type is valid (none is only allowed for unused slots)
        uint32_t type_value = static_cast<uint32_t>(artifact.type);
        if (type_value > static_cast<uint32_t>(vmprog_toc_entry_type_v1_0::bitstream_hd_dual)) {
            return vmprog_validation_result::invalid_enum_value;
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Validate a vmprog_signed_descriptor_v1_0 structure.
     *
     * Checks:
     * - Artifact count is within bounds (0-8)
     * - Valid artifacts have proper types
     * - Unused artifact slots are zeroed
     * - Reserved padding is zeroed
     *
     * @param descriptor Signed descriptor to validate
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_signed_descriptor_v1_0(
        const vmprog_signed_descriptor_v1_0& descriptor
    ) {
        // Check artifact count
        if (descriptor.artifact_count > vmprog_signed_descriptor_v1_0::max_artifacts) {
            return vmprog_validation_result::invalid_artifact_count;
        }

        // Verify reserved padding is zeroed
        for (uint32_t i = 0; i < 3; ++i) {
            if (descriptor.reserved_pad[i] != 0) {
                return vmprog_validation_result::reserved_field_not_zero;
            }
        }

        // Validate used artifact slots
        for (uint32_t i = 0; i < descriptor.artifact_count; ++i) {
            if (descriptor.artifacts[i].type == vmprog_toc_entry_type_v1_0::none) {
                return vmprog_validation_result::invalid_artifact_count;
            }
            auto result = validate_vmprog_artifact_hash_v1_0(descriptor.artifacts[i]);
            if (result != vmprog_validation_result::ok) {
                return result;
            }
        }

        // Verify unused artifact slots are zeroed
        for (uint32_t i = descriptor.artifact_count; i < vmprog_signed_descriptor_v1_0::max_artifacts; ++i) {
            if (descriptor.artifacts[i].type != vmprog_toc_entry_type_v1_0::none) {
                return vmprog_validation_result::invalid_artifact_count;
            }
            // Check hash is zeroed
            for (uint32_t j = 0; j < 32; ++j) {
                if (descriptor.artifacts[i].sha256[j] != 0) {
                    return vmprog_validation_result::reserved_field_not_zero;
                }
            }
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Validate a vmprog_parameter_config_v1_0 structure.
     *
     * Checks:
     * - Value label count is within bounds (0-16)
     * - All strings are null-terminated
     * - Min/max/initial values are consistent
     * - Parameter ID and control mode are valid
     * - Reserved fields are zeroed
     *
     * @param param Parameter configuration to validate
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_parameter_config_v1_0(
        const vmprog_parameter_config_v1_0& param
    ) {
        // Check parameter ID is valid
        uint32_t param_id = static_cast<uint32_t>(param.parameter_id);
        if (param_id > static_cast<uint32_t>(vmprog_parameter_id_v1_0::linear_potentiometer_12)) {
            return vmprog_validation_result::invalid_enum_value;
        }

        // Check control mode is valid
        uint32_t mode = static_cast<uint32_t>(param.control_mode);
        if (mode > static_cast<uint32_t>(vmprog_parameter_control_mode_v1_0::expo_in_out)) {
            return vmprog_validation_result::invalid_enum_value;
        }

        // Check value label count
        if (param.value_label_count > vmprog_parameter_config_v1_0::max_value_labels) {
            return vmprog_validation_result::invalid_value_label_count;
        }

        // Check min/max/initial value consistency
        if (param.min_value > param.max_value) {
            return vmprog_validation_result::invalid_parameter_values;
        }
        if (param.initial_value < param.min_value || param.initial_value > param.max_value) {
            return vmprog_validation_result::invalid_parameter_values;
        }
        if (param.display_min_value > param.display_max_value) {
            return vmprog_validation_result::invalid_parameter_values;
        }

        // Check all strings are null-terminated
        if (!is_string_terminated(param.name_label, sizeof(param.name_label)) ||
            !is_string_terminated(param.suffix_label, sizeof(param.suffix_label))) {
            return vmprog_validation_result::string_not_terminated;
        }

        // Check value labels
        for (uint32_t i = 0; i < param.value_label_count; ++i) {
            if (!is_string_terminated(param.value_labels[i], sizeof(param.value_labels[i]))) {
                return vmprog_validation_result::string_not_terminated;
            }
        }

        // Verify reserved fields are zeroed
        for (uint32_t i = 0; i < 2; ++i) {
            if (param.reserved_pad[i] != 0 || param.reserved[i] != 0) {
                return vmprog_validation_result::reserved_field_not_zero;
            }
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Validate a vmprog_program_config_v1_0 structure.
     *
     * Checks:
     * - Parameter count is within bounds (0-12)
     * - ABI range is valid (min_abi <= max_abi)
     * - All strings are null-terminated and non-empty (program_id, program_name)
     * - Hardware flags are valid
     * - All parameters are valid
     * - Reserved fields are zeroed
     *
     * @param config Program configuration to validate
     * @return Validation result code
     */
    inline vmprog_validation_result validate_vmprog_program_config_v1_0(
        const vmprog_program_config_v1_0& config
    ) {
        // Check parameter count
        if (config.parameter_count > vmprog_program_config_v1_0::num_parameters) {
            return vmprog_validation_result::invalid_parameter_count;
        }

        // Check ABI range (major.minor comparison)
        if (config.abi_min_major > config.abi_max_major ||
            (config.abi_min_major == config.abi_max_major && config.abi_min_minor > config.abi_max_minor)) {
            return vmprog_validation_result::invalid_abi_range;
        }

        // Check ABI versions are reasonable (not zero)
        if (config.abi_min_major == 0 || config.abi_max_major == 0) {
            return vmprog_validation_result::invalid_abi_range;
        }

        // Check all strings are null-terminated
        if (!is_string_terminated(config.program_id, sizeof(config.program_id)) ||
            !is_string_terminated(config.program_name, sizeof(config.program_name)) ||
            !is_string_terminated(config.author, sizeof(config.author)) ||
            !is_string_terminated(config.license, sizeof(config.license)) ||
            !is_string_terminated(config.category, sizeof(config.category)) ||
            !is_string_terminated(config.description, sizeof(config.description))) {
            return vmprog_validation_result::string_not_terminated;
        }

        // Check required fields are non-empty
        if (config.program_id[0] == '\0' || config.program_name[0] == '\0') {
            return vmprog_validation_result::string_not_terminated;
        }

        // Check hardware flags have at least one valid flag set
        if (config.hw_mask == vmprog_hardware_flags_v1_0::none) {
            return vmprog_validation_result::invalid_enum_value;
        }

        // Check core_id is valid (not none)
        if (config.core_id == vmprog_core_id_v1_0::none) {
            return vmprog_validation_result::invalid_enum_value;
        }

        // Verify reserved fields are zeroed
        if (config.reserved_pad != 0 || config.reserved[0] != 0 || config.reserved[1] != 0) {
            return vmprog_validation_result::reserved_field_not_zero;
        }

        // Validate each parameter
        for (uint32_t i = 0; i < config.parameter_count; ++i) {
            auto result = validate_vmprog_parameter_config_v1_0(config.parameters[i]);
            if (result != vmprog_validation_result::ok) {
                return result;
            }
        }

        return vmprog_validation_result::ok;
    }

    // =============================================================================
    // Hash Calculation Helpers
    // =============================================================================

    /**
     * @brief Calculate SHA-256 hash of program configuration.
     *
     * This function computes the config_sha256 field for the signed descriptor.
     * The hash covers the entire vmprog_program_config_v1_0 structure with all
     * reserved fields zeroed.
     *
     * @param config Program configuration to hash
     * @param out_hash Output buffer (must be 32 bytes)
     * @return true if hash was calculated successfully
     */
    inline bool calculate_config_sha256(const vmprog_program_config_v1_0& config, uint8_t* out_hash) {
        // Create a copy of config with reserved fields zeroed
        vmprog_program_config_v1_0 config_copy = config;

        // Zero out all reserved fields for deterministic hashing
        // The main reserved field is at the end
        config_copy.reserved[0] = 0;
        config_copy.reserved[1] = 0;

        // Zero reserved fields in used parameters only (for consistency with validation)
        for (uint32_t i = 0; i < config.parameter_count && i < vmprog_program_config_v1_0::num_parameters; ++i) {
            config_copy.parameters[i].reserved_pad[0] = 0;
            config_copy.parameters[i].reserved_pad[1] = 0;
            config_copy.parameters[i].reserved[0] = 0;
            config_copy.parameters[i].reserved[1] = 0;
        }

        // Calculate BLAKE2b-256 hash (used as SHA-256 equivalent)
        sha256_ctx ctx;
        sha256_init(ctx);
        sha256_update(ctx, reinterpret_cast<const uint8_t*>(&config_copy), sizeof(config_copy));
        sha256_final(ctx, out_hash);

        return true;
    }

    /**
     * @brief Calculate SHA-256 hash of entire package file.
     *
     * This function computes the sha256_package field in the header.
     * The hash covers the entire file with the sha256_package field itself zeroed.
     *
     * @param file_data Pointer to complete file data
     * @param file_size Size of file in bytes
     * @param out_hash Output buffer (must be 32 bytes)
     * @return true if hash was calculated successfully
     */
    inline bool calculate_package_sha256(const uint8_t* file_data, uint32_t file_size, uint8_t* out_hash) {
        if (file_size < sizeof(vmprog_header_v1_0)) {
            return false; // File too small to contain header
        }

        // Calculate BLAKE2b-256 hash (used as SHA-256 equivalent)
        sha256_ctx ctx;
        sha256_init(ctx);

        // Hash bytes before sha256_package field (offset 0-31)
        sha256_update(ctx, file_data, 32);

        // Hash zeros for the sha256_package field (offset 32-63)
        uint8_t zeros[32] = { 0 };
        sha256_update(ctx, zeros, 32);

        // Hash remaining bytes after sha256_package field (offset 64 onwards)
        if (file_size > 64) {
            sha256_update(ctx, file_data + 64, file_size - 64);
        }

        sha256_final(ctx, out_hash);
        return true;
    }

    /**
     * @brief Verify SHA-256 hash of entire package file.
     *
     * This function verifies the sha256_package field in the header matches
     * the computed hash of the file.
     *
     * @param file_data Pointer to complete file data
     * @param file_size Size of file in bytes
     * @return true if hash verification succeeds
     */
    inline bool verify_package_sha256(const uint8_t* file_data, uint32_t file_size) {
        if (file_size < sizeof(vmprog_header_v1_0)) {
            return false;
        }

        const auto* header = reinterpret_cast<const vmprog_header_v1_0*>(file_data);

        // Calculate expected hash
        uint8_t computed_hash[32];
        if (!calculate_package_sha256(file_data, file_size, computed_hash)) {
            return false;
        }

        // Compare with header hash (constant-time comparison)
        uint8_t diff = 0;
        for (int i = 0; i < 32; ++i) {
            diff |= (computed_hash[i] ^ header->sha256_package[i]);
        }

        return diff == 0;
    }

    /**
     * @brief Verify Ed25519 signature of signed descriptor.
     *
     * This function verifies an Ed25519 signature over the signed descriptor
     * using the provided public key.
     *
     * @param signature Ed25519 signature (64 bytes)
     * @param public_key Ed25519 public key (32 bytes)
     * @param signed_descriptor The signed descriptor to verify
     * @return true if signature verification succeeds
     */
    inline bool verify_ed25519_signature(
        const uint8_t signature[64],
        const uint8_t public_key[32],
        const vmprog_signed_descriptor_v1_0& signed_descriptor
    ) {
        return ed25519_verify(
            signature,
            public_key,
            reinterpret_cast<const uint8_t*>(&signed_descriptor),
            sizeof(vmprog_signed_descriptor_v1_0)
        );
    }

    /**
     * @brief Verify payload hash in TOC entry.
     *
     * This function verifies that a payload's hash matches the hash stored
     * in its TOC entry.
     *
     * @param payload_data Pointer to payload data
     * @param payload_size Size of payload in bytes
     * @param expected_hash Expected hash from TOC entry (32 bytes)
     * @return true if hash verification succeeds
     */
    inline bool verify_payload_hash(
        const uint8_t* payload_data,
        uint32_t payload_size,
        const uint8_t expected_hash[32]
    ) {
        return verify_hash(payload_data, payload_size, expected_hash);
    }

    /**
     * @brief Calculate hash of arbitrary data.
     *
     * @param data Data to hash
     * @param size Size of data in bytes
     * @param out_hash Output buffer (must be 32 bytes)
     */
    inline void calculate_data_hash(const uint8_t* data, uint32_t size, uint8_t out_hash[32]) {
        sha256_oneshot(data, size, out_hash);
    }

    // =============================================================================
    // TOC Helper Functions
    // =============================================================================

    /**
     * @brief Find TOC entry by type.
     *
     * @param toc Pointer to TOC array
     * @param toc_count Number of TOC entries
     * @param type Entry type to find
     * @param out_index Optional output parameter for entry index
     * @return Pointer to entry if found, nullptr otherwise
     */
    inline const vmprog_toc_entry_v1_0* find_toc_entry(
        const vmprog_toc_entry_v1_0* toc,
        uint32_t toc_count,
        vmprog_toc_entry_type_v1_0 type,
        uint32_t* out_index = nullptr
    ) {
        for (uint32_t i = 0; i < toc_count; ++i) {
            if (toc[i].type == type) {
                if (out_index) *out_index = i;
                return &toc[i];
            }
        }
        return nullptr;
    }

    /**
     * @brief Check if TOC contains entry of specified type.
     *
     * @param toc Pointer to TOC array
     * @param toc_count Number of TOC entries
     * @param type Entry type to check for
     * @return true if entry exists
     */
    inline bool has_toc_entry(
        const vmprog_toc_entry_v1_0* toc,
        uint32_t toc_count,
        vmprog_toc_entry_type_v1_0 type
    ) {
        return find_toc_entry(toc, toc_count, type) != nullptr;
    }

    /**
     * @brief Count TOC entries of specified type.
     *
     * @param toc Pointer to TOC array
     * @param toc_count Number of TOC entries
     * @param type Entry type to count
     * @return Number of matching entries
     */
    inline uint32_t count_toc_entries(
        const vmprog_toc_entry_v1_0* toc,
        uint32_t toc_count,
        vmprog_toc_entry_type_v1_0 type
    ) {
        uint32_t count = 0;
        for (uint32_t i = 0; i < toc_count; ++i) {
            if (toc[i].type == type) ++count;
        }
        return count;
    }

    // =============================================================================
    // Package Integrity Verification
    // =============================================================================

    /**
     * @brief Verify all payload hashes in TOC match actual data.
     *
     * @param file_data Complete file data
     * @param file_size File size in bytes
     * @param header Validated header
     * @return Validation result
     */
    inline vmprog_validation_result verify_all_payload_hashes(
        const uint8_t* file_data,
        uint32_t file_size,
        const vmprog_header_v1_0& header
    ) {
        const auto* toc = reinterpret_cast<const vmprog_toc_entry_v1_0*>(
            file_data + header.toc_offset);

        for (uint32_t i = 0; i < header.toc_count; ++i) {
            // Skip entries with no payload
            if (toc[i].size == 0) continue;

            // Validate entry
            auto result = validate_vmprog_toc_entry_v1_0(toc[i], file_size);
            if (result != vmprog_validation_result::ok) {
                return result;
            }

            // Verify hash
            const uint8_t* payload = file_data + toc[i].offset;
            if (!verify_hash(payload, toc[i].size, toc[i].sha256)) {
                return vmprog_validation_result::invalid_hash;
            }
        }

        return vmprog_validation_result::ok;
    }

    /**
     * @brief Check if package is signed.
     *
     * @param header Package header
     * @return true if signed flag is set
     */
    inline bool is_package_signed(const vmprog_header_v1_0& header) {
        return (header.flags & vmprog_header_flags_v1_0::signed_pkg) != vmprog_header_flags_v1_0::none;
    }

    /**
     * @brief Get human-readable validation result string.
     *
     * @param result Validation result code
     * @return String description
     */
    inline const char* validation_result_string(vmprog_validation_result result) {
        switch (result) {
            case vmprog_validation_result::ok: return "OK";
            case vmprog_validation_result::invalid_magic: return "Invalid magic number";
            case vmprog_validation_result::invalid_version: return "Invalid version";
            case vmprog_validation_result::invalid_header_size: return "Invalid header size";
            case vmprog_validation_result::invalid_file_size: return "Invalid file size";
            case vmprog_validation_result::invalid_toc_offset: return "Invalid TOC offset";
            case vmprog_validation_result::invalid_toc_size: return "Invalid TOC size";
            case vmprog_validation_result::invalid_toc_count: return "Invalid TOC count";
            case vmprog_validation_result::invalid_artifact_count: return "Invalid artifact count";
            case vmprog_validation_result::invalid_parameter_count: return "Invalid parameter count";
            case vmprog_validation_result::invalid_value_label_count: return "Invalid value label count";
            case vmprog_validation_result::invalid_abi_range: return "Invalid ABI range";
            case vmprog_validation_result::string_not_terminated: return "String not terminated";
            case vmprog_validation_result::invalid_hash: return "Invalid hash";
            case vmprog_validation_result::invalid_toc_entry: return "Invalid TOC entry";
            case vmprog_validation_result::invalid_payload_offset: return "Invalid payload offset";
            case vmprog_validation_result::invalid_parameter_values: return "Invalid parameter values";
            case vmprog_validation_result::invalid_enum_value: return "Invalid enum value";
            case vmprog_validation_result::reserved_field_not_zero: return "Reserved field not zero";
            default: return "Unknown error";
        }
    }

    // =============================================================================
    // Structure Initialization Helpers
    // =============================================================================

    /**
     * @brief Initialize vmprog_header_v1_0 with default values.
     *
     * @param header Header to initialize
     */
    inline void init_vmprog_header(vmprog_header_v1_0& header) {
        header = {}; // Zero everything
        header.magic = vmprog_header_v1_0::expected_magic;
        header.version_major = vmprog_header_v1_0::default_version_major;
        header.version_minor = vmprog_header_v1_0::default_version_minor;
        header.header_size = vmprog_header_v1_0::struct_size;
        header.flags = vmprog_header_flags_v1_0::none;
    }

    /**
     * @brief Initialize vmprog_program_config_v1_0 with default values.
     *
     * @param config Config to initialize
     */
    inline void init_vmprog_config(vmprog_program_config_v1_0& config) {
        config = {}; // Zero everything
        config.program_version_major = 1;
        config.program_version_minor = 0;
        config.program_version_patch = 0;
        config.abi_min_major = 1;
        config.abi_min_minor = 0;
        config.abi_max_major = 2;
        config.abi_max_minor = 0;
        config.hw_mask = vmprog_hardware_flags_v1_0::rev_a;
        config.core_id = vmprog_core_id_v1_0::yuv444_30b;
        config.parameter_count = 0;
    }

    /**
     * @brief Initialize vmprog_signed_descriptor_v1_0 with default values.
     *
     * @param descriptor Descriptor to initialize
     */
    inline void init_signed_descriptor(vmprog_signed_descriptor_v1_0& descriptor) {
        descriptor = {}; // Zero everything
        descriptor.flags = vmprog_signed_descriptor_flags_v1_0::none;
        descriptor.artifact_count = 0;
    }

    /**
     * @brief Initialize vmprog_toc_entry_v1_0 with default values.
     *
     * @param entry TOC entry to initialize
     */
    inline void init_toc_entry(vmprog_toc_entry_v1_0& entry) {
        entry = {}; // Zero everything
        entry.type = vmprog_toc_entry_type_v1_0::none;
        entry.flags = vmprog_toc_entry_flags_v1_0::none;
        entry.offset = 0;
        entry.size = 0;
        // Explicitly zero sha256 and reserved arrays
        for (size_t i = 0; i < sizeof(entry.sha256); ++i) {
            entry.sha256[i] = 0;
        }
        for (size_t i = 0; i < 4; ++i) {
            entry.reserved[i] = 0;
        }
    }

    /**
     * @brief Initialize vmprog_parameter_config_v1_0 with default values.
     *
     * @param param Parameter to initialize
     */
    inline void init_parameter_config(vmprog_parameter_config_v1_0& param) {
        param = {}; // Zero everything
        param.parameter_id = vmprog_parameter_id_v1_0::none;
        param.control_mode = vmprog_parameter_control_mode_v1_0::linear;
        param.min_value = 0;
        param.max_value = 65535;
        param.initial_value = 0;
        param.display_min_value = 0;
        param.display_max_value = 100;
        param.display_float_digits = 0;
        param.value_label_count = 0;
    }

    // =============================================================================
    // Comprehensive Package Validation
    // =============================================================================

    /**
     * @brief Comprehensively validate an entire vmprog package.
     *
     * This performs all validation checks in the correct order:
     * 1. Header validation
     * 2. TOC validation
     * 3. Payload hash verification
     * 4. Package hash verification (if present)
     * 5. Signed descriptor validation (if present)
     * 6. Config validation (if present)
     *
     * @param file_data Complete file data
     * @param file_size File size in bytes
     * @param verify_hashes If true, verify all payload and package hashes
     * @param verify_signature If true and package is signed, verify signature
     * @param public_key Public key for signature verification (32 bytes, optional)
     * @return Validation result
     */
    inline vmprog_validation_result validate_vmprog_package(
        const uint8_t* file_data,
        uint32_t file_size,
        bool verify_hashes = true,
        bool verify_signature = false,
        const uint8_t* public_key = nullptr
    ) {
        // Validate header
        if (file_size < sizeof(vmprog_header_v1_0)) {
            return vmprog_validation_result::invalid_file_size;
        }

        const auto* header = reinterpret_cast<const vmprog_header_v1_0*>(file_data);
        auto result = validate_vmprog_header_v1_0(*header, file_size);
        if (result != vmprog_validation_result::ok) {
            return result;
        }

        // Validate TOC entries
        const auto* toc = reinterpret_cast<const vmprog_toc_entry_v1_0*>(
            file_data + header->toc_offset);

        for (uint32_t i = 0; i < header->toc_count; ++i) {
            result = validate_vmprog_toc_entry_v1_0(toc[i], file_size);
            if (result != vmprog_validation_result::ok) {
                return result;
            }
        }

        // Verify payload hashes
        if (verify_hashes) {
            result = verify_all_payload_hashes(file_data, file_size, *header);
            if (result != vmprog_validation_result::ok) {
                return result;
            }

            // Verify package hash if present
            if (!is_hash_zero(header->sha256_package)) {
                if (!verify_package_sha256(file_data, file_size)) {
                    return vmprog_validation_result::invalid_hash;
                }
            }
        }

        // Find and validate config if present
        const vmprog_toc_entry_v1_0* config_entry = find_toc_entry(
            toc, header->toc_count, vmprog_toc_entry_type_v1_0::config);

        if (config_entry && config_entry->size == sizeof(vmprog_program_config_v1_0)) {
            const auto* config = reinterpret_cast<const vmprog_program_config_v1_0*>(
                file_data + config_entry->offset);
            result = validate_vmprog_program_config_v1_0(*config);
            if (result != vmprog_validation_result::ok) {
                return result;
            }
        }

        // Find and validate signed descriptor if present
        const vmprog_toc_entry_v1_0* desc_entry = find_toc_entry(
            toc, header->toc_count, vmprog_toc_entry_type_v1_0::signed_descriptor);

        if (desc_entry && desc_entry->size == sizeof(vmprog_signed_descriptor_v1_0)) {
            const auto* descriptor = reinterpret_cast<const vmprog_signed_descriptor_v1_0*>(
                file_data + desc_entry->offset);
            result = validate_vmprog_signed_descriptor_v1_0(*descriptor);
            if (result != vmprog_validation_result::ok) {
                return result;
            }

            // Verify signature if requested
            if (verify_signature && is_package_signed(*header)) {
                if (!public_key) {
                    return vmprog_validation_result::invalid_hash; // No key provided
                }

                const vmprog_toc_entry_v1_0* sig_entry = find_toc_entry(
                    toc, header->toc_count, vmprog_toc_entry_type_v1_0::signature);

                if (!sig_entry || sig_entry->size != VMPROG_SIGNATURE_SIZE) {
                    return vmprog_validation_result::invalid_hash; // Missing or invalid signature
                }

                const uint8_t* signature = file_data + sig_entry->offset;
                if (!verify_ed25519_signature(signature, public_key, *descriptor)) {
                    return vmprog_validation_result::invalid_hash; // Invalid signature
                }
            }
        }

        return vmprog_validation_result::ok;
    }

    // =============================================================================
    // Public Key Management
    // =============================================================================

    /**
     * @brief Get number of built-in public keys.
     *
     * @return Number of public keys in vmprog_public_keys array
     */
    inline constexpr size_t get_public_key_count() {
        return sizeof(vmprog_public_keys) / sizeof(vmprog_public_keys[0]);
    }

    /**
     * @brief Verify signature against all built-in public keys.
     *
     * Tries to verify the signature using each built-in public key until
     * one succeeds or all fail.
     *
     * @param signature Ed25519 signature (64 bytes)
     * @param signed_descriptor The signed descriptor to verify
     * @param out_key_index Optional output parameter for which key succeeded
     * @return true if signature verified with any built-in key
     */
    inline bool verify_with_builtin_keys(
        const uint8_t signature[64],
        const vmprog_signed_descriptor_v1_0& signed_descriptor,
        size_t* out_key_index = nullptr
    ) {
        for (size_t i = 0; i < get_public_key_count(); ++i) {
            if (verify_ed25519_signature(signature, vmprog_public_keys[i], signed_descriptor)) {
                if (out_key_index) *out_key_index = i;
                return true;
            }
        }
        return false;
    }

    // =============================================================================
    // Endianness Conversion Helpers
    // =============================================================================

    /**
     * @brief Convert 32-bit value to little-endian format.
     *
     * On little-endian systems (x86, ARM), this is a no-op.
     * On big-endian systems, bytes are swapped.
     *
     * @param value Value to convert
     * @return Value in little-endian format
     */
    inline uint32_t to_little_endian_32(uint32_t value) {
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
        return ((value & 0xFF000000) >> 24) |
            ((value & 0x00FF0000) >> 8) |
            ((value & 0x0000FF00) << 8) |
            ((value & 0x000000FF) << 24);
#else
        return value; // Already little-endian or unspecified (assume little-endian)
#endif
    }

    /**
     * @brief Convert 32-bit value from little-endian format.
     *
     * On little-endian systems (x86, ARM), this is a no-op.
     * On big-endian systems, bytes are swapped.
     *
     * @param value Little-endian value to convert
     * @return Value in native format
     */
    inline uint32_t from_little_endian_32(uint32_t value) {
        return to_little_endian_32(value); // Symmetric operation
    }

    /**
     * @brief Convert 16-bit value to little-endian format.
     *
     * On little-endian systems (x86, ARM), this is a no-op.
     * On big-endian systems, bytes are swapped.
     *
     * @param value Value to convert
     * @return Value in little-endian format
     */
    inline uint16_t to_little_endian_16(uint16_t value) {
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
        return ((value & 0xFF00) >> 8) |
               ((value & 0x00FF) << 8);
#else
        return value; // Already little-endian or unspecified (assume little-endian)
#endif
    }

    /**
     * @brief Convert 16-bit value from little-endian format.
     *
     * On little-endian systems (x86, ARM), this is a no-op.
     * On big-endian systems, bytes are swapped.
     *
     * @param value Little-endian value to convert
     * @return Value in native format
     */
    inline uint16_t from_little_endian_16(uint16_t value) {
        return to_little_endian_16(value); // Symmetric operation
    }

    // =============================================================================
    // Usage Examples
    // =============================================================================

    /*
     * Example 1: Creating a simple .vmprog package
     *
     * ```cpp
     * // Initialize program configuration
     * lzx::vmprog_program_config_v1_0 config = {};
     *
     * // Set string fields
     * lzx::safe_strncpy(config.program_id, "com.example.test", sizeof(config.program_id));
     * lzx::safe_strncpy(config.program_name, "My Test Program", sizeof(config.program_name));
     * lzx::safe_strncpy(config.author, "Test Author", sizeof(config.author));
     * lzx::safe_strncpy(config.description, "A simple test program", sizeof(config.description));
     *
     * // Set version and ABI fields
     * config.program_version_major = 1;
     * config.program_version_minor = 0;
     * config.program_version_patch = 0;
     * config.abi_min_major = 1;
     * config.abi_min_minor = 0;
     * config.abi_max_major = 2;  // Exclusive upper bound
     * config.abi_max_minor = 0;
     *
     * // Set hardware compatibility
     * config.hw_mask = static_cast<lzx::vmprog_hardware_flags_v1_0>(
     *     lzx::to_little_endian_32(static_cast<uint32_t>(lzx::vmprog_hardware_flags_v1_0::rev_a)));
     *
     * config.parameter_count = 0; // No parameters for this example
     *
     * // Validate configuration
     * auto result = lzx::validate_vmprog_program_config_v1_0(config);
     * if (result != lzx::vmprog_validation_result::ok) {
     *     // Handle validation error
     *     return;
     * }
     *
     * // Create signed descriptor
     * lzx::vmprog_signed_descriptor_v1_0 descriptor = {};
     * lzx::calculate_config_sha256(config, descriptor.config_sha256);
     * descriptor.artifact_count = 1; // One FPGA bitstream
     * descriptor.artifacts[0].type = lzx::vmprog_toc_entry_type_v1_0::fpga_bitstream;
     * // ... set artifact hash ...
     *
     * // Build complete package file (pseudo-code):
     * // 1. Write header with magic, version, sizes
     * // 2. Write TOC entries
     * // 3. Write signed descriptor
     * // 4. Write program config
     * // 5. Write signature (if signed)
     * // 6. Write FPGA bitstream payload
     * // 7. Calculate and update sha256_package in header
     * ```
     */

     /*
      * Example 2: Validating a loaded .vmprog package with signature verification
      *
      * ```cpp
      * // Load file into memory
      * std::vector<uint8_t> file_data = load_vmprog_file("program.vmprog");
      *
      * // Comprehensive validation with built-in public key (verifies everything)
      * auto result = lzx::validate_vmprog_package(
      *     file_data.data(),
      *     file_data.size(),
      *     true,  // verify_hashes
      *     true,  // verify_signature
      *     lzx::vmprog_public_keys[0]  // Use first built-in public key
      * );
      *
      * if (result != lzx::vmprog_validation_result::ok) {
      *     printf("Validation failed: %s\n", lzx::validation_result_string(result));
      *     return;
      * }
      *
      * // Package is valid and signature verified - safe to use
      * const auto* header = reinterpret_cast<const lzx::vmprog_header_v1_0*>(file_data.data());
      * const auto* toc = reinterpret_cast<const lzx::vmprog_toc_entry_v1_0*>(
      *     file_data.data() + header->toc_offset);
      *
      * // Extract program configuration
      * const lzx::vmprog_toc_entry_v1_0* config_entry = lzx::find_toc_entry(
      *     toc, header->toc_count, lzx::vmprog_toc_entry_type_v1_0::config);
      *
      * if (config_entry) {
      *     const auto* config = reinterpret_cast<const lzx::vmprog_program_config_v1_0*>(
      *         file_data.data() + config_entry->offset);
      *     // Use validated config...
      * }
      * ```
      */

     /*
      * Example 3: Manual signature verification with built-in keys
      *
      * ```cpp
      * // Load package
      * std::vector<uint8_t> file_data = load_vmprog_file("program.vmprog");
      * const auto* header = reinterpret_cast<const lzx::vmprog_header_v1_0*>(file_data.data());
      * const auto* toc = reinterpret_cast<const lzx::vmprog_toc_entry_v1_0*>(
      *     file_data.data() + header->toc_offset);
      *
      * // Check if package is signed
      * if (!lzx::is_package_signed(*header)) {
      *     printf("Package is not signed\n");
      *     return;
      * }
      *
      * // Find signed descriptor and signature entries
      * const lzx::vmprog_toc_entry_v1_0* desc_entry = lzx::find_toc_entry(
      *     toc, header->toc_count, lzx::vmprog_toc_entry_type_v1_0::signed_descriptor);
      * const lzx::vmprog_toc_entry_v1_0* sig_entry = lzx::find_toc_entry(
      *     toc, header->toc_count, lzx::vmprog_toc_entry_type_v1_0::signature);
      *
      * if (!desc_entry || !sig_entry) {
      *     printf("Missing descriptor or signature\n");
      *     return;
      * }
      *
      * const auto* descriptor = reinterpret_cast<const lzx::vmprog_signed_descriptor_v1_0*>(
      *     file_data.data() + desc_entry->offset);
      * const uint8_t* signature = file_data.data() + sig_entry->offset;
      *
      * // Try each built-in public key
      * bool verified = false;
      * for (size_t i = 0; i < sizeof(lzx::vmprog_public_keys) / sizeof(lzx::vmprog_public_keys[0]); ++i) {
      *     if (lzx::verify_ed25519_signature(signature, lzx::vmprog_public_keys[i], *descriptor)) {
      *         printf("Signature verified with public key %zu\n", i);
      *         verified = true;
      *         break;
      *     }
      * }
      *
      * if (!verified) {
      *     printf("Signature verification failed\n");
      *     return;
      * }
      * ```
      */

} // namespace lzx
