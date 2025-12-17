// Videomancer SDK - Unit Tests for vmprog_format.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/vmprog_format.hpp>
#include <iostream>
#include <cassert>
#include <cstring>

using namespace lzx;

// Test struct sizes and alignment
bool test_struct_sizes() {
    // Verify sizes match specification
    if (sizeof(vmprog_header_v1_0) != 64) {
        std::cerr << "FAILED: Struct size test - header size is "
                  << sizeof(vmprog_header_v1_0) << ", expected 64" << std::endl;
        return false;
    }

    if (sizeof(vmprog_toc_entry_v1_0) != 64) {
        std::cerr << "FAILED: Struct size test - TOC entry size is "
                  << sizeof(vmprog_toc_entry_v1_0) << ", expected 64" << std::endl;
        return false;
    }

    if (sizeof(vmprog_program_config_v1_0) != 7372) {
        std::cerr << "FAILED: Struct size test - program config size is "
                  << sizeof(vmprog_program_config_v1_0) << ", expected 7372" << std::endl;
        return false;
    }

    std::cout << "PASSED: Struct size validation test" << std::endl;
    return true;
}

// Test magic number constant
bool test_magic_number() {
    if (vmprog_header_v1_0::expected_magic != 0x47504D56) {
        std::cerr << "FAILED: Magic number test - incorrect value" << std::endl;
        return false;
    }

    // Verify it's 'VMPG' in little-endian
    uint32_t magic = vmprog_header_v1_0::expected_magic;
    const uint8_t* magic_bytes = reinterpret_cast<const uint8_t*>(&magic);
    if (magic_bytes[0] != 'V' || magic_bytes[1] != 'M' ||
        magic_bytes[2] != 'P' || magic_bytes[3] != 'G') {
        std::cerr << "FAILED: Magic number test - incorrect byte order" << std::endl;
        return false;
    }

    std::cout << "PASSED: Magic number constant test" << std::endl;
    return true;
}

// Test safe_strncpy function
bool test_safe_strncpy() {
    char buffer[16];

    // Test normal copy
    memset(buffer, 0xFF, sizeof(buffer));
    safe_strncpy(buffer, "Hello", sizeof(buffer));

    if (strcmp(buffer, "Hello") != 0) {
        std::cerr << "FAILED: safe_strncpy test - normal copy failed" << std::endl;
        return false;
    }

    // Test truncation
    memset(buffer, 0xFF, sizeof(buffer));
    safe_strncpy(buffer, "This is a very long string that should be truncated", sizeof(buffer));

    if (buffer[sizeof(buffer) - 1] != '\0') {
        std::cerr << "FAILED: safe_strncpy test - buffer not null-terminated" << std::endl;
        return false;
    }

    if (strlen(buffer) >= sizeof(buffer)) {
        std::cerr << "FAILED: safe_strncpy test - string length exceeds buffer" << std::endl;
        return false;
    }

    // Test empty string
    memset(buffer, 0xFF, sizeof(buffer));
    safe_strncpy(buffer, "", sizeof(buffer));

    if (buffer[0] != '\0') {
        std::cerr << "FAILED: safe_strncpy test - empty string not handled" << std::endl;
        return false;
    }

    std::cout << "PASSED: safe_strncpy function test" << std::endl;
    return true;
}

// Test header initialization
bool test_header_init() {
    vmprog_header_v1_0 header;
    memset(&header, 0xFF, sizeof(header));

    init_vmprog_header(header);

    // Verify magic number
    if (header.magic != vmprog_header_v1_0::expected_magic) {
        std::cerr << "FAILED: Header init test - incorrect magic number" << std::endl;
        return false;
    }

    // Verify version
    if (header.version_major != 1 || header.version_minor != 0) {
        std::cerr << "FAILED: Header init test - incorrect version" << std::endl;
        return false;
    }

    // Verify header size
    if (header.header_size != sizeof(vmprog_header_v1_0)) {
        std::cerr << "FAILED: Header init test - incorrect header size" << std::endl;
        return false;
    }

    std::cout << "PASSED: Header initialization test" << std::endl;
    return true;
}

