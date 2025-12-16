// Videomancer SDK - Unit Tests for vmprog_stream_reader.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/vmprog_stream_reader.hpp>
#include <iostream>
#include <cassert>
#include <cstring>
#include <vector>

using namespace lzx;

// Mock stream implementation for testing
class mock_vmprog_stream : public vmprog_stream {
private:
    std::vector<uint8_t> data_;
    size_t position_;

public:
    mock_vmprog_stream() : position_(0) {}

    void set_data(const std::vector<uint8_t>& data) {
        data_ = data;
        position_ = 0;
    }

    size_t read(uint8_t* buffer, size_t size) override {
        if (position_ >= data_.size()) {
            return 0;
        }

        size_t available = data_.size() - position_;
        size_t to_read = (size < available) ? size : available;

        memcpy(buffer, data_.data() + position_, to_read);
        position_ += to_read;

        return to_read;
    }

    bool seek(size_t offset) override {
        if (offset > data_.size()) {
            return false;
        }
        position_ = offset;
        return true;
    }

    // Additional helper methods for testing (not part of interface)
    size_t tell() const {
        return position_;
    }

    size_t size() const {
        return data_.size();
    }
};

// Helper to create a minimal valid header
vmprog_header_v1_0 create_test_header(uint32_t file_size) {
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = file_size;
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 1;
    header.toc_bytes = header.toc_count * sizeof(vmprog_toc_entry_v1_0);
    return header;
}

// Test reading header from stream
bool test_read_header() {
    mock_vmprog_stream stream;

    // Create test data
    vmprog_header_v1_0 test_header = create_test_header(1024);
    std::vector<uint8_t> data(reinterpret_cast<uint8_t*>(&test_header),
                              reinterpret_cast<uint8_t*>(&test_header) + sizeof(test_header));

    stream.set_data(data);

    // Read header
    vmprog_header_v1_0 read_header;
    auto result = read_vmprog_header(stream, read_header);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read header test - read failed" << std::endl;
        return false;
    }

    if (memcmp(&test_header, &read_header, sizeof(vmprog_header_v1_0)) != 0) {
        std::cerr << "FAILED: Read header test - data mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read header from stream test" << std::endl;
    return true;
}

// Test reading header with validation
bool test_read_and_validate_header() {
    mock_vmprog_stream stream;

    // Create test data
    vmprog_header_v1_0 test_header = create_test_header(1024);
    std::vector<uint8_t> data(reinterpret_cast<uint8_t*>(&test_header),
                              reinterpret_cast<uint8_t*>(&test_header) + sizeof(test_header));

    stream.set_data(data);

    // Read and validate
    vmprog_header_v1_0 read_header;
    auto result = read_and_validate_vmprog_header(stream, 1024, read_header);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read and validate header test - validation failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read and validate header test" << std::endl;
    return true;
}

// Test reading header with file size mismatch
bool test_read_header_size_mismatch() {
    mock_vmprog_stream stream;

    // Create test data with mismatched size
    vmprog_header_v1_0 test_header = create_test_header(2048);
    std::vector<uint8_t> data(reinterpret_cast<uint8_t*>(&test_header),
                              reinterpret_cast<uint8_t*>(&test_header) + sizeof(test_header));

    stream.set_data(data);

    // Try to validate with different file size
    vmprog_header_v1_0 read_header;
    auto result = read_and_validate_vmprog_header(stream, 1024, read_header);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Header size mismatch test - should have failed validation" << std::endl;
        return false;
    }

    std::cout << "PASSED: Header size mismatch detection test" << std::endl;
    return true;
}

// Test reading TOC entries
bool test_read_toc() {
    mock_vmprog_stream stream;

    // Create header
    vmprog_header_v1_0 header = create_test_header(1024);
    header.toc_count = 2;

    // Create TOC entries
    vmprog_toc_entry_v1_0 toc_entries[2];
    init_toc_entry(toc_entries[0]);
    init_toc_entry(toc_entries[1]);
    toc_entries[0].type = vmprog_toc_entry_type_v1_0::config;
    toc_entries[1].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;

    // Create data: header + TOC
    std::vector<uint8_t> data;
    data.insert(data.end(),
                reinterpret_cast<uint8_t*>(&header),
                reinterpret_cast<uint8_t*>(&header) + sizeof(header));
    data.insert(data.end(),
                reinterpret_cast<uint8_t*>(toc_entries),
                reinterpret_cast<uint8_t*>(toc_entries) + sizeof(toc_entries));

    stream.set_data(data);

    // Read TOC
    vmprog_toc_entry_v1_0 read_toc[2];
    auto result = read_vmprog_toc(stream, header, read_toc, 2);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read TOC test - read failed" << std::endl;
        return false;
    }

    if (read_toc[0].type != vmprog_toc_entry_type_v1_0::config ||
        read_toc[1].type != vmprog_toc_entry_type_v1_0::fpga_bitstream) {
        std::cerr << "FAILED: Read TOC test - data mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read TOC entries test" << std::endl;
    return true;
}

