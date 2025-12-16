// Videomancer SDK - Unit Tests for vmprog_crypto.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/vmprog_crypto.hpp>
#include <cassert>
#include <cstring>
#include <iostream>
#include <vector>

using namespace lzx;

// Test data
const uint8_t test_message[] = "Hello, Videomancer!";
const size_t test_message_len = sizeof(test_message) - 1; // Exclude null terminator

// Known hash outputs for verification (BLAKE2b-256)
const uint8_t expected_empty_hash[32] = {
    0x0e, 0x57, 0x51, 0xc0, 0x26, 0xe5, 0x43, 0xb2,
    0xe8, 0xab, 0x2e, 0xb0, 0x60, 0x99, 0xda, 0xa1,
    0xd1, 0xe5, 0xdf, 0x47, 0x77, 0x8f, 0x77, 0x87,
    0xfa, 0xab, 0x45, 0xcd, 0xf1, 0x2f, 0xe3, 0xa8
};

// Test hash initialization
bool test_sha256_init() {
    sha256_ctx ctx;
    sha256_init(ctx);

    // Finalize without any updates (hash of empty data)
    uint8_t hash[32];
    sha256_final(ctx, hash);

    if (memcmp(hash, expected_empty_hash, 32) != 0) {
        std::cerr << "FAILED: SHA256 initialization test - empty hash mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: SHA256 initialization test" << std::endl;
    return true;
}

// Test incremental hash updates
bool test_sha256_incremental() {
    sha256_ctx ctx;
    sha256_init(ctx);

    // Hash in chunks
    sha256_update(ctx, test_message, 5);
    sha256_update(ctx, test_message + 5, test_message_len - 5);

    uint8_t hash_incremental[32];
    sha256_final(ctx, hash_incremental);

    // Compare with one-shot hash
    uint8_t hash_oneshot[32];
    sha256_oneshot(test_message, test_message_len, hash_oneshot);

    if (memcmp(hash_incremental, hash_oneshot, 32) != 0) {
        std::cerr << "FAILED: SHA256 incremental hash test - hashes don't match" << std::endl;
        return false;
    }

    std::cout << "PASSED: SHA256 incremental hash test" << std::endl;
    return true;
}

// Test one-shot hash function
bool test_sha256_oneshot() {
    uint8_t hash1[32];
    uint8_t hash2[32];

    sha256_oneshot(test_message, test_message_len, hash1);
    sha256_oneshot(test_message, test_message_len, hash2);

    if (memcmp(hash1, hash2, 32) != 0) {
        std::cerr << "FAILED: SHA256 one-shot test - deterministic hash failed" << std::endl;
        return false;
    }

    // Hash different data should produce different hash
    const uint8_t different_msg[] = "Different message";
    uint8_t hash3[32];
    sha256_oneshot(different_msg, sizeof(different_msg) - 1, hash3);

    if (memcmp(hash1, hash3, 32) == 0) {
        std::cerr << "FAILED: SHA256 one-shot test - different messages produced same hash" << std::endl;
        return false;
    }

    std::cout << "PASSED: SHA256 one-shot hash test" << std::endl;
    return true;
}

// Test constant-time comparison
bool test_constant_time_compare() {
    uint8_t data1[32];
    uint8_t data2[32];
    uint8_t data3[32];

    // Fill with test pattern
    for (size_t i = 0; i < 32; ++i) {
        data1[i] = static_cast<uint8_t>(i);
        data2[i] = static_cast<uint8_t>(i);
        data3[i] = static_cast<uint8_t>(i + 1);
    }

    // Equal data should match
    if (!secure_compare(data1, data2, 32)) {
        std::cerr << "FAILED: Constant-time compare test - equal data not matched" << std::endl;
        return false;
    }

    // Different data should not match
    if (secure_compare(data1, data3, 32)) {
        std::cerr << "FAILED: Constant-time compare test - different data matched" << std::endl;
        return false;
    }

    // Test with different lengths
    if (!secure_compare(data1, data2, 16)) {
        std::cerr << "FAILED: Constant-time compare test - partial compare failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Constant-time comparison test" << std::endl;
    return true;
}

// Test secure memory wipe
bool test_secure_wipe() {
    uint8_t data[64];

    // Fill with non-zero pattern
    for (size_t i = 0; i < 64; ++i) {
        data[i] = 0xFF;
    }

    // Wipe memory
    secure_zero(data, 64);

    // Verify all bytes are zero
    for (size_t i = 0; i < 64; ++i) {
        if (data[i] != 0) {
            std::cerr << "FAILED: Secure wipe test - memory not zeroed" << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Secure memory wipe test" << std::endl;
    return true;
}

// Test Ed25519 signature verification with known test vectors
bool test_ed25519_verify() {
    // RFC 8032 Test Vector 1 (empty message)
    // Now that we're using crypto_ed25519_check, RFC 8032 vectors should work!
    const uint8_t public_key[32] = {
        0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
        0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
        0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
        0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a
    };

    const uint8_t message[1] = {0x00};  // Empty message (length 0)

    const uint8_t signature[64] = {
        0xe5, 0x56, 0x43, 0x00, 0xc3, 0x60, 0xac, 0x72,
        0x90, 0x86, 0xe2, 0xcc, 0x80, 0x6e, 0x82, 0x8a,
        0x84, 0x87, 0x7f, 0x1e, 0xb8, 0xe5, 0xd9, 0x74,
        0xd8, 0x73, 0xe0, 0x65, 0x22, 0x49, 0x01, 0x55,
        0x5f, 0xb8, 0x82, 0x15, 0x90, 0xa3, 0x3b, 0xac,
        0xc6, 0x1e, 0x39, 0x70, 0x1c, 0xf9, 0xb4, 0x6b,
        0xd2, 0x5b, 0xf5, 0xf0, 0x59, 0x5b, 0xbe, 0x24,
        0x65, 0x51, 0x41, 0x43, 0x8e, 0x7a, 0x10, 0x0b
    };

    // Valid signature should verify (empty message, so length = 0)
    if (!ed25519_verify(signature, public_key, message, 0)) {
        std::cerr << "FAILED: Ed25519 verify test - RFC 8032 test vector 1 rejected" << std::endl;
        return false;
    }

    // Modified signature should fail
    uint8_t bad_signature[64];
    memcpy(bad_signature, signature, 64);
    bad_signature[0] ^= 0x01;

    if (ed25519_verify(bad_signature, public_key, message, 0)) {
        std::cerr << "FAILED: Ed25519 verify test - invalid signature accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Ed25519 signature verification test (RFC 8032 test vector 1)" << std::endl;
    return true;
}

// Test hash determinism
bool test_hash_determinism() {
    const size_t iterations = 100;
    uint8_t reference_hash[32];
    sha256_oneshot(test_message, test_message_len, reference_hash);

    for (size_t i = 0; i < iterations; ++i) {
        uint8_t hash[32];
        sha256_oneshot(test_message, test_message_len, hash);

        if (memcmp(hash, reference_hash, 32) != 0) {
            std::cerr << "FAILED: Hash determinism test - iteration " << i << " produced different hash" << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Hash determinism test (" << iterations << " iterations)" << std::endl;
    return true;
}

// Test large data hashing
bool test_large_data_hash() {
    const size_t large_size = 1024 * 1024; // 1 MB
    std::vector<uint8_t> large_data(large_size);

    // Fill with pattern
    for (size_t i = 0; i < large_size; ++i) {
        large_data[i] = static_cast<uint8_t>(i & 0xFF);
    }

    uint8_t hash1[32];
    uint8_t hash2[32];

    // Hash using one-shot
    sha256_oneshot(large_data.data(), large_size, hash1);

    // Hash using incremental (1 KB chunks)
    sha256_ctx ctx;
    sha256_init(ctx);
    for (size_t offset = 0; offset < large_size; offset += 1024) {
        size_t chunk_size = (offset + 1024 <= large_size) ? 1024 : (large_size - offset);
        sha256_update(ctx, large_data.data() + offset, chunk_size);
    }
    sha256_final(ctx, hash2);

    if (memcmp(hash1, hash2, 32) != 0) {
        std::cerr << "FAILED: Large data hash test - incremental hash mismatch" << std::endl;
        return false;
    }

    std::cout << "PASSED: Large data hash test (1 MB)" << std::endl;
    return true;
}

// Test Ed25519 with different message lengths
bool test_ed25519_message_lengths() {
    // RFC 8032 Test Vector 2 (1-byte message)
    const uint8_t pub_key_2[32] = {
        0x3d, 0x40, 0x17, 0xc3, 0xe8, 0x43, 0x89, 0x5a,
        0x92, 0xb7, 0x0a, 0xa7, 0x4d, 0x1b, 0x7e, 0xbc,
        0x9c, 0x98, 0x2c, 0xcf, 0x2e, 0xc4, 0x96, 0x8c,
        0xc0, 0xcd, 0x55, 0xf1, 0x2a, 0xf4, 0x66, 0x0c
    };

    const uint8_t message_2[1] = {0x72};

    const uint8_t sig_2[64] = {
        0x92, 0xa0, 0x09, 0xa9, 0xf0, 0xd4, 0xca, 0xb8,
        0x72, 0x0e, 0x82, 0x0b, 0x5f, 0x64, 0x25, 0x40,
        0xa2, 0xb2, 0x7b, 0x54, 0x16, 0x50, 0x3f, 0x8f,
        0xb3, 0x76, 0x22, 0x23, 0xeb, 0xdb, 0x69, 0xda,
        0x08, 0x5a, 0xc1, 0xe4, 0x3e, 0x15, 0x99, 0x6e,
        0x45, 0x8f, 0x36, 0x13, 0xd0, 0xf1, 0x1d, 0x8c,
        0x38, 0x7b, 0x2e, 0xae, 0xb4, 0x30, 0x2a, 0xee,
        0xb0, 0x0d, 0x29, 0x16, 0x12, 0xbb, 0x0c, 0x00
    };

    if (!ed25519_verify(sig_2, pub_key_2, message_2, 1)) {
        std::cerr << "FAILED: Ed25519 message length test - RFC 8032 test vector 2 failed" << std::endl;
        return false;
    }

    // RFC 8032 Test Vector 3 (2-byte message)
    const uint8_t pub_key_3[32] = {
        0xfc, 0x51, 0xcd, 0x8e, 0x62, 0x18, 0xa1, 0xa3,
        0x8d, 0xa4, 0x7e, 0xd0, 0x02, 0x30, 0xf0, 0x58,
        0x08, 0x16, 0xed, 0x13, 0xba, 0x33, 0x03, 0xac,
        0x5d, 0xeb, 0x91, 0x15, 0x48, 0x90, 0x80, 0x25
    };

    const uint8_t message_3[2] = {0xaf, 0x82};

    const uint8_t sig_3[64] = {
        0x62, 0x91, 0xd6, 0x57, 0xde, 0xec, 0x24, 0x02,
        0x48, 0x27, 0xe6, 0x9c, 0x3a, 0xbe, 0x01, 0xa3,
        0x0c, 0xe5, 0x48, 0xa2, 0x84, 0x74, 0x3a, 0x44,
        0x5e, 0x36, 0x80, 0xd7, 0xdb, 0x5a, 0xc3, 0xac,
        0x18, 0xff, 0x9b, 0x53, 0x8d, 0x16, 0xf2, 0x90,
        0xae, 0x67, 0xf7, 0x60, 0x98, 0x4d, 0xc6, 0x59,
        0x4a, 0x7c, 0x15, 0xe9, 0x71, 0x6e, 0xd2, 0x8d,
        0xc0, 0x27, 0xbe, 0xce, 0xea, 0x1e, 0xc4, 0x0a
    };

    if (!ed25519_verify(sig_3, pub_key_3, message_3, 2)) {
        std::cerr << "FAILED: Ed25519 message length test - RFC 8032 test vector 3 failed" << std::endl;
        return false;
    }

    std::cout << "PASSED: Ed25519 RFC 8032 test vectors 2 & 3" << std::endl;
    return true;
}

// Test Ed25519 with corrupted signatures
bool test_ed25519_corrupted_signatures() {
    const uint8_t public_key[32] = {
        0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
        0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
        0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
        0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a
    };

    const uint8_t message[8] = {'T', 'e', 's', 't', ' ', 'M', 's', 'g'};

    // Test all-zero signature
    uint8_t zero_sig[64];
    memset(zero_sig, 0, 64);
    if (ed25519_verify(zero_sig, public_key, message, sizeof(message))) {
        std::cerr << "FAILED: Ed25519 corrupted signature test - all-zero accepted" << std::endl;
        return false;
    }

    // Test all-FF signature
    uint8_t ff_sig[64];
    memset(ff_sig, 0xFF, 64);
    if (ed25519_verify(ff_sig, public_key, message, sizeof(message))) {
        std::cerr << "FAILED: Ed25519 corrupted signature test - all-FF accepted" << std::endl;
        return false;
    }

    // Test sparse signature
    uint8_t sparse_sig[64];
    memset(sparse_sig, 0, 64);
    sparse_sig[0] = 1;
    sparse_sig[63] = 1;
    if (ed25519_verify(sparse_sig, public_key, message, sizeof(message))) {
        std::cerr << "FAILED: Ed25519 corrupted signature test - sparse pattern accepted" << std::endl;
        return false;
    }

    // Test patterned signature
    uint8_t pattern_sig[64];
    memset(pattern_sig, 0xAA, 32);
    memset(pattern_sig + 32, 0x55, 32);
    if (ed25519_verify(pattern_sig, public_key, message, sizeof(message))) {
        std::cerr << "FAILED: Ed25519 corrupted signature test - pattern accepted" << std::endl;
        return false;
    }

    std::cout << "PASSED: Ed25519 corrupted signature rejection test" << std::endl;
    return true;
}

// Test Ed25519 API safety
bool test_ed25519_api_safety() {
    // Test that API handles edge cases without crashing
    const uint8_t public_key[32] = {0};
    const uint8_t signature[64] = {0};
    const uint8_t message[1] = {0};

    // Zero-length message should work (not crash)
    bool result1 = ed25519_verify(signature, public_key, message, 0);
    (void)result1;  // Don't care about result, just that it doesn't crash

    // 1-byte message should work (not crash)
    bool result2 = ed25519_verify(signature, public_key, message, 1);
    (void)result2;  // Don't care about result, just that it doesn't crash

    // Verify API doesn't crash with null-like inputs
    // (just testing that the function executes)

    std::cout << "PASSED: Ed25519 API safety test" << std::endl;
    return true;
}

// Test verify_hash helper
bool test_verify_hash() {
    const uint8_t data[] = "Test data for hash verification";
    const size_t data_len = sizeof(data) - 1;

    // Compute hash
    uint8_t hash[32];
    sha256_oneshot(data, data_len, hash);

    // Verify correct hash
    if (!verify_hash(data, data_len, hash)) {
        std::cerr << "FAILED: verify_hash - valid hash not verified" << std::endl;
        return false;
    }

    // Modify hash and verify it fails
    hash[0] ^= 0x01;
    if (verify_hash(data, data_len, hash)) {
        std::cerr << "FAILED: verify_hash - corrupted hash verified" << std::endl;
        return false;
    }

    std::cout << "PASSED: verify_hash" << std::endl;
    return true;
}

// Test is_hash_zero helper
bool test_is_hash_zero() {
    uint8_t zero_hash[32] = {0};
    uint8_t nonzero_hash[32] = {0};
    nonzero_hash[31] = 1;

    if (!is_hash_zero(zero_hash)) {
        std::cerr << "FAILED: is_hash_zero - zero hash not detected" << std::endl;
        return false;
    }

    if (is_hash_zero(nonzero_hash)) {
        std::cerr << "FAILED: is_hash_zero - nonzero hash detected as zero" << std::endl;
        return false;
    }

    std::cout << "PASSED: is_hash_zero" << std::endl;
    return true;
}

// Test secure_compare_hash helper
bool test_secure_compare_hash() {
    uint8_t hash1[32] = {0};
    uint8_t hash2[32] = {0};
    uint8_t hash3[32] = {0};

    // Fill with test pattern
    for (int i = 0; i < 32; i++) {
        hash1[i] = static_cast<uint8_t>(i);
        hash2[i] = static_cast<uint8_t>(i);
        hash3[i] = static_cast<uint8_t>(i ^ 0x01); // Different
    }

    if (!secure_compare_hash(hash1, hash2)) {
        std::cerr << "FAILED: secure_compare_hash - identical hashes not equal" << std::endl;
        return false;
    }

    if (secure_compare_hash(hash1, hash3)) {
        std::cerr << "FAILED: secure_compare_hash - different hashes equal" << std::endl;
        return false;
    }

    std::cout << "PASSED: secure_compare_hash" << std::endl;
    return true;
}

// Test is_pubkey_valid helper
bool test_is_pubkey_valid() {
    // All-zero key is invalid
    uint8_t zero_key[32] = {0};
    if (is_pubkey_valid(zero_key)) {
        std::cerr << "FAILED: is_pubkey_valid - zero key validated" << std::endl;
        return false;
    }

    // Non-zero key is valid (basic check)
    uint8_t valid_key[32] = {0};
    valid_key[0] = 1;
    if (!is_pubkey_valid(valid_key)) {
        std::cerr << "FAILED: is_pubkey_valid - nonzero key rejected" << std::endl;
        return false;
    }

    std::cout << "PASSED: is_pubkey_valid" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "======================================" << std::endl;
    std::cout << "Videomancer vmprog_crypto.hpp Tests" << std::endl;
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

    RUN_TEST(test_sha256_init);
    RUN_TEST(test_sha256_oneshot);
    RUN_TEST(test_sha256_incremental);
    RUN_TEST(test_hash_determinism);
    RUN_TEST(test_large_data_hash);
    RUN_TEST(test_constant_time_compare);
    RUN_TEST(test_secure_wipe);
    RUN_TEST(test_ed25519_verify);
    RUN_TEST(test_ed25519_message_lengths);
    RUN_TEST(test_ed25519_corrupted_signatures);
    RUN_TEST(test_ed25519_api_safety);
    RUN_TEST(test_verify_hash);
    RUN_TEST(test_is_hash_zero);
    RUN_TEST(test_secure_compare_hash);
    RUN_TEST(test_is_pubkey_valid);

    std::cout << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "======================================" << std::endl;

    return (passed == total) ? 0 : 1;
}