// Test TOC entry initialization
bool test_toc_entry_init() {
    vmprog_toc_entry_v1_0 entry;
    memset(&entry, 0xFF, sizeof(entry));

    init_toc_entry(entry);

    // Verify type is none
    if (entry.type != vmprog_toc_entry_type_v1_0::none) {
        std::cerr << "FAILED: TOC entry init test - incorrect type" << std::endl;
        return false;
    }

    // Verify flags are none
    if (entry.flags != vmprog_toc_entry_flags_v1_0::none) {
        std::cerr << "FAILED: TOC entry init test - incorrect flags" << std::endl;
        return false;
    }

    // Verify reserved fields are zeroed (4 uint32_t elements)
    for (size_t i = 0; i < 4; ++i) {
        if (entry.reserved[i] != 0) {
            std::cerr << "FAILED: TOC entry init test - reserved field not zeroed" << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: TOC entry initialization test" << std::endl;
    return true;
}

// Test program config initialization
bool test_program_config_init() {
    vmprog_program_config_v1_0 config;
    memset(&config, 0xFF, sizeof(config));

    init_vmprog_config(config);

    // Verify program version
    if (config.program_version_major != 1 || config.program_version_minor != 0) {
        std::cerr << "FAILED: Program config init test - incorrect version" << std::endl;
        return false;
    }

    // Verify counts are zero
    if (config.parameter_count != 0) {
        std::cerr << "FAILED: Program config init test - parameter count not zero" << std::endl;
        return false;
    }

    // Verify string fields are empty
    if (config.program_id[0] != '\0' || config.program_name[0] != '\0') {
        std::cerr << "FAILED: Program config init test - string fields not empty" << std::endl;
        return false;
    }

    std::cout << "PASSED: Program config initialization test" << std::endl;
    return true;
}

// Test validation result enum values
bool test_validation_result_values() {
    // Verify ok is 0
    if (static_cast<uint32_t>(vmprog_validation_result::ok) != 0) {
        std::cerr << "FAILED: Validation result test - ok value is not 0" << std::endl;
        return false;
    }

    // Verify error codes are non-zero and unique
    const vmprog_validation_result errors[] = {
        vmprog_validation_result::invalid_magic,
        vmprog_validation_result::invalid_version,
        vmprog_validation_result::invalid_header_size,
        vmprog_validation_result::invalid_file_size,
        vmprog_validation_result::invalid_toc_offset,
        vmprog_validation_result::invalid_toc_size,
        vmprog_validation_result::invalid_toc_count
    };

    for (size_t i = 0; i < sizeof(errors) / sizeof(errors[0]); ++i) {
        uint32_t val = static_cast<uint32_t>(errors[i]);
        if (val == 0) {
            std::cerr << "FAILED: Validation result test - error code is 0" << std::endl;
            return false;
        }

        // Check uniqueness
        for (size_t j = i + 1; j < sizeof(errors) / sizeof(errors[0]); ++j) {
            if (val == static_cast<uint32_t>(errors[j])) {
                std::cerr << "FAILED: Validation result test - duplicate error codes" << std::endl;
                return false;
            }
        }
    }

    std::cout << "PASSED: Validation result enum test" << std::endl;
    return true;
}

// Test enum type sizes
bool test_enum_sizes() {
    // All enums should be 32-bit
    if (sizeof(vmprog_validation_result) != 4) {
        std::cerr << "FAILED: Enum size test - validation_result not 32-bit" << std::endl;
        return false;
    }

    if (sizeof(vmprog_toc_entry_type_v1_0) != 4) {
        std::cerr << "FAILED: Enum size test - toc_entry_type not 32-bit" << std::endl;
        return false;
    }

    if (sizeof(vmprog_parameter_control_mode_v1_0) != 4) {
        std::cerr << "FAILED: Enum size test - parameter_control_mode not 32-bit" << std::endl;
        return false;
    }

    std::cout << "PASSED: Enum size validation test" << std::endl;
    return true;
}

// Test header validation with invalid magic
bool test_validate_header_invalid_magic() {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);

    header.magic = 0x12345678;  // Invalid magic
    header.file_size = 1024;

    auto result = validate_vmprog_header_v1_0(header, 1024);

    if (result != vmprog_validation_result::invalid_magic) {
        std::cerr << "FAILED: Header validation test - did not detect invalid magic" << std::endl;
        return false;
    }

    std::cout << "PASSED: Header validation (invalid magic) test" << std::endl;
    return true;
}

// Test header validation with invalid version
bool test_validate_header_invalid_version() {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);

    header.version_major = 99;  // Invalid version
    header.file_size = 1024;

    auto result = validate_vmprog_header_v1_0(header, 1024);

    if (result != vmprog_validation_result::invalid_version) {
        std::cerr << "FAILED: Header validation test - did not detect invalid version" << std::endl;
        return false;
    }

    std::cout << "PASSED: Header validation (invalid version) test" << std::endl;
    return true;
}