// Test reading TOC with buffer too small
bool test_read_toc_buffer_too_small() {
    mock_vmprog_stream stream;

    vmprog_header_v1_0 header = create_test_header(1024);
    header.toc_count = 3;

    std::vector<uint8_t> data(reinterpret_cast<uint8_t*>(&header),
                              reinterpret_cast<uint8_t*>(&header) + sizeof(header));
    stream.set_data(data);

    // Try to read 3 entries into buffer for 2
    vmprog_toc_entry_v1_0 read_toc[2];
    auto result = read_vmprog_toc(stream, header, read_toc, 2);

    if (result != vmprog_validation_result::invalid_toc_count) {
        std::cerr << "FAILED: TOC buffer too small test - should have failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: TOC buffer size validation test" << std::endl;
    return true;
}

// Test reading payload data
bool test_read_payload() {
    mock_vmprog_stream stream;

    // Create test payload
    const char* payload_data = "Test payload data";
    size_t payload_size = strlen(payload_data);

    // Create TOC entry pointing to payload
    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.offset = 0;
    entry.size = payload_size;

    // Set up stream data
    std::vector<uint8_t> data(payload_data, payload_data + payload_size);
    stream.set_data(data);

    // Read payload
    std::vector<uint8_t> buffer(payload_size);
    uint32_t bytes_read = 0;
    bool success = read_payload(stream, entry, buffer.data(), payload_size, &bytes_read);

    if (!success) {
        std::cerr << "FAILED: Read payload test - read failed" << std::endl;
        return false;
    }

    if (bytes_read != payload_size) {
        std::cerr << "FAILED: Read payload test - incorrect bytes read" << std::endl;
        return false;
    }

    if (memcmp(buffer.data(), payload_data, payload_size) != 0) {
        std::cerr << "FAILED: Read payload test - data mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read payload data test" << std::endl;
    return true;
}

// Test reading payload with buffer too small
bool test_read_payload_buffer_too_small() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.offset = 0;
    entry.size = 100;

    std::vector<uint8_t> data(100, 0xAA);
    stream.set_data(data);

    // Try to read into smaller buffer
    std::vector<uint8_t> buffer(50);
    bool success = read_payload(stream, entry, buffer.data(), 50, nullptr);

    if (success) {
        std::cerr << "FAILED: Payload buffer too small test - should have failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Payload buffer size validation test" << std::endl;
    return true;
}

// Test stream seeking
bool test_stream_seeking() {
    mock_vmprog_stream stream;

    std::vector<uint8_t> data = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    stream.set_data(data);

    // Seek to middle
    if (!stream.seek(5)) {
        std::cerr << "FAILED: Stream seeking test - seek failed" << std::endl;
        return false;
    }

    if (stream.tell() != 5) {
        std::cerr << "FAILED: Stream seeking test - incorrect position" << std::endl;
        return false;
    }

    // Read byte
    uint8_t byte;
    if (stream.read(&byte, 1) != 1 || byte != 5) {
        std::cerr << "FAILED: Stream seeking test - incorrect data read" << std::endl;
        return false;
    }

    // Seek to start
    if (!stream.seek(0)) {
        std::cerr << "FAILED: Stream seeking test - seek to start failed" << std::endl;
        return false;
    }

    if (stream.read(&byte, 1) != 1 || byte != 0) {
        std::cerr << "FAILED: Stream seeking test - incorrect data at start" << std::endl;
        return false;
    }

    std::cout << "PASSED: Stream seeking test" << std::endl;
    return true;
}

// Test stream reading beyond end
bool test_stream_read_beyond_end() {
    mock_vmprog_stream stream;

    std::vector<uint8_t> data = {1, 2, 3, 4, 5};
    stream.set_data(data);

    // Try to read more than available
    uint8_t buffer[10];
    size_t bytes_read = stream.read(buffer, 10);

    if (bytes_read != 5) {
        std::cerr << "FAILED: Read beyond end test - incorrect bytes read" << std::endl;
        return false;
    }

    // Verify partial read
    if (memcmp(buffer, data.data(), 5) != 0) {
        std::cerr << "FAILED: Read beyond end test - data mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Stream read beyond end test" << std::endl;
    return true;
}

// Helper to create a complete mock package with config
std::vector<uint8_t> create_mock_package_with_config() {
    std::vector<uint8_t> package;

    // Create config
    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.mock.package", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Mock Test Program", sizeof(config.program_name));
    safe_strncpy(config.author, "Test Author", sizeof(config.author));
    config.parameter_count = 0;

    // Calculate config hash
    uint8_t config_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), config_hash);

    // Create TOC entry for config
    vmprog_toc_entry_v1_0 config_toc;
    init_toc_entry(config_toc);
    config_toc.type = vmprog_toc_entry_type_v1_0::config;
    config_toc.offset = sizeof(vmprog_header_v1_0) + sizeof(vmprog_toc_entry_v1_0);
    config_toc.size = sizeof(vmprog_program_config_v1_0);
    memcpy(config_toc.sha256, config_hash, 32);

    // Create header
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = sizeof(vmprog_header_v1_0) + sizeof(vmprog_toc_entry_v1_0) + sizeof(vmprog_program_config_v1_0);
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 1;
    header.toc_bytes = sizeof(vmprog_toc_entry_v1_0);

    // Assemble package
    package.resize(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, &config_toc, sizeof(config_toc));
    memcpy(package.data() + config_toc.offset, &config, sizeof(config));

    return package;
}

// Helper to create a complete mock package with signed descriptor
std::vector<uint8_t> create_mock_package_with_signed_descriptor() {
    std::vector<uint8_t> package;

    // Create config
    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.signed.package", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Signed Test Program", sizeof(config.program_name));

    // Create signed descriptor
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), descriptor.config_sha256);
    descriptor.artifact_count = 1;
    descriptor.artifacts[0].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    // Fill with dummy hash
    for (int i = 0; i < 32; i++) {
        descriptor.artifacts[0].sha256[i] = static_cast<uint8_t>(i);
    }
    descriptor.build_id = 12345;

    // Calculate hashes
    uint8_t config_hash[32];
    uint8_t descriptor_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), config_hash);
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&descriptor), sizeof(descriptor), descriptor_hash);

    // Create TOC entries
    vmprog_toc_entry_v1_0 toc[2];

    // Config TOC entry
    init_toc_entry(toc[0]);
    toc[0].type = vmprog_toc_entry_type_v1_0::config;
    toc[0].offset = sizeof(vmprog_header_v1_0) + 2 * sizeof(vmprog_toc_entry_v1_0);
    toc[0].size = sizeof(vmprog_program_config_v1_0);
    memcpy(toc[0].sha256, config_hash, 32);

    // Signed descriptor TOC entry
    init_toc_entry(toc[1]);
    toc[1].type = vmprog_toc_entry_type_v1_0::signed_descriptor;
    toc[1].offset = toc[0].offset + toc[0].size;
    toc[1].size = sizeof(vmprog_signed_descriptor_v1_0);
    memcpy(toc[1].sha256, descriptor_hash, 32);

    // Create header
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = sizeof(vmprog_header_v1_0) + 2 * sizeof(vmprog_toc_entry_v1_0) +
                       sizeof(vmprog_program_config_v1_0) + sizeof(vmprog_signed_descriptor_v1_0);
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 2;
    header.toc_bytes = 2 * sizeof(vmprog_toc_entry_v1_0);

    // Assemble package
    package.resize(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, toc, 2 * sizeof(vmprog_toc_entry_v1_0));
    memcpy(package.data() + toc[0].offset, &config, sizeof(config));
    memcpy(package.data() + toc[1].offset, &descriptor, sizeof(descriptor));

    return package;
}

