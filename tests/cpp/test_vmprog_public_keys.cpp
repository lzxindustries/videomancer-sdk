// Videomancer SDK - Unit Tests for vmprog_public_keys.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/vmprog_public_keys.hpp>
#include <iostream>
#include <cassert>
#include <cstring>

using namespace lzx;

// Test that public keys array is defined
bool test_public_keys_exist() {
    // Array should exist and have at least one key
    size_t key_count = sizeof(vmprog_public_keys) / sizeof(vmprog_public_keys[0]);

    if (key_count == 0) {
        std::cerr << "FAILED: Public keys exist test - no keys defined" << std::endl;
        return false;
    }

    std::cout << "PASSED: Public keys exist test (" << key_count << " key(s))" << std::endl;
    return true;
}

// Test public key size is correct (32 bytes for Ed25519)
bool test_public_key_size() {
    size_t key_size = sizeof(vmprog_public_keys[0]);

    if (key_size != 32) {
        std::cerr << "FAILED: Public key size test - size is " << key_size
                  << " bytes, expected 32" << std::endl;
        return false;
    }

    std::cout << "PASSED: Public key size test (32 bytes)" << std::endl;
    return true;
}

// Test first public key is not all zeros
bool test_key_not_zero() {
    bool all_zero = true;

    for (size_t i = 0; i < 32; ++i) {
        if (vmprog_public_keys[0][i] != 0) {
            all_zero = false;
            break;
        }
    }

    if (all_zero) {
        std::cerr << "FAILED: Key not zero test - key is all zeros" << std::endl;
        return false;
    }

    std::cout << "PASSED: Key not zero test" << std::endl;
    return true;
}

// Test public keys are accessible
bool test_key_access() {
    size_t key_count = sizeof(vmprog_public_keys) / sizeof(vmprog_public_keys[0]);

    // Access each key and verify we can read all bytes
    for (size_t k = 0; k < key_count; ++k) {
        for (size_t i = 0; i < 32; ++i) {
            uint8_t byte = vmprog_public_keys[k][i];
            (void)byte; // Use variable to prevent warning
        }
    }

    std::cout << "PASSED: Key access test" << std::endl;
    return true;
}

// Test keys can be copied
bool test_key_copy() {
    uint8_t key_copy[32];

    // Copy first key
    memcpy(key_copy, vmprog_public_keys[0], 32);

    // Verify copy matches original
    if (memcmp(key_copy, vmprog_public_keys[0], 32) != 0) {
        std::cerr << "FAILED: Key copy test - copy doesn't match original" << std::endl;
        return false;
    }

    std::cout << "PASSED: Key copy test" << std::endl;
    return true;
}

// Test key entropy (reasonable distribution of bytes)
bool test_key_entropy() {
    // Count unique bytes in first key (should have good variety)
    bool byte_seen[256] = {false};
    size_t unique_count = 0;

    for (size_t i = 0; i < 32; ++i) {
        uint8_t byte = vmprog_public_keys[0][i];
        if (!byte_seen[byte]) {
            byte_seen[byte] = true;
            unique_count++;
        }
    }

    // Expect at least 16 unique bytes in a 32-byte key (reasonable entropy)
    if (unique_count < 16) {
        std::cerr << "FAILED: Key entropy test - only " << unique_count
                  << " unique bytes (expected >= 16)" << std::endl;
        return false;
    }

    std::cout << "PASSED: Key entropy test (" << unique_count << " unique bytes)" << std::endl;
    return true;
}

// Test array bounds
bool test_array_bounds() {
    size_t key_count = sizeof(vmprog_public_keys) / sizeof(vmprog_public_keys[0]);

    // Verify we can access first and last key
    const uint8_t* first_key = vmprog_public_keys[0];
    const uint8_t* last_key = vmprog_public_keys[key_count - 1];

    // Access first and last byte of each
    uint8_t first_byte = first_key[0];
    uint8_t last_byte = last_key[31];

    (void)first_byte;
    (void)last_byte;

    std::cout << "PASSED: Array bounds test" << std::endl;
    return true;
}

// Test constexpr accessibility
bool test_constexpr_access() {
    // Verify we can use in compile-time contexts
    constexpr size_t first_byte = vmprog_public_keys[0][0];
    constexpr size_t last_byte = vmprog_public_keys[0][31];

    if (first_byte > 255 || last_byte > 255) {
        std::cerr << "FAILED: Constexpr access test - invalid byte values" << std::endl;
        return false;
    }

    std::cout << "PASSED: Constexpr access test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "================================================" << std::endl;
    std::cout << "Videomancer vmprog_public_keys.hpp Tests" << std::endl;
    std::cout << "================================================" << std::endl;
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

    RUN_TEST(test_public_keys_exist);
    RUN_TEST(test_public_key_size);
    RUN_TEST(test_key_not_zero);
    RUN_TEST(test_key_access);
    RUN_TEST(test_key_copy);
    RUN_TEST(test_key_entropy);
    RUN_TEST(test_array_bounds);
    RUN_TEST(test_constexpr_access);

    std::cout << std::endl;
    std::cout << "================================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "================================================" << std::endl;

    return (passed == total) ? 0 : 1;
}