// Test header validation with valid header
bool test_validate_header_valid() {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);

    header.file_size = 1024;
    header.toc_offset = 64;
    header.toc_count = 2;
    header.toc_bytes = header.toc_count * sizeof(vmprog_toc_entry_v1_0);

    auto result = validate_vmprog_header_v1_0(header, 1024);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Header validation test - rejected valid header" << std::endl;
        return false;
    }

    std::cout << "PASSED: Header validation (valid) test" << std::endl;
    return true;
}

// Test is_string_terminated helper
bool test_is_string_terminated() {
    char terminated[16] = "Hello";
    char not_terminated[5] = {'H', 'e', 'l', 'l', 'o'};

    if (!is_string_terminated(terminated, sizeof(terminated))) {
        std::cerr << "FAILED: is_string_terminated - terminated string not detected" << std::endl;
        return false;
    }

    if (is_string_terminated(not_terminated, sizeof(not_terminated))) {
        std::cerr << "FAILED: is_string_terminated - non-terminated string detected as terminated" << std::endl;
        return false;
    }

    std::cout << "PASSED: is_string_terminated test" << std::endl;
    return true;
}

// Test safe_strlen helper
bool test_safe_strlen() {
    char str[16] = "Hello";
    char full_str[5] = {'H', 'e', 'l', 'l', 'o'};

    if (safe_strlen(str, sizeof(str)) != 5) {
        std::cerr << "FAILED: safe_strlen - incorrect length for terminated string" << std::endl;
        return false;
    }

    // Non-terminated string should return buffer size
    if (safe_strlen(full_str, sizeof(full_str)) != 5) {
        std::cerr << "FAILED: safe_strlen - incorrect length for non-terminated string" << std::endl;
        return false;
    }

    // Empty string
    char empty[16] = "";
    if (safe_strlen(empty, sizeof(empty)) != 0) {
        std::cerr << "FAILED: safe_strlen - incorrect length for empty string" << std::endl;
        return false;
    }

    std::cout << "PASSED: safe_strlen test" << std::endl;
    return true;
}

// Test is_string_empty helper
bool test_is_string_empty() {
    char empty[16] = "";
    char non_empty[16] = "Hello";

    if (!is_string_empty(empty, sizeof(empty))) {
        std::cerr << "FAILED: is_string_empty - empty string not detected" << std::endl;
        return false;
    }

    if (is_string_empty(non_empty, sizeof(non_empty))) {
        std::cerr << "FAILED: is_string_empty - non-empty string detected as empty" << std::endl;
        return false;
    }

    // Zero size should return true
    if (!is_string_empty(non_empty, 0)) {
        std::cerr << "FAILED: is_string_empty - zero size buffer not handled" << std::endl;
        return false;
    }

    std::cout << "PASSED: is_string_empty test" << std::endl;
    return true;
}

// Test safe_strcmp helper
bool test_safe_strcmp() {
    char str1[16] = "Hello";
    char str2[16] = "Hello";
    char str3[16] = "World";
    char str4[8] = "Hello";

    // Identical strings
    if (!safe_strcmp(str1, sizeof(str1), str2, sizeof(str2))) {
        std::cerr << "FAILED: safe_strcmp - identical strings not equal" << std::endl;
        return false;
    }

    // Different strings
    if (safe_strcmp(str1, sizeof(str1), str3, sizeof(str3))) {
        std::cerr << "FAILED: safe_strcmp - different strings detected as equal" << std::endl;
        return false;
    }

    // Same content, different buffer sizes
    if (!safe_strcmp(str1, sizeof(str1), str4, sizeof(str4))) {
        std::cerr << "FAILED: safe_strcmp - same content with different buffer sizes" << std::endl;
        return false;
    }

    std::cout << "PASSED: safe_strcmp test" << std::endl;
    return true;
}