// Helper to create a complete mock package with signature
std::vector<uint8_t> create_mock_package_with_signature() {
    std::vector<uint8_t> package;

    // Create signed descriptor
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    // Fill with known data
    for (int i = 0; i < 32; i++) {
        descriptor.config_sha256[i] = static_cast<uint8_t>(i);
    }
    descriptor.artifact_count = 0;
    descriptor.build_id = 99999;

    // Create mock signature (64 bytes)
    uint8_t signature[64];
    for (int i = 0; i < 64; i++) {
        signature[i] = static_cast<uint8_t>(i * 2);
    }

    // Calculate hashes
    uint8_t descriptor_hash[32];
    uint8_t signature_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&descriptor), sizeof(descriptor), descriptor_hash);
    sha256_oneshot(signature, 64, signature_hash);

    // Create TOC entries
    vmprog_toc_entry_v1_0 toc[2];

    // Signed descriptor TOC entry
    init_toc_entry(toc[0]);
    toc[0].type = vmprog_toc_entry_type_v1_0::signed_descriptor;
    toc[0].offset = sizeof(vmprog_header_v1_0) + 2 * sizeof(vmprog_toc_entry_v1_0);
    toc[0].size = sizeof(vmprog_signed_descriptor_v1_0);
    memcpy(toc[0].sha256, descriptor_hash, 32);

    // Signature TOC entry
    init_toc_entry(toc[1]);
    toc[1].type = vmprog_toc_entry_type_v1_0::signature;
    toc[1].offset = toc[0].offset + toc[0].size;
    toc[1].size = 64;
    memcpy(toc[1].sha256, signature_hash, 32);

    // Create header
    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.flags = vmprog_header_flags_v1_0::signed_pkg;
    header.file_size = sizeof(vmprog_header_v1_0) + 2 * sizeof(vmprog_toc_entry_v1_0) +
                       sizeof(vmprog_signed_descriptor_v1_0) + 64;
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 2;
    header.toc_bytes = 2 * sizeof(vmprog_toc_entry_v1_0);

    // Assemble package
    package.resize(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, toc, 2 * sizeof(vmprog_toc_entry_v1_0));
    memcpy(package.data() + toc[0].offset, &descriptor, sizeof(descriptor));
    memcpy(package.data() + toc[1].offset, signature, 64);

    return package;
}

// Test read_and_verify_payload with valid hash
bool test_read_and_verify_payload() {
    mock_vmprog_stream stream;

    // Create simple package with payload
    const char* payload_data = "Test payload data for verification";
    size_t payload_size = strlen(payload_data);

    // Calculate hash
    uint8_t payload_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(payload_data), payload_size, payload_hash);

    // Create TOC entry
    vmprog_toc_entry_v1_0 toc_entry;
    init_toc_entry(toc_entry);
    toc_entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    toc_entry.offset = sizeof(vmprog_header_v1_0) + sizeof(vmprog_toc_entry_v1_0);
    toc_entry.size = static_cast<uint32_t>(payload_size);
    memcpy(toc_entry.sha256, payload_hash, 32);

    // Create package
    std::vector<uint8_t> package;
    vmprog_header_v1_0 header = create_test_header(toc_entry.offset + toc_entry.size);

    package.resize(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, &toc_entry, sizeof(toc_entry));
    memcpy(package.data() + toc_entry.offset, payload_data, payload_size);

    stream.set_data(package);

    // Read and verify payload
    std::vector<uint8_t> buffer(payload_size);
    auto result = read_and_verify_payload(stream, toc_entry, buffer.data(), buffer.size());

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read and verify payload - verification failed" << std::endl;
        return false;
    }

    if (memcmp(buffer.data(), payload_data, payload_size) != 0) {
        std::cerr << "FAILED: Read and verify payload - data mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read and verify payload test" << std::endl;
    return true;
}

// Test read_and_verify_payload with corrupted hash
bool test_read_and_verify_payload_corrupted() {
    mock_vmprog_stream stream;

    const char* payload_data = "Test payload data";
    size_t payload_size = strlen(payload_data);

    // Create TOC entry with wrong hash
    vmprog_toc_entry_v1_0 toc_entry;
    init_toc_entry(toc_entry);
    toc_entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    toc_entry.offset = sizeof(vmprog_header_v1_0) + sizeof(vmprog_toc_entry_v1_0);
    toc_entry.size = static_cast<uint32_t>(payload_size);
    // Intentionally wrong hash
    memset(toc_entry.sha256, 0xFF, 32);

    // Create package
    std::vector<uint8_t> package;
    vmprog_header_v1_0 header = create_test_header(toc_entry.offset + toc_entry.size);

    package.resize(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, &toc_entry, sizeof(toc_entry));
    memcpy(package.data() + toc_entry.offset, payload_data, payload_size);

    stream.set_data(package);

    // Attempt to read and verify - should fail
    std::vector<uint8_t> buffer(payload_size);
    auto result = read_and_verify_payload(stream, toc_entry, buffer.data(), buffer.size());

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read and verify corrupted payload - verification passed incorrectly" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read and verify corrupted payload test" << std::endl;
    return true;
}

