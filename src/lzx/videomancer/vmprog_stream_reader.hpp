// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_stream_reader.hpp - VMProg Package Stream-based Reading
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

#pragma once

#include "vmprog_stream.hpp"
#include "vmprog_format.hpp"

namespace lzx {

// Maximum TOC entries supported by stream reader (matches validation limit)
constexpr size_t vmprog_stream_max_toc_entries = 16;

// =============================================================================
// Stream-based Reading Functions
// =============================================================================

/**
 * @brief Read and validate vmprog header from stream.
 *
 * @param stream Input stream positioned at start of file
 * @param out_header Output header structure
 * @return Validation result code
 */
inline vmprog_validation_result read_vmprog_header(
    vmprog_stream& stream,
    vmprog_header_v1_0& out_header
) {
    // Seek to start
    if (!stream.seek(0)) {
        return vmprog_validation_result::invalid_file_size;
    }

    // Read header
    size_t bytes_read = stream.read(reinterpret_cast<uint8_t*>(&out_header), sizeof(vmprog_header_v1_0));
    if (bytes_read != sizeof(vmprog_header_v1_0)) {
        return vmprog_validation_result::invalid_file_size;
    }

    // Note: Validation against actual file size should be done separately
    // since streams may not know their total size
    return vmprog_validation_result::ok;
}

/**
 * @brief Read and validate complete package header with file size validation.
 *
 * @param stream Input stream positioned at start of file
 * @param file_size Total file size in bytes
 * @param out_header Output header structure
 * @return Validation result code
 */
inline vmprog_validation_result read_and_validate_vmprog_header(
    vmprog_stream& stream,
    uint32_t file_size,
    vmprog_header_v1_0& out_header
) {
    auto result = read_vmprog_header(stream, out_header);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    return validate_vmprog_header_v1_0(out_header, file_size);
}

/**
 * @brief Read TOC entries from stream.
 *
 * @param stream Input stream
 * @param header Validated package header
 * @param out_toc Output buffer to store TOC entries (must be at least header.toc_count entries)
 * @param max_toc_entries Maximum number of entries that can be stored in out_toc
 * @return Validation result code
 */
inline vmprog_validation_result read_vmprog_toc(
    vmprog_stream& stream,
    const vmprog_header_v1_0& header,
    vmprog_toc_entry_v1_0* out_toc,
    uint32_t max_toc_entries
) {
    // Check buffer size
    if (header.toc_count > max_toc_entries) {
        return vmprog_validation_result::invalid_toc_count;
    }

    // Seek to TOC offset
    if (!stream.seek(header.toc_offset)) {
        return vmprog_validation_result::invalid_toc_offset;
    }

    // Read all TOC entries
    size_t bytes_to_read = header.toc_count * sizeof(vmprog_toc_entry_v1_0);
    size_t bytes_read = stream.read(reinterpret_cast<uint8_t*>(out_toc), bytes_to_read);

    if (bytes_read != bytes_to_read) {
        return vmprog_validation_result::invalid_toc_size;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read and validate TOC entries from stream.
 *
 * @param stream Input stream
 * @param header Validated package header
 * @param file_size Total file size in bytes
 * @param out_toc Output buffer to store TOC entries (must be at least header.toc_count entries)
 * @param max_toc_entries Maximum number of entries that can be stored in out_toc
 * @return Validation result code
 */
inline vmprog_validation_result read_and_validate_vmprog_toc(
    vmprog_stream& stream,
    const vmprog_header_v1_0& header,
    uint32_t file_size,
    vmprog_toc_entry_v1_0* out_toc,
    uint32_t max_toc_entries
) {
    auto result = read_vmprog_toc(stream, header, out_toc, max_toc_entries);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Validate each TOC entry
    for (uint32_t i = 0; i < header.toc_count; ++i) {
        result = validate_vmprog_toc_entry_v1_0(out_toc[i], file_size);
        if (result != vmprog_validation_result::ok) {
            return result;
        }
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read payload data from stream based on TOC entry.
 *
 * @param stream Input stream
 * @param entry TOC entry specifying payload location
 * @param out_payload Output buffer to store payload data (must be at least entry.size bytes)
 * @param max_payload_size Maximum size of out_payload buffer
 * @param out_bytes_read Optional output parameter for actual bytes read
 * @return true if read succeeded
 */
inline bool read_payload(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    uint8_t* out_payload,
    uint32_t max_payload_size,
    uint32_t* out_bytes_read = nullptr
) {
    // Check buffer size
    if (entry.size > max_payload_size) {
        return false;
    }

    // Seek to payload offset
    if (!stream.seek(entry.offset)) {
        return false;
    }

    // Read payload data
    size_t bytes_read = stream.read(out_payload, entry.size);
    if (out_bytes_read) {
        *out_bytes_read = static_cast<uint32_t>(bytes_read);
    }
    return bytes_read == entry.size;
}

/**
 * @brief Read and verify payload data with hash validation.
 *
 * @param stream Input stream
 * @param entry TOC entry specifying payload location and expected hash
 * @param out_payload Output buffer to store payload data (must be at least entry.size bytes)
 * @param max_payload_size Maximum size of out_payload buffer
 * @return Validation result code
 */
inline vmprog_validation_result read_and_verify_payload(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    uint8_t* out_payload,
    uint32_t max_payload_size
) {
    uint32_t bytes_read = 0;
    if (!read_payload(stream, entry, out_payload, max_payload_size, &bytes_read)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    // Verify hash
    if (!verify_payload_hash(out_payload, bytes_read, entry.sha256)) {
        return vmprog_validation_result::invalid_hash;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read program configuration from stream.
 *
 * @param stream Input stream
 * @param entry TOC entry for config
 * @param out_config Output configuration structure
 * @return Validation result code
 */
inline vmprog_validation_result read_vmprog_config(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    vmprog_program_config_v1_0& out_config
) {
    // Validate entry type and size
    if (entry.type != vmprog_toc_entry_type_v1_0::config) {
        return vmprog_validation_result::invalid_toc_entry;
    }
    if (entry.size != sizeof(vmprog_program_config_v1_0)) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Seek to config offset
    if (!stream.seek(entry.offset)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    // Read config
    size_t bytes_read = stream.read(reinterpret_cast<uint8_t*>(&out_config), sizeof(vmprog_program_config_v1_0));
    if (bytes_read != sizeof(vmprog_program_config_v1_0)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read and validate program configuration from stream.
 *
 * @param stream Input stream
 * @param entry TOC entry for config
 * @param out_config Output configuration structure
 * @param should_verify_hash If true, verify hash against TOC entry
 * @return Validation result code
 */
inline vmprog_validation_result read_and_validate_vmprog_config(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    vmprog_program_config_v1_0& out_config,
    bool should_verify_hash = true
) {
    auto result = read_vmprog_config(stream, entry, out_config);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Validate config structure
    result = validate_vmprog_program_config_v1_0(out_config);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Verify hash if requested
    if (should_verify_hash) {
        if (!verify_hash(reinterpret_cast<const uint8_t*>(&out_config),
                        sizeof(vmprog_program_config_v1_0),
                        entry.sha256)) {
            return vmprog_validation_result::invalid_hash;
        }
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read signed descriptor from stream.
 *
 * @param stream Input stream
 * @param entry TOC entry for signed descriptor
 * @param out_descriptor Output descriptor structure
 * @return Validation result code
 */
inline vmprog_validation_result read_signed_descriptor(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    vmprog_signed_descriptor_v1_0& out_descriptor
) {
    // Validate entry type and size
    if (entry.type != vmprog_toc_entry_type_v1_0::signed_descriptor) {
        return vmprog_validation_result::invalid_toc_entry;
    }
    if (entry.size != sizeof(vmprog_signed_descriptor_v1_0)) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Seek to descriptor offset
    if (!stream.seek(entry.offset)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    // Read descriptor
    size_t bytes_read = stream.read(reinterpret_cast<uint8_t*>(&out_descriptor), sizeof(vmprog_signed_descriptor_v1_0));
    if (bytes_read != sizeof(vmprog_signed_descriptor_v1_0)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read and validate signed descriptor from stream.
 *
 * @param stream Input stream
 * @param entry TOC entry for signed descriptor
 * @param out_descriptor Output descriptor structure
 * @return Validation result code
 */
inline vmprog_validation_result read_and_validate_signed_descriptor(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    vmprog_signed_descriptor_v1_0& out_descriptor
) {
    auto result = read_signed_descriptor(stream, entry, out_descriptor);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    return validate_vmprog_signed_descriptor_v1_0(out_descriptor);
}

/**
 * @brief Read Ed25519 signature from stream.
 *
 * @param stream Input stream
 * @param entry TOC entry for signature
 * @param out_signature Output signature buffer (must be 64 bytes)
 * @return true if read succeeded
 */
inline bool read_signature(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0& entry,
    uint8_t out_signature[64]
) {
    // Validate entry type and size
    if (entry.type != vmprog_toc_entry_type_v1_0::signature) {
        return false;
    }
    if (entry.size != VMPROG_SIGNATURE_SIZE) {
        return false;
    }

    // Seek to signature offset
    if (!stream.seek(entry.offset)) {
        return false;
    }

    // Read signature
    size_t bytes_read = stream.read(out_signature, VMPROG_SIGNATURE_SIZE);
    return bytes_read == VMPROG_SIGNATURE_SIZE;
}

/**
 * @brief Find and read specific TOC entry by type.
 *
 * @param stream Input stream
 * @param toc TOC entries array
 * @param toc_count Number of TOC entries
 * @param type Entry type to find
 * @param out_payload Output buffer to store payload data
 * @param max_payload_size Maximum size of out_payload buffer
 * @param out_bytes_read Optional output parameter for actual bytes read
 * @return Validation result code
 */
inline vmprog_validation_result find_and_read_payload(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    vmprog_toc_entry_type_v1_0 type,
    uint8_t* out_payload,
    uint32_t max_payload_size,
    uint32_t* out_bytes_read = nullptr
) {
    // Find entry
    const vmprog_toc_entry_v1_0* entry = find_toc_entry(toc, toc_count, type);
    if (!entry) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Read payload
    if (!read_payload(stream, *entry, out_payload, max_payload_size, out_bytes_read)) {
        return vmprog_validation_result::invalid_payload_offset;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Verify all payload hashes in TOC using stream.
 *
 * @param stream Input stream
 * @param toc TOC entries array
 * @param toc_count Number of TOC entries
 * @param scratch_buffer Temporary buffer for reading payloads
 * @param scratch_buffer_size Size of scratch buffer
 * @return Validation result code
 */
inline vmprog_validation_result verify_all_payload_hashes_stream(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    uint8_t* scratch_buffer,
    uint32_t scratch_buffer_size
) {
    for (uint32_t i = 0; i < toc_count; ++i) {
        const auto& entry = toc[i];

        // Skip entries with no payload
        if (entry.size == 0) continue;

        // Check if payload fits in scratch buffer
        if (entry.size > scratch_buffer_size) {
            return vmprog_validation_result::invalid_payload_offset;
        }

        // Read payload
        uint32_t bytes_read = 0;
        if (!read_payload(stream, entry, scratch_buffer, scratch_buffer_size, &bytes_read)) {
            return vmprog_validation_result::invalid_payload_offset;
        }

        // Verify hash
        if (!verify_hash(scratch_buffer, bytes_read, entry.sha256)) {
            return vmprog_validation_result::invalid_hash;
        }
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Read and verify package signature using stream.
 *
 * @param stream Input stream
 * @param toc TOC entries array
 * @param toc_count Number of TOC entries
 * @param public_key Ed25519 public key (32 bytes)
 * @return Validation result code
 */
inline vmprog_validation_result verify_package_signature_stream(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    const uint8_t* public_key
) {
    // Find signed descriptor
    const vmprog_toc_entry_v1_0* desc_entry = find_toc_entry(
        toc, toc_count, vmprog_toc_entry_type_v1_0::signed_descriptor);
    if (!desc_entry) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Read descriptor
    vmprog_signed_descriptor_v1_0 descriptor;
    auto result = read_and_validate_signed_descriptor(stream, *desc_entry, descriptor);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Find signature
    const vmprog_toc_entry_v1_0* sig_entry = find_toc_entry(
        toc, toc_count, vmprog_toc_entry_type_v1_0::signature);
    if (!sig_entry) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Read signature
    uint8_t signature[64];
    if (!read_signature(stream, *sig_entry, signature)) {
        return vmprog_validation_result::invalid_hash;
    }

    // Verify signature
    if (!verify_ed25519_signature(signature, public_key, descriptor)) {
        return vmprog_validation_result::invalid_hash;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Verify package signature with built-in public keys using stream.
 *
 * @param stream Input stream
 * @param toc TOC entries array
 * @param toc_count Number of TOC entries
 * @param out_key_index Optional output parameter for which key succeeded
 * @return Validation result code
 */
inline vmprog_validation_result verify_package_signature_builtin_keys_stream(
    vmprog_stream& stream,
    const vmprog_toc_entry_v1_0* toc,
    uint32_t toc_count,
    size_t* out_key_index = nullptr
) {
    // Find signed descriptor
    const vmprog_toc_entry_v1_0* desc_entry = find_toc_entry(
        toc, toc_count, vmprog_toc_entry_type_v1_0::signed_descriptor);
    if (!desc_entry) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Read descriptor
    vmprog_signed_descriptor_v1_0 descriptor;
    auto result = read_and_validate_signed_descriptor(stream, *desc_entry, descriptor);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Find signature
    const vmprog_toc_entry_v1_0* sig_entry = find_toc_entry(
        toc, toc_count, vmprog_toc_entry_type_v1_0::signature);
    if (!sig_entry) {
        return vmprog_validation_result::invalid_toc_entry;
    }

    // Read signature
    uint8_t signature[64];
    if (!read_signature(stream, *sig_entry, signature)) {
        return vmprog_validation_result::invalid_hash;
    }

    // Try each built-in public key
    if (!verify_with_builtin_keys(signature, descriptor, out_key_index)) {
        return vmprog_validation_result::invalid_hash;
    }

    return vmprog_validation_result::ok;
}

/**
 * @brief Comprehensively validate a vmprog package using stream-based reading.
 *
 * This performs validation in stages:
 * 1. Read and validate header
 * 2. Read and validate TOC
 * 3. Optionally verify all payload hashes
 * 4. Optionally verify package signature
 *
 * @param stream Input stream positioned at start of file
 * @param file_size Total file size in bytes
 * @param verify_hashes If true, verify all payload hashes
 * @param verify_signature If true and package is signed, verify signature
 * @param public_key Public key for signature verification (32 bytes, optional)
 * @param scratch_buffer Temporary buffer for hash verification (required if verify_hashes=true)
 * @param scratch_buffer_size Size of scratch buffer (should be at least max expected payload size)
 * @return Validation result code
 */
inline vmprog_validation_result validate_vmprog_package_stream(
    vmprog_stream& stream,
    uint32_t file_size,
    bool verify_hashes = true,
    bool verify_signature = false,
    const uint8_t* public_key = nullptr,
    uint8_t* scratch_buffer = nullptr,
    uint32_t scratch_buffer_size = 0
) {
    // Read and validate header
    vmprog_header_v1_0 header;
    auto result = read_and_validate_vmprog_header(stream, file_size, header);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Read and validate TOC
    vmprog_toc_entry_v1_0 toc[vmprog_stream_max_toc_entries];
    result = read_and_validate_vmprog_toc(stream, header, file_size, toc, vmprog_stream_max_toc_entries);
    if (result != vmprog_validation_result::ok) {
        return result;
    }

    // Verify payload hashes if requested
    if (verify_hashes) {
        if (!scratch_buffer || scratch_buffer_size == 0) {
            return vmprog_validation_result::invalid_file_size; // Need scratch buffer for verification
        }
        result = verify_all_payload_hashes_stream(stream, toc, header.toc_count, scratch_buffer, scratch_buffer_size);
        if (result != vmprog_validation_result::ok) {
            return result;
        }
    }

    // Find and validate config if present
    const vmprog_toc_entry_v1_0* config_entry = find_toc_entry(
        toc, header.toc_count, vmprog_toc_entry_type_v1_0::config);

    if (config_entry && config_entry->size == sizeof(vmprog_program_config_v1_0)) {
        vmprog_program_config_v1_0 config;
        result = read_and_validate_vmprog_config(stream, *config_entry, config, verify_hashes);
        if (result != vmprog_validation_result::ok) {
            return result;
        }
    }

    // Verify signature if requested
    if (verify_signature && is_package_signed(header)) {
        if (public_key) {
            result = verify_package_signature_stream(stream, toc, header.toc_count, public_key);
        } else {
            result = verify_package_signature_builtin_keys_stream(stream, toc, header.toc_count);
        }
        if (result != vmprog_validation_result::ok) {
            return result;
        }
    }

    return vmprog_validation_result::ok;
}

// =============================================================================
// High-level Package Reading Helper Class
// =============================================================================

/**
 * @brief High-level reader for vmprog packages using streams.
 *
 * Provides convenient access to package contents with automatic validation.
 */
class vmprog_package_reader {
public:
    /**
     * @brief Open and validate a vmprog package.
     *
     * @param stream Stream to read from
     * @param file_size Total file size in bytes
     * @param verify_hashes If true, verify all payload hashes
     * @param scratch_buffer Temporary buffer for hash verification (required if verify_hashes=true)
     * @param scratch_buffer_size Size of scratch buffer
     * @return Validation result code
     */
    vmprog_validation_result open(
        vmprog_stream& stream,
        uint32_t file_size,
        bool verify_hashes = true,
        uint8_t* scratch_buffer = nullptr,
        uint32_t scratch_buffer_size = 0
    ) {
        stream_ = &stream;
        file_size_ = file_size;

        // Read and validate header
        auto result = read_and_validate_vmprog_header(stream, file_size, header_);
        if (result != vmprog_validation_result::ok) {
            return result;
        }

        // Read and validate TOC
        result = read_and_validate_vmprog_toc(stream, header_, file_size, toc_, vmprog_stream_max_toc_entries);
        if (result != vmprog_validation_result::ok) {
            return result;
        }

        // Verify payload hashes if requested
        if (verify_hashes) {
            if (!scratch_buffer || scratch_buffer_size == 0) {
                return vmprog_validation_result::invalid_file_size;
            }
            result = verify_all_payload_hashes_stream(stream, toc_, header_.toc_count, scratch_buffer, scratch_buffer_size);
            if (result != vmprog_validation_result::ok) {
                return result;
            }
        }

        is_open_ = true;
        return vmprog_validation_result::ok;
    }

    /**
     * @brief Check if package is open and validated.
     */
    bool is_open() const { return is_open_; }

    /**
     * @brief Get package header.
     */
    const vmprog_header_v1_0& header() const { return header_; }

    /**
     * @brief Get TOC entries array.
     */
    const vmprog_toc_entry_v1_0* toc() const { return toc_; }

    /**
     * @brief Get TOC entry count.
     */
    uint32_t toc_count() const { return is_open_ ? header_.toc_count : 0; }

    /**
     * @brief Check if package is signed.
     */
    bool is_signed() const { return is_open_ && is_package_signed(header_); }

    /**
     * @brief Read program configuration.
     *
     * @param out_config Output configuration structure
     * @return Validation result code
     */
    vmprog_validation_result read_config(vmprog_program_config_v1_0& out_config) {
        if (!is_open_) return vmprog_validation_result::invalid_file_size;

        const vmprog_toc_entry_v1_0* entry = find_toc_entry(
            toc_, header_.toc_count, vmprog_toc_entry_type_v1_0::config);

        if (!entry) {
            return vmprog_validation_result::invalid_toc_entry;
        }

        return read_and_validate_vmprog_config(*stream_, *entry, out_config, false);
    }

    /**
     * @brief Read specific payload by type.
     *
     * @param type Payload type to read
     * @param out_payload Output buffer to store payload data
     * @param max_payload_size Maximum size of out_payload buffer
     * @param out_bytes_read Optional output parameter for actual bytes read
     * @return Validation result code
     */
    vmprog_validation_result read_payload_by_type(
        vmprog_toc_entry_type_v1_0 type,
        uint8_t* out_payload,
        uint32_t max_payload_size,
        uint32_t* out_bytes_read = nullptr
    ) {
        if (!is_open_) return vmprog_validation_result::invalid_file_size;
        return find_and_read_payload(*stream_, toc_, header_.toc_count, type, out_payload, max_payload_size, out_bytes_read);
    }

    /**
     * @brief Read FPGA bitstream.
     *
     * @param out_bitstream Output buffer to store bitstream data
     * @param max_bitstream_size Maximum size of out_bitstream buffer
     * @param out_bytes_read Optional output parameter for actual bytes read
     * @return Validation result code
     */
    vmprog_validation_result read_bitstream(
        uint8_t* out_bitstream,
        uint32_t max_bitstream_size,
        uint32_t* out_bytes_read = nullptr
    ) {
        return read_payload_by_type(vmprog_toc_entry_type_v1_0::fpga_bitstream, out_bitstream, max_bitstream_size, out_bytes_read);
    }

    /**
     * @brief Verify package signature.
     *
     * @param public_key Public key for verification (32 bytes, optional)
     * @param out_key_index Optional output parameter for which built-in key succeeded
     * @return Validation result code
     */
    vmprog_validation_result verify_signature(
        const uint8_t* public_key = nullptr,
        size_t* out_key_index = nullptr
    ) {
        if (!is_open_) return vmprog_validation_result::invalid_file_size;
        if (!is_signed()) return vmprog_validation_result::invalid_toc_entry;

        if (public_key) {
            return verify_package_signature_stream(*stream_, toc_, header_.toc_count, public_key);
        } else {
            return verify_package_signature_builtin_keys_stream(*stream_, toc_, header_.toc_count, out_key_index);
        }
    }

private:
    vmprog_stream* stream_ = nullptr;
    uint32_t file_size_ = 0;
    bool is_open_ = false;
    vmprog_header_v1_0 header_ = {};
    vmprog_toc_entry_v1_0 toc_[vmprog_stream_max_toc_entries] = {};
};

} // namespace lzx