// Test enum bitwise operators
bool test_enum_bitwise_operators() {
    // Test flag combination with hardware flags (has multiple values)
    auto hw_flags = vmprog_hardware_flags_v1_0::videomancer_core_rev_a | vmprog_hardware_flags_v1_0::videomancer_core_rev_b;

    // Test flag check (AND)
    if ((hw_flags & vmprog_hardware_flags_v1_0::videomancer_core_rev_a) == vmprog_hardware_flags_v1_0::none) {
        std::cerr << "FAILED: enum bitwise operators - OR/AND test failed" << std::endl;
        return false;
    }

    // Test flag removal (AND NOT)
    auto hw_flags2 = hw_flags & ~vmprog_hardware_flags_v1_0::videomancer_core_rev_a;
    if ((hw_flags2 & vmprog_hardware_flags_v1_0::videomancer_core_rev_a) != vmprog_hardware_flags_v1_0::none) {
        std::cerr << "FAILED: enum bitwise operators - NOT test failed" << std::endl;
        return false;
    }

    // Test XOR
    auto hw_flags3 = vmprog_hardware_flags_v1_0::videomancer_core_rev_a ^ vmprog_hardware_flags_v1_0::videomancer_core_rev_a;
    if (hw_flags3 != vmprog_hardware_flags_v1_0::none) {
        std::cerr << "FAILED: enum bitwise operators - XOR test failed" << std::endl;
        return false;
    }

    // Test |= operator
    auto test_flags = vmprog_hardware_flags_v1_0::none;
    test_flags |= vmprog_hardware_flags_v1_0::videomancer_core_rev_a;
    if ((test_flags & vmprog_hardware_flags_v1_0::videomancer_core_rev_a) == vmprog_hardware_flags_v1_0::none) {
        std::cerr << "FAILED: enum bitwise operators - |= test failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: enum bitwise operators test" << std::endl;
    return true;
}

// Test endianness conversion functions
bool test_endianness_conversion() {
    uint32_t test32 = 0x12345678;
    uint16_t test16 = 0x1234;

    // Test 32-bit conversion (round-trip)
    uint32_t converted32 = to_little_endian_32(test32);
    uint32_t recovered32 = from_little_endian_32(converted32);
    if (recovered32 != test32) {
        std::cerr << "FAILED: endianness conversion - 32-bit round-trip failed" << std::endl;
        return false;
    }

    // Test 16-bit conversion (round-trip)
    uint16_t converted16 = to_little_endian_16(test16);
    uint16_t recovered16 = from_little_endian_16(converted16);
    if (recovered16 != test16) {
        std::cerr << "FAILED: endianness conversion - 16-bit round-trip failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: endianness conversion test" << std::endl;
    return true;
}

// Test is_package_signed helper
bool test_is_package_signed() {
    vmprog_header_v1_0 signed_header;
    init_vmprog_header(signed_header);
    signed_header.flags = vmprog_header_flags_v1_0::signed_pkg;

    if (!is_package_signed(signed_header)) {
        std::cerr << "FAILED: is_package_signed - signed package not detected" << std::endl;
        return false;
    }

    vmprog_header_v1_0 unsigned_header;
    init_vmprog_header(unsigned_header);
    unsigned_header.flags = vmprog_header_flags_v1_0::none;

    if (is_package_signed(unsigned_header)) {
        std::cerr << "FAILED: is_package_signed - unsigned package detected as signed" << std::endl;
        return false;
    }

    std::cout << "PASSED: is_package_signed test" << std::endl;
    return true;
}

// Test validation_result_string helper
bool test_validation_result_string() {
    const char* ok_str = validation_result_string(vmprog_validation_result::ok);
    if (strcmp(ok_str, "OK") != 0) {
        std::cerr << "FAILED: validation_result_string - incorrect OK string" << std::endl;
        return false;
    }

    const char* magic_str = validation_result_string(vmprog_validation_result::invalid_magic);
    if (strcmp(magic_str, "Invalid magic number") != 0) {
        std::cerr << "FAILED: validation_result_string - incorrect magic error string" << std::endl;
        return false;
    }

    // Test unknown error
    const char* unknown_str = validation_result_string(static_cast<vmprog_validation_result>(9999));
    if (strcmp(unknown_str, "Unknown error") != 0) {
        std::cerr << "FAILED: validation_result_string - incorrect unknown error string" << std::endl;
        return false;
    }

    std::cout << "PASSED: validation_result_string test" << std::endl;
    return true;
}

// Test get_public_key_count helper
bool test_get_public_key_count() {
    size_t count = get_public_key_count();

    // We know there's at least 1 key from vmprog_public_keys.hpp
    if (count == 0) {
        std::cerr << "FAILED: get_public_key_count - returned zero keys" << std::endl;
        return false;
    }

    std::cout << "PASSED: get_public_key_count test (found " << count << " key(s))" << std::endl;
    return true;
}

// Test validate_vmprog_toc_entry with various invalid cases
bool test_validate_toc_entry_invalid_type() {
    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::none; // Invalid type for actual entry
    entry.offset = 100;
    entry.size = 50;

    auto result = validate_vmprog_toc_entry_v1_0(entry, 1024);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate TOC entry invalid type - none type accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate TOC entry invalid type test" << std::endl;
    return true;
}

// Test validate_vmprog_toc_entry with offset overflow
bool test_validate_toc_entry_offset_overflow() {
    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::config;
    entry.offset = 1000;
    entry.size = 500; // offset + size > file_size

    auto result = validate_vmprog_toc_entry_v1_0(entry, 1200); // 1000 + 500 > 1200

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate TOC entry offset overflow - overflow not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate TOC entry offset overflow test" << std::endl;
    return true;
}

// Test validate_vmprog_artifact_hash
bool test_validate_artifact_hash() {
    vmprog_artifact_hash_v1_0 artifact;
    artifact.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    memset(artifact.sha256, 0xAB, 32);

    auto result = validate_vmprog_artifact_hash_v1_0(artifact);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate artifact hash - valid artifact rejected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate artifact hash test" << std::endl;
    return true;
}

// Test validate_vmprog_artifact_hash with invalid type
bool test_validate_artifact_hash_invalid_type() {
    vmprog_artifact_hash_v1_0 artifact;
    artifact.type = static_cast<vmprog_toc_entry_type_v1_0>(999); // Invalid type
    memset(artifact.sha256, 0, 32);

    auto result = validate_vmprog_artifact_hash_v1_0(artifact);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate artifact hash invalid type - invalid type accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate artifact hash invalid type test" << std::endl;
    return true;
}

// Test validate_vmprog_signed_descriptor with max artifacts
bool test_validate_descriptor_max_artifacts() {
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    descriptor.artifact_count = vmprog_signed_descriptor_v1_0::max_artifacts; // 8

    // Fill all artifact slots
    for (uint8_t i = 0; i < descriptor.artifact_count; i++) {
        descriptor.artifacts[i].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
        memset(descriptor.artifacts[i].sha256, i, 32);
    }

    auto result = validate_vmprog_signed_descriptor_v1_0(descriptor);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate descriptor max artifacts - max count rejected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate descriptor max artifacts test" << std::endl;
    return true;
}

// Test validate_vmprog_signed_descriptor with unused slots not zeroed
bool test_validate_descriptor_unused_not_zeroed() {
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    descriptor.artifact_count = 2;

    // Fill first 2 slots
    for (uint8_t i = 0; i < 2; i++) {
        descriptor.artifacts[i].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
        memset(descriptor.artifacts[i].sha256, i, 32);
    }

    // Leave unused slot with non-zero data
    descriptor.artifacts[3].type = vmprog_toc_entry_type_v1_0::config; // Should be none

    auto result = validate_vmprog_signed_descriptor_v1_0(descriptor);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate descriptor unused not zeroed - invalid unused slot accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate descriptor unused not zeroed test" << std::endl;
    return true;
}

// Test validate_vmprog_parameter_config with invalid value range
bool test_validate_parameter_invalid_range() {
    vmprog_parameter_config_v1_0 param;
    init_parameter_config(param);
    safe_strncpy(param.name_label, "Test Param", sizeof(param.name_label));
    param.parameter_id = vmprog_parameter_id_v1_0::rotary_potentiometer_1;
    param.min_value = 1000;
    param.max_value = 500; // Max < Min (invalid)
    param.initial_value = 750;

    auto result = validate_vmprog_parameter_config_v1_0(param);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate parameter invalid range - invalid range accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate parameter invalid range test" << std::endl;
    return true;
}

// Test validate_vmprog_parameter_config with initial value out of range
bool test_validate_parameter_initial_out_of_range() {
    vmprog_parameter_config_v1_0 param;
    init_parameter_config(param);
    safe_strncpy(param.name_label, "Test", sizeof(param.name_label));
    param.parameter_id = vmprog_parameter_id_v1_0::rotary_potentiometer_1;
    param.min_value = 100;
    param.max_value = 500;
    param.initial_value = 50; // Below min

    auto result = validate_vmprog_parameter_config_v1_0(param);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate parameter initial out of range - out of range value accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate parameter initial out of range test" << std::endl;
    return true;
}

// Test validate_vmprog_parameter_config with non-terminated string
bool test_validate_parameter_non_terminated_string() {
    vmprog_parameter_config_v1_0 param;
    init_parameter_config(param);
    param.parameter_id = vmprog_parameter_id_v1_0::rotary_potentiometer_1;

    // Fill name_label without null terminator
    memset(param.name_label, 'A', sizeof(param.name_label));

    auto result = validate_vmprog_parameter_config_v1_0(param);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate parameter non-terminated string - non-terminated string accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate parameter non-terminated string test" << std::endl;
    return true;
}

// Test validate_vmprog_parameter_config with excessive value labels
bool test_validate_parameter_excessive_value_labels() {
    vmprog_parameter_config_v1_0 param;
    init_parameter_config(param);
    safe_strncpy(param.name_label, "Test", sizeof(param.name_label));
    param.parameter_id = vmprog_parameter_id_v1_0::rotary_potentiometer_1;
    param.value_label_count = 20; // Over max (16)

    auto result = validate_vmprog_parameter_config_v1_0(param);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate parameter excessive value labels - excessive count accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate parameter excessive value labels test" << std::endl;
    return true;
}

// Test validate_vmprog_program_config with excessive parameters
bool test_validate_config_excessive_parameters() {
    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.id", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Test", sizeof(config.program_name));
    config.parameter_count = 20; // Over max (12)

    auto result = validate_vmprog_program_config_v1_0(config);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate config excessive parameters - excessive count accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate config excessive parameters test" << std::endl;
    return true;
}

// Test validate_vmprog_program_config with zero ABI version
bool test_validate_config_zero_abi_version() {
    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.id", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Test", sizeof(config.program_name));
    config.abi_min_major = 0; // Invalid
    config.abi_min_minor = 0;

    auto result = validate_vmprog_program_config_v1_0(config);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate config zero ABI version - zero version accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate config zero ABI version test" << std::endl;
    return true;
}