// Test read_vmprog_config
bool test_read_vmprog_config() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_config();
    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 header;
    auto result = read_vmprog_header(stream, header);
    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read config - header read failed" << std::endl;
        return false;
    }

    vmprog_toc_entry_v1_0 toc[1];
    result = read_vmprog_toc(stream, header, toc, 1);
    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read config - TOC read failed" << std::endl;
        return false;
    }

    // Read config
    vmprog_program_config_v1_0 config;
    result = read_vmprog_config(stream, toc[0], config);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read config - config read failed" << std::endl;
        return false;
    }

    // Verify config data
    if (strcmp(config.program_id, "test.mock.package") != 0) {
        std::cerr << "FAILED: Read config - program_id mismatch" << std::endl;
        return false;
    }

    if (strcmp(config.program_name, "Mock Test Program") != 0) {
        std::cerr << "FAILED: Read config - program_name mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read vmprog config test" << std::endl;
    return true;
}

// Test read_and_validate_vmprog_config
bool test_read_and_validate_vmprog_config() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_config();
    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 header;
    read_vmprog_header(stream, header);

    vmprog_toc_entry_v1_0 toc[1];
    read_vmprog_toc(stream, header, toc, 1);

    // Read and validate config
    vmprog_program_config_v1_0 config;
    auto result = read_and_validate_vmprog_config(stream, toc[0], config);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read and validate config - validation failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read and validate vmprog config test" << std::endl;
    return true;
}

// Test read_signed_descriptor
bool test_read_signed_descriptor() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_signed_descriptor();
    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 header;
    read_vmprog_header(stream, header);

    vmprog_toc_entry_v1_0 toc[2];
    read_vmprog_toc(stream, header, toc, 2);

    // Find and read signed descriptor
    const vmprog_toc_entry_v1_0* desc_entry = nullptr;
    for (uint32_t i = 0; i < header.toc_count; i++) {
        if (toc[i].type == vmprog_toc_entry_type_v1_0::signed_descriptor) {
            desc_entry = &toc[i];
            break;
        }
    }

    if (!desc_entry) {
        std::cerr << "FAILED: Read signed descriptor - descriptor not found in TOC" << std::endl;
        return false;
    }

    vmprog_signed_descriptor_v1_0 descriptor;
    auto result = read_signed_descriptor(stream, *desc_entry, descriptor);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read signed descriptor - read failed" << std::endl;
        return false;
    }

    // Verify descriptor data
    if (descriptor.artifact_count != 1) {
        std::cerr << "FAILED: Read signed descriptor - artifact count mismatch" << std::endl;
        return false;
    }

    if (descriptor.build_id != 12345) {
        std::cerr << "FAILED: Read signed descriptor - build_id mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read signed descriptor test" << std::endl;
    return true;
}

// Test read_and_validate_signed_descriptor
bool test_read_and_validate_signed_descriptor() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_signed_descriptor();
    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 header;
    read_vmprog_header(stream, header);

    vmprog_toc_entry_v1_0 toc[2];
    read_vmprog_toc(stream, header, toc, 2);

    // Find descriptor entry
    const vmprog_toc_entry_v1_0* desc_entry = nullptr;
    for (uint32_t i = 0; i < header.toc_count; i++) {
        if (toc[i].type == vmprog_toc_entry_type_v1_0::signed_descriptor) {
            desc_entry = &toc[i];
            break;
        }
    }

    vmprog_signed_descriptor_v1_0 descriptor;
    auto result = read_and_validate_signed_descriptor(stream, *desc_entry, descriptor);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read and validate signed descriptor - validation failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read and validate signed descriptor test" << std::endl;
    return true;
}

// Test read_signature
bool test_read_signature() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_signature();
    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 header;
    read_vmprog_header(stream, header);

    vmprog_toc_entry_v1_0 toc[2];
    read_vmprog_toc(stream, header, toc, 2);

    // Find signature entry
    const vmprog_toc_entry_v1_0* sig_entry = nullptr;
    for (uint32_t i = 0; i < header.toc_count; i++) {
        if (toc[i].type == vmprog_toc_entry_type_v1_0::signature) {
            sig_entry = &toc[i];
            break;
        }
    }

    if (!sig_entry) {
        std::cerr << "FAILED: Read signature - signature not found in TOC" << std::endl;
        return false;
    }

    uint8_t signature[64];
    if (!read_signature(stream, *sig_entry, signature)) {
        std::cerr << "FAILED: Read signature - read failed" << std::endl;
        return false;
    }

    // Verify signature data (should be pattern 0, 2, 4, 6, ...)
    for (int i = 0; i < 64; i++) {
        if (signature[i] != static_cast<uint8_t>(i * 2)) {
            std::cerr << "FAILED: Read signature - signature data mismatch at byte " << i << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Read signature test" << std::endl;
    return true;
}

// Test verify_with_builtin_keys (integration test with format.hpp)
bool test_verify_with_builtin_keys_integration() {
    // Create a descriptor to test with
    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    for (int i = 0; i < 32; i++) {
        descriptor.config_sha256[i] = static_cast<uint8_t>(i);
    }
    descriptor.artifact_count = 0;

    // Create a dummy signature (will not verify with real keys)
    uint8_t signature[64];
    memset(signature, 0xAB, 64);

    // Test that verify_with_builtin_keys doesn't crash and returns false for invalid sig
    size_t key_index = 999;
    bool verified = verify_with_builtin_keys(signature, descriptor, &key_index);

    // Should return false since we have a dummy signature
    if (verified) {
        std::cerr << "FAILED: Verify with builtin keys - dummy signature incorrectly verified" << std::endl;
        return false;
    }

    // key_index should remain unchanged
    if (key_index != 999) {
        std::cerr << "FAILED: Verify with builtin keys - key_index modified on failure" << std::endl;
        return false;
    }

    std::cout << "PASSED: Verify with builtin keys integration test" << std::endl;
    return true;
}

// Test complete package validation workflow
bool test_complete_package_workflow() {
    mock_vmprog_stream stream;
    std::vector<uint8_t> package = create_mock_package_with_signed_descriptor();
    stream.set_data(package);

    // Step 1: Read and validate header
    vmprog_header_v1_0 header;
    auto result = read_and_validate_vmprog_header(stream, static_cast<uint32_t>(package.size()), header);
    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Complete workflow - header validation failed" << std::endl;
        return false;
    }

    // Step 2: Read and validate TOC
    vmprog_toc_entry_v1_0 toc[vmprog_stream_max_toc_entries];
    result = read_and_validate_vmprog_toc(stream, header, static_cast<uint32_t>(package.size()), toc, vmprog_stream_max_toc_entries);
    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Complete workflow - TOC validation failed" << std::endl;
        return false;
    }

    // Step 3: Find and read config
    const vmprog_toc_entry_v1_0* config_entry = find_toc_entry(toc, header.toc_count, vmprog_toc_entry_type_v1_0::config);
    if (config_entry) {
        vmprog_program_config_v1_0 config;
        result = read_and_validate_vmprog_config(stream, *config_entry, config);
        if (result != vmprog_validation_result::ok) {
            std::cerr << "FAILED: Complete workflow - config validation failed" << std::endl;
            return false;
        }
    }

    // Step 4: Find and read signed descriptor
    const vmprog_toc_entry_v1_0* desc_entry = find_toc_entry(toc, header.toc_count, vmprog_toc_entry_type_v1_0::signed_descriptor);
    if (desc_entry) {
        vmprog_signed_descriptor_v1_0 descriptor;
        result = read_and_validate_signed_descriptor(stream, *desc_entry, descriptor);
        if (result != vmprog_validation_result::ok) {
            std::cerr << "FAILED: Complete workflow - descriptor validation failed" << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Complete package workflow test" << std::endl;
    return true;
}

// Test reading config with invalid size
bool test_read_config_invalid_size() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 invalid_entry;
    init_toc_entry(invalid_entry);
    invalid_entry.type = vmprog_toc_entry_type_v1_0::config;
    invalid_entry.offset = 64;
    invalid_entry.size = 100; // Wrong size, should be sizeof(vmprog_program_config_v1_0)

    std::vector<uint8_t> data(200, 0);
    stream.set_data(data);

    vmprog_program_config_v1_0 config;
    auto result = read_vmprog_config(stream, invalid_entry, config);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read config invalid size - incorrect size not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read config invalid size test" << std::endl;
    return true;
}

// Test reading signed descriptor with invalid size
bool test_read_descriptor_invalid_size() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 invalid_entry;
    init_toc_entry(invalid_entry);
    invalid_entry.type = vmprog_toc_entry_type_v1_0::signed_descriptor;
    invalid_entry.offset = 64;
    invalid_entry.size = 50; // Wrong size

    std::vector<uint8_t> data(200, 0);
    stream.set_data(data);

    vmprog_signed_descriptor_v1_0 descriptor;
    auto result = read_signed_descriptor(stream, invalid_entry, descriptor);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read descriptor invalid size - incorrect size not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read descriptor invalid size test" << std::endl;
    return true;
}

// Test reading signature with invalid size
bool test_read_signature_invalid_size() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 invalid_entry;
    init_toc_entry(invalid_entry);
    invalid_entry.type = vmprog_toc_entry_type_v1_0::signature;
    invalid_entry.offset = 64;
    invalid_entry.size = 32; // Wrong size, should be 64

    std::vector<uint8_t> data(200, 0);
    stream.set_data(data);

    uint8_t signature[64];
    bool result = read_signature(stream, invalid_entry, signature);

    if (result) {
        std::cerr << "FAILED: Read signature invalid size - incorrect size not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read signature invalid size test" << std::endl;
    return true;
}

// Test TOC with zero entries
bool test_read_toc_zero_entries() {
    mock_vmprog_stream stream;

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = 128;
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.toc_count = 0; // No entries
    header.toc_bytes = 0;

    std::vector<uint8_t> package(128);
    memcpy(package.data(), &header, sizeof(header));
    stream.set_data(package);

    vmprog_toc_entry_v1_0 toc[1];
    auto result = read_vmprog_toc(stream, header, toc, 1);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read TOC zero entries - failed on valid zero count" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read TOC zero entries test" << std::endl;
    return true;
}

// Test TOC with maximum entries
bool test_read_toc_max_entries() {
    mock_vmprog_stream stream;

    const uint32_t max_entries = vmprog_stream_max_toc_entries;

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.toc_count = max_entries;
    header.toc_bytes = max_entries * sizeof(vmprog_toc_entry_v1_0);
    header.toc_offset = sizeof(vmprog_header_v1_0);
    header.file_size = header.toc_offset + header.toc_bytes;

    std::vector<uint8_t> package(header.file_size);
    memcpy(package.data(), &header, sizeof(header));

    // Initialize TOC entries
    for (uint32_t i = 0; i < max_entries; i++) {
        vmprog_toc_entry_v1_0 entry;
        init_toc_entry(entry);
        entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
        memcpy(package.data() + header.toc_offset + i * sizeof(entry), &entry, sizeof(entry));
    }

    stream.set_data(package);

    vmprog_toc_entry_v1_0 toc[vmprog_stream_max_toc_entries];
    auto result = read_vmprog_toc(stream, header, toc, max_entries);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read TOC max entries - failed on maximum valid count" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read TOC max entries test" << std::endl;
    return true;
}

// Test payload with zero size
bool test_read_payload_zero_size() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::config;
    entry.offset = 64;
    entry.size = 0; // Zero-length payload

    std::vector<uint8_t> data(200, 0);
    stream.set_data(data);

    uint8_t buffer[1];
    bool result = read_payload(stream, entry, buffer, 1, nullptr);

    if (!result) {
        std::cerr << "FAILED: Read payload zero size - failed on valid zero-length payload" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read payload zero size test" << std::endl;
    return true;
}