// Test validate_vmprog_program_config with no hardware flags
bool test_validate_config_no_hardware_flags() {
    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.id", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Test", sizeof(config.program_name));
    config.hw_mask = vmprog_hardware_flags_v1_0::none; // No hardware selected

    auto result = validate_vmprog_program_config_v1_0(config);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate config no hardware flags - no hardware accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate config no hardware flags test" << std::endl;
    return true;
}

// Test has_toc_entry function
bool test_has_toc_entry_function() {
    vmprog_toc_entry_v1_0 toc[3];

    init_toc_entry(toc[0]);
    toc[0].type = vmprog_toc_entry_type_v1_0::config;

    init_toc_entry(toc[1]);
    toc[1].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;

    init_toc_entry(toc[2]);
    toc[2].type = vmprog_toc_entry_type_v1_0::signed_descriptor;

    // Test positive case
    if (!has_toc_entry(toc, 3, vmprog_toc_entry_type_v1_0::config)) {
        std::cerr << "FAILED: has_toc_entry - config not found" << std::endl;
        return false;
    }

    // Test negative case
    if (has_toc_entry(toc, 3, vmprog_toc_entry_type_v1_0::signature)) {
        std::cerr << "FAILED: has_toc_entry - signature incorrectly found" << std::endl;
        return false;
    }

    std::cout << "PASSED: has_toc_entry function test" << std::endl;
    return true;
}