// Test header with corrupted magic number
bool test_read_header_corrupted_magic() {
    mock_vmprog_stream stream;

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.magic = 0xDEADBEEF; // Wrong magic
    header.file_size = 1024;

    std::vector<uint8_t> package(1024);
    memcpy(package.data(), &header, sizeof(header));
    stream.set_data(package);

    vmprog_header_v1_0 read_header;
    auto result = read_and_validate_vmprog_header(stream, 1024, read_header);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read header corrupted magic - invalid magic not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read header corrupted magic test" << std::endl;
    return true;
}

// Test package with multiple config entries (invalid)
bool test_package_multiple_configs() {
    mock_vmprog_stream stream;

    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);

    uint8_t config_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), config_hash);

    // Create 2 config TOC entries (invalid)
    vmprog_toc_entry_v1_0 toc[2];
    for (int i = 0; i < 2; i++) {
        init_toc_entry(toc[i]);
        toc[i].type = vmprog_toc_entry_type_v1_0::config;
        toc[i].offset = sizeof(vmprog_header_v1_0) + 2 * sizeof(vmprog_toc_entry_v1_0) + i * sizeof(config);
        toc[i].size = sizeof(config);
        memcpy(toc[i].sha256, config_hash, 32);
    }

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = sizeof(header) + 2 * sizeof(vmprog_toc_entry_v1_0) + 2 * sizeof(config);
    header.toc_offset = sizeof(header);
    header.toc_count = 2;
    header.toc_bytes = 2 * sizeof(vmprog_toc_entry_v1_0);

    std::vector<uint8_t> package(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, toc, 2 * sizeof(vmprog_toc_entry_v1_0));
    memcpy(package.data() + toc[0].offset, &config, sizeof(config));
    memcpy(package.data() + toc[1].offset, &config, sizeof(config));

    stream.set_data(package);

    // Read header and TOC
    vmprog_header_v1_0 read_header;
    read_vmprog_header(stream, read_header);

    vmprog_toc_entry_v1_0 read_toc[2];
    read_vmprog_toc(stream, read_header, read_toc, 2);

    // Count config entries - should detect duplicate
    uint32_t config_count = count_toc_entries(read_toc, read_header.toc_count, vmprog_toc_entry_type_v1_0::config);

    if (config_count != 2) {
        std::cerr << "FAILED: Package multiple configs - did not detect multiple configs" << std::endl;
        return false;
    }

    std::cout << "PASSED: Package multiple configs test" << std::endl;
    return true;
}

// Test reading from stream at wrong position
bool test_read_payload_wrong_position() {
    mock_vmprog_stream stream;

    const char* payload_data = "Test data";
    size_t payload_size = strlen(payload_data);

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    entry.offset = 100;
    entry.size = static_cast<uint32_t>(payload_size);

    std::vector<uint8_t> data(200, 0);
    memcpy(data.data() + entry.offset, payload_data, payload_size);
    stream.set_data(data);

    // Seek to wrong position
    stream.seek(50);

    // read_payload should seek to correct offset automatically
    std::vector<uint8_t> buffer(payload_size);
    bool result = read_payload(stream, entry, buffer.data(), buffer.size(), nullptr);

    if (!result || memcmp(buffer.data(), payload_data, payload_size) != 0) {
        std::cerr << "FAILED: Read payload wrong position - failed to seek correctly" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read payload wrong position test" << std::endl;
    return true;
}

// Test package with all bitstream types
bool test_package_all_bitstream_types() {
    mock_vmprog_stream stream;

    const uint32_t bitstream_count = 7;
    vmprog_toc_entry_type_v1_0 bitstream_types[] = {
        vmprog_toc_entry_type_v1_0::fpga_bitstream,
        vmprog_toc_entry_type_v1_0::bitstream_sd_analog,
        vmprog_toc_entry_type_v1_0::bitstream_sd_hdmi,
        vmprog_toc_entry_type_v1_0::bitstream_sd_dual,
        vmprog_toc_entry_type_v1_0::bitstream_hd_analog,
        vmprog_toc_entry_type_v1_0::bitstream_hd_hdmi,
        vmprog_toc_entry_type_v1_0::bitstream_hd_dual
    };

    vmprog_toc_entry_v1_0 toc[bitstream_count];
    uint32_t current_offset = sizeof(vmprog_header_v1_0) + bitstream_count * sizeof(vmprog_toc_entry_v1_0);

    for (uint32_t i = 0; i < bitstream_count; i++) {
        init_toc_entry(toc[i]);
        toc[i].type = bitstream_types[i];
        toc[i].offset = current_offset;
        toc[i].size = 16;
        current_offset += 16;
    }

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = current_offset;
    header.toc_offset = sizeof(header);
    header.toc_count = bitstream_count;
    header.toc_bytes = bitstream_count * sizeof(vmprog_toc_entry_v1_0);

    std::vector<uint8_t> package(header.file_size, 0xAB);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, toc, bitstream_count * sizeof(vmprog_toc_entry_v1_0));

    stream.set_data(package);

    vmprog_header_v1_0 read_header;
    read_vmprog_header(stream, read_header);

    vmprog_toc_entry_v1_0 read_toc[bitstream_count];
    auto result = read_vmprog_toc(stream, read_header, read_toc, bitstream_count);

    if (result != vmprog_validation_result::ok) {
        std::cerr << "FAILED: Package all bitstream types - reading failed" << std::endl;
        return false;
    }

    // Verify all types present
    for (uint32_t i = 0; i < bitstream_count; i++) {
        if (read_toc[i].type != bitstream_types[i]) {
            std::cerr << "FAILED: Package all bitstream types - type mismatch at index " << i << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Package all bitstream types test" << std::endl;
    return true;
}

// Test verify payload with empty hash
bool test_verify_payload_empty_hash() {
    mock_vmprog_stream stream;

    const char* payload_data = "Data";
    size_t payload_size = strlen(payload_data);

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    entry.offset = 64;
    entry.size = static_cast<uint32_t>(payload_size);
    memset(entry.sha256, 0, 32); // Empty hash

    std::vector<uint8_t> data(200, 0);
    memcpy(data.data() + entry.offset, payload_data, payload_size);
    stream.set_data(data);

    std::vector<uint8_t> buffer(payload_size);
    auto result = read_and_verify_payload(stream, entry, buffer.data(), buffer.size());

    // Should fail since hash doesn't match
    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Verify payload empty hash - empty hash verified" << std::endl;
        return false;
    }

    std::cout << "PASSED: Verify payload empty hash test" << std::endl;
    return true;
}

// Test config with invalid program_id (empty)
bool test_config_empty_program_id() {
    mock_vmprog_stream stream;

    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    config.program_id[0] = '\0'; // Empty program_id (invalid)
    safe_strncpy(config.program_name, "Test", sizeof(config.program_name));

    uint8_t config_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), config_hash);

    vmprog_toc_entry_v1_0 toc_entry;
    init_toc_entry(toc_entry);
    toc_entry.type = vmprog_toc_entry_type_v1_0::config;
    toc_entry.offset = 64;
    toc_entry.size = sizeof(config);
    memcpy(toc_entry.sha256, config_hash, 32);

    std::vector<uint8_t> data(64 + sizeof(config));
    memcpy(data.data() + toc_entry.offset, &config, sizeof(config));
    stream.set_data(data);

    vmprog_program_config_v1_0 read_config;
    auto result = read_and_validate_vmprog_config(stream, toc_entry, read_config);

    // Should fail validation
    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Config empty program_id - empty ID not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Config empty program_id test" << std::endl;
    return true;
}

// Test descriptor with artifact count overflow
bool test_descriptor_artifact_overflow() {
    mock_vmprog_stream stream;

    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    descriptor.artifact_count = 255; // Way over max (8)

    uint8_t desc_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&descriptor), sizeof(descriptor), desc_hash);

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::signed_descriptor;
    entry.offset = 64;
    entry.size = sizeof(descriptor);
    memcpy(entry.sha256, desc_hash, 32);

    std::vector<uint8_t> data(64 + sizeof(descriptor));
    memcpy(data.data() + entry.offset, &descriptor, sizeof(descriptor));
    stream.set_data(data);

    vmprog_signed_descriptor_v1_0 read_desc;
    auto result = read_and_validate_signed_descriptor(stream, entry, read_desc);

    // Should fail validation
    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Descriptor artifact overflow - overflow not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Descriptor artifact overflow test" << std::endl;
    return true;
}

// Test stream seek failure handling
bool test_stream_seek_failure() {
    mock_vmprog_stream stream;

    std::vector<uint8_t> data(100);
    stream.set_data(data);

    // Try to seek beyond end
    bool result = stream.seek(200);

    if (result) {
        std::cerr << "FAILED: Stream seek failure - seek beyond end succeeded" << std::endl;
        return false;
    }

    std::cout << "PASSED: Stream seek failure test" << std::endl;
    return true;
}

// Test reading header from empty stream
bool test_read_header_empty_stream() {
    mock_vmprog_stream stream;

    std::vector<uint8_t> empty_data;
    stream.set_data(empty_data);

    vmprog_header_v1_0 header;
    auto result = read_vmprog_header(stream, header);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Read header empty stream - succeeded on empty stream" << std::endl;
        return false;
    }

    std::cout << "PASSED: Read header empty stream test" << std::endl;
    return true;
}

// Test TOC entry with payload beyond file size
bool test_toc_payload_beyond_file() {
    mock_vmprog_stream stream;

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::fpga_bitstream;
    entry.offset = 150;
    entry.size = 100; // offset + size = 250 > file_size

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.file_size = 200; // File too small for payload (offset=150 + size=100 > 200)
    header.toc_offset = sizeof(header);
    header.toc_count = 1;
    header.toc_bytes = sizeof(vmprog_toc_entry_v1_0);

    std::vector<uint8_t> package(200);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, &entry, sizeof(entry));
    stream.set_data(package);

    vmprog_header_v1_0 read_header;
    read_vmprog_header(stream, read_header);

    vmprog_toc_entry_v1_0 read_toc[1];
    read_vmprog_toc(stream, read_header, read_toc, 1);

    // Validate should fail (150 > 200 - 100, i.e., 150 > 100)
    auto result = validate_vmprog_toc_entry_v1_0(read_toc[0], header.file_size);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: TOC payload beyond file - invalid offset not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: TOC payload beyond file test" << std::endl;
    return true;
}

// Test package with signed flag but no signature
bool test_signed_package_missing_signature() {
    mock_vmprog_stream stream;

    vmprog_signed_descriptor_v1_0 descriptor;
    init_signed_descriptor(descriptor);
    descriptor.artifact_count = 0;

    uint8_t desc_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&descriptor), sizeof(descriptor), desc_hash);

    vmprog_toc_entry_v1_0 toc;
    init_toc_entry(toc);
    toc.type = vmprog_toc_entry_type_v1_0::signed_descriptor;
    toc.offset = sizeof(vmprog_header_v1_0) + sizeof(vmprog_toc_entry_v1_0);
    toc.size = sizeof(descriptor);
    memcpy(toc.sha256, desc_hash, 32);

    vmprog_header_v1_0 header;
    init_vmprog_header(header);
    header.flags = vmprog_header_flags_v1_0::signed_pkg; // Marked as signed
    header.file_size = sizeof(header) + sizeof(toc) + sizeof(descriptor);
    header.toc_offset = sizeof(header);
    header.toc_count = 1;
    header.toc_bytes = sizeof(toc);

    std::vector<uint8_t> package(header.file_size);
    memcpy(package.data(), &header, sizeof(header));
    memcpy(package.data() + header.toc_offset, &toc, sizeof(toc));
    memcpy(package.data() + toc.offset, &descriptor, sizeof(descriptor));

    stream.set_data(package);

    vmprog_header_v1_0 read_header;
    read_vmprog_header(stream, read_header);

    vmprog_toc_entry_v1_0 read_toc[1];
    read_vmprog_toc(stream, read_header, read_toc, 1);

    // Check if signed flag is set
    if (!is_package_signed(read_header)) {
        std::cerr << "FAILED: Signed package missing signature - flag not detected" << std::endl;
        return false;
    }

    // Check if signature entry exists
    bool has_sig = has_toc_entry(read_toc, read_header.toc_count, vmprog_toc_entry_type_v1_0::signature);

    if (has_sig) {
        std::cerr << "FAILED: Signed package missing signature - signature entry found" << std::endl;
        return false;
    }

    std::cout << "PASSED: Signed package missing signature test" << std::endl;
    return true;
}