// Test count_toc_entries function
bool test_count_toc_entries_function() {
    vmprog_toc_entry_v1_0 toc[5];

    for (int i = 0; i < 5; i++) {
        init_toc_entry(toc[i]);
    }

    toc[0].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    toc[1].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    toc[2].type = vmprog_toc_entry_type_v1_0::config;
    toc[3].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    toc[4].type = vmprog_toc_entry_type_v1_0::signed_descriptor;

    uint32_t bitstream_count = count_toc_entries(toc, 5, vmprog_toc_entry_type_v1_0::fpga_bitstream);

    if (bitstream_count != 3) {
        std::cerr << "FAILED: count_toc_entries - incorrect count (expected 3, got " << bitstream_count << ")" << std::endl;
        return false;
    }

    uint32_t sig_count = count_toc_entries(toc, 5, vmprog_toc_entry_type_v1_0::signature);

    if (sig_count != 0) {
        std::cerr << "FAILED: count_toc_entries - found non-existent entries" << std::endl;
        return false;
    }

    std::cout << "PASSED: count_toc_entries function test" << std::endl;
    return true;
}

// Test init_signed_descriptor function
bool test_init_signed_descriptor() {
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);

    if (descriptor.artifact_count != 0) {
        std::cerr << "FAILED: init_signed_descriptor - artifact_count not zero" << std::endl;
        return false;
    }

    if (descriptor.flags != vmprog_signed_descriptor_flags_v1_0::none) {
        std::cerr << "FAILED: init_signed_descriptor - flags not none" << std::endl;
        return false;
    }

    // Check config_sha256 is zeroed
    bool all_zero = true;
    for (int i = 0; i < 32; i++) {
        if (descriptor.config_sha256[i] != 0) {
            all_zero = false;
            break;
        }
    }

    if (!all_zero) {
        std::cerr << "FAILED: init_signed_descriptor - config_sha256 not zeroed" << std::endl;
        return false;
    }

    std::cout << "PASSED: init_signed_descriptor test" << std::endl;
    return true;
}

// Test init_parameter_config function
bool test_init_parameter_config() {
    vmprog_parameter_config_v1_0 param;
    init_parameter_config(param);

    if (param.parameter_id != vmprog_parameter_id_v1_0::none) {
        std::cerr << "FAILED: init_parameter_config - parameter_id not none" << std::endl;
        return false;
    }

    if (param.control_mode != vmprog_parameter_control_mode_v1_0::linear) {
        std::cerr << "FAILED: init_parameter_config - control_mode not linear" << std::endl;
        return false;
    }

    if (param.value_label_count != 0) {
        std::cerr << "FAILED: init_parameter_config - value_label_count not zero" << std::endl;
        return false;
    }

    std::cout << "PASSED: init_parameter_config test" << std::endl;
    return true;
}

// Test safe_strncpy with exact buffer size
bool test_safe_strncpy_exact_size() {
    char buffer[6];
    safe_strncpy(buffer, "Hello", sizeof(buffer));

    if (strcmp(buffer, "Hello") != 0) {
        std::cerr << "FAILED: safe_strncpy exact size - string mismatch" << std::endl;
        return false;
    }

    if (buffer[5] != '\0') {
        std::cerr << "FAILED: safe_strncpy exact size - not null terminated" << std::endl;
        return false;
    }

    std::cout << "PASSED: safe_strncpy exact size test" << std::endl;
    return true;
}