// Test reading config with invalid ABI range
bool test_config_invalid_abi_range() {
    mock_vmprog_stream stream;

    vmprog_program_config_v1_0 config;
    init_vmprog_config(config);
    safe_strncpy(config.program_id, "test.package", sizeof(config.program_id));
    safe_strncpy(config.program_name, "Test", sizeof(config.program_name));
    config.abi_min_major = 2;
    config.abi_min_minor = 0;
    config.abi_max_major = 1; // Max < Min (invalid)
    config.abi_max_minor = 0;

    uint8_t config_hash[32];
    sha256_oneshot(reinterpret_cast<const uint8_t*>(&config), sizeof(config), config_hash);

    vmprog_toc_entry_v1_0 entry;
    init_toc_entry(entry);
    entry.type = vmprog_toc_entry_type_v1_0::config;
    entry.offset = 64;
    entry.size = sizeof(config);
    memcpy(entry.sha256, config_hash, 32);

    std::vector<uint8_t> data(64 + sizeof(config));
    memcpy(data.data() + entry.offset, &config, sizeof(config));
    stream.set_data(data);

    vmprog_program_config_v1_0 read_config;
    auto result = read_and_validate_vmprog_config(stream, entry, read_config);

    if (result == vmprog_validation_result::ok) {
        std::cerr << "FAILED: Config invalid ABI range - invalid range not detected" << std::endl;
        return false;
    }

    std::cout << "PASSED: Config invalid ABI range test" << std::endl;
    return true;
}

// Test finding TOC entry by type
bool test_find_toc_entry_by_type() {
    vmprog_toc_entry_v1_0 toc[3];

    init_toc_entry(toc[0]);
    toc[0].type = vmprog_toc_entry_type_v1_0::config;

    init_toc_entry(toc[1]);
    toc[1].type = vmprog_toc_entry_type_v1_0::signed_descriptor;

    init_toc_entry(toc[2]);
    toc[2].type = vmprog_toc_entry_type_v1_0::fpga_bitstream;

    // Find descriptor
    const vmprog_toc_entry_v1_0* found = find_toc_entry(toc, 3, vmprog_toc_entry_type_v1_0::signed_descriptor);

    if (!found || found->type != vmprog_toc_entry_type_v1_0::signed_descriptor) {
        std::cerr << "FAILED: Find TOC entry by type - descriptor not found" << std::endl;
        return false;
    }

    // Try to find non-existent type
    const vmprog_toc_entry_v1_0* not_found = find_toc_entry(toc, 3, vmprog_toc_entry_type_v1_0::signature);

    if (not_found != nullptr) {
        std::cerr << "FAILED: Find TOC entry by type - found non-existent entry" << std::endl;
        return false;
    }

    std::cout << "PASSED: Find TOC entry by type test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "============================================" << std::endl;
    std::cout << "Videomancer vmprog_stream_reader.hpp Tests" << std::endl;
    std::cout << "============================================" << std::endl;
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

    RUN_TEST(test_stream_seeking);
    RUN_TEST(test_stream_read_beyond_end);
    RUN_TEST(test_read_header);
    RUN_TEST(test_read_and_validate_header);
    RUN_TEST(test_read_header_size_mismatch);
    RUN_TEST(test_read_toc);
    RUN_TEST(test_read_toc_buffer_too_small);
    RUN_TEST(test_read_payload);
    RUN_TEST(test_read_payload_buffer_too_small);
    RUN_TEST(test_read_and_verify_payload);
    RUN_TEST(test_read_and_verify_payload_corrupted);
    RUN_TEST(test_read_vmprog_config);
    RUN_TEST(test_read_and_validate_vmprog_config);
    RUN_TEST(test_read_signed_descriptor);
    RUN_TEST(test_read_and_validate_signed_descriptor);
    RUN_TEST(test_read_signature);
    RUN_TEST(test_verify_with_builtin_keys_integration);
    RUN_TEST(test_complete_package_workflow);
    RUN_TEST(test_read_config_invalid_size);
    RUN_TEST(test_read_descriptor_invalid_size);
    RUN_TEST(test_read_signature_invalid_size);
    RUN_TEST(test_read_toc_zero_entries);
    RUN_TEST(test_read_toc_max_entries);
    RUN_TEST(test_read_payload_zero_size);
    RUN_TEST(test_read_header_corrupted_magic);
    RUN_TEST(test_package_multiple_configs);
    RUN_TEST(test_read_payload_wrong_position);
    RUN_TEST(test_package_all_bitstream_types);
    RUN_TEST(test_verify_payload_empty_hash);
    RUN_TEST(test_config_empty_program_id);
    RUN_TEST(test_descriptor_artifact_overflow);
    RUN_TEST(test_stream_seek_failure);
    RUN_TEST(test_read_header_empty_stream);
    RUN_TEST(test_toc_payload_beyond_file);
    RUN_TEST(test_signed_package_missing_signature);
    RUN_TEST(test_config_invalid_abi_range);
    RUN_TEST(test_find_toc_entry_by_type);

    std::cout << std::endl;
    std::cout << "============================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "============================================" << std::endl;

    return (passed == total) ? 0 : 1;
}