// Test safe_strncpy with zero size
bool test_safe_strncpy_zero_size() {
    char buffer[10] = "unchanged";
    safe_strncpy(buffer, "test", 0);

    // Should not modify buffer
    if (strcmp(buffer, "unchanged") != 0) {
        std::cerr << "FAILED: safe_strncpy zero size - buffer modified" << std::endl;
        return false;
    }

    std::cout << "PASSED: safe_strncpy zero size test" << std::endl;
    return true;
}

// Test validate_vmprog_header with invalid file size
bool test_validate_header_file_size_mismatch() {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = 1024;
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 1;
    header.toc_bytes = sizeof(vmprog_toc_entry_v1_0);

    // Actual file size differs from header.file_size
    auto result = validate_vmprog_header_v1_0(header, 2048);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate header file size mismatch - mismatch not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate header file size mismatch test" << std::endl;
    return true;
}

// Test validate_vmprog_header with TOC beyond file
bool test_validate_header_toc_beyond_file() {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = 200;
    header.toc_offset = 100;
    header.toc_count = 10;
    header.toc_bytes = 10 * sizeof(vmprog_toc_entry_v1_0); // Will exceed file_size

    auto result = validate_vmprog_header_v1_0(header, 200);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Validate header TOC beyond file - overflow not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Validate header TOC beyond file test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "======================================" << std::endl;
    std::cout << "Videomancer vmprog_format.hpp Tests" << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << std::endl;

    int passed = 0;
    int total = 0;

    #define RUN_TEST(test_func) \
        do { \
            total++; \
            if (test_func()) { \
                passed++; \
            } \
        } while(0)

    RUN_TEST(test_struct_sizes);
    RUN_TEST(test_magic_number);
    RUN_TEST(test_enum_sizes);
    RUN_TEST(test_validation_result_values);
    RUN_TEST(test_safe_strncpy);
    RUN_TEST(test_is_string_terminated);
    RUN_TEST(test_safe_strlen);
    RUN_TEST(test_is_string_empty);
    RUN_TEST(test_safe_strcmp);
    RUN_TEST(test_enum_bitwise_operators);
    RUN_TEST(test_endianness_conversion);
    RUN_TEST(test_is_package_signed);
    RUN_TEST(test_validation_result_string);
    RUN_TEST(test_get_public_key_count);
    RUN_TEST(test_header_init);
    RUN_TEST(test_toc_entry_init);
    RUN_TEST(test_program_config_init);
    RUN_TEST(test_validate_header_invalid_magic);
    RUN_TEST(test_validate_header_invalid_version);
    RUN_TEST(test_validate_header_valid);
    RUN_TEST(test_validate_toc_entry_invalid_type);
    RUN_TEST(test_validate_toc_entry_offset_overflow);
    RUN_TEST(test_validate_artifact_hash);
    RUN_TEST(test_validate_artifact_hash_invalid_type);
    RUN_TEST(test_validate_descriptor_max_artifacts);
    RUN_TEST(test_validate_descriptor_unused_not_zeroed);
    RUN_TEST(test_validate_parameter_invalid_range);
    RUN_TEST(test_validate_parameter_initial_out_of_range);
    RUN_TEST(test_validate_parameter_non_terminated_string);
    RUN_TEST(test_validate_parameter_excessive_value_labels);
    RUN_TEST(test_validate_config_excessive_parameters);
    RUN_TEST(test_validate_config_zero_abi_version);
    RUN_TEST(test_validate_config_no_hardware_flags);
    RUN_TEST(test_has_toc_entry_function);
    RUN_TEST(test_count_toc_entries_function);
    RUN_TEST(test_init_signed_descriptor);
    RUN_TEST(test_init_parameter_config);
    RUN_TEST(test_safe_strncpy_exact_size);
    RUN_TEST(test_safe_strncpy_zero_size);
    RUN_TEST(test_validate_header_file_size_mismatch);
    RUN_TEST(test_validate_header_toc_beyond_file);

    std::cout << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "======================================" << std::endl;

    return (passed == total) ? 0 : 1;
}
