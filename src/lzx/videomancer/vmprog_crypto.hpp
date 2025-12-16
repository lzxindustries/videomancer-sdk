// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_crypto.hpp - Cryptographic primitives wrapper
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
// Overview:
//   Provides cryptographic primitives for vmprog package security:
//   - BLAKE2b-256 hashing (used as SHA-256 equivalent)
//   - Ed25519 signature verification (RFC 8032 with SHA-512)
//   - Constant-time memory comparison
//   - Secure memory operations
//
// Implementation:
//   Uses Monocypher library for portable, audited cryptography
//   - No external dependencies beyond Monocypher
//   - Suitable for embedded systems (RP2040)
//   - Side-channel resistant operations

#pragma once

#include <stdint.h>
#include <stddef.h>

namespace lzx {

    // ============================================================================
    // Monocypher Library Integration
    // ============================================================================

    extern "C" {
#include "monocypher.h"
#include "monocypher-ed25519.h"
    }

    // ============================================================================
    // Cryptographic Constants
    // ============================================================================

    constexpr size_t VMPROG_HASH_SIZE = 32;       // SHA-256/BLAKE2b-256 output
    constexpr size_t VMPROG_PUBKEY_SIZE = 32;     // Ed25519 public key
    constexpr size_t VMPROG_SIGNATURE_SIZE = 64;  // Ed25519 signature

    // ============================================================================
    // Hash Functions (BLAKE2b-256)
    // ============================================================================

    /**
     * @brief Incremental BLAKE2b-256 hash context.
     * 
     * BLAKE2b-256 is used as a SHA-256 equivalent for vmprog packages.
     * It provides:
     * - 256-bit (32-byte) hash output
     * - Fast performance on modern CPUs
     * - Cryptographically secure
     * - Simpler implementation than SHA-256
     */
    struct sha256_ctx {
        crypto_blake2b_ctx c;
    };

    /**
     * @brief Initialize hash context.
     * 
     * @param ctx Hash context to initialize
     */
    inline void sha256_init(sha256_ctx& ctx) {
        crypto_blake2b_init(&ctx.c, 32); // 32-byte hash
    }

    /**
     * @brief Update hash with additional data.
     * 
     * Can be called multiple times to hash large data incrementally.
     * 
     * @param ctx Hash context
     * @param data Data to hash
     * @param n Length of data in bytes
     */
    inline void sha256_update(sha256_ctx& ctx, const uint8_t* data, uint32_t n) {
        crypto_blake2b_update(&ctx.c, data, n);
    }

    /**
     * @brief Finalize hash and output result.
     * 
     * After calling this, the context should be reinitialized before reuse.
     * 
     * @param ctx Hash context
     * @param out Output buffer (must be 32 bytes)
     */
    inline void sha256_final(sha256_ctx& ctx, uint8_t out[32]) {
        crypto_blake2b_final(&ctx.c, out);
    }

    /**
     * @brief One-shot hash function.
     * 
     * Convenience function to hash data in a single call.
     * 
     * @param data Data to hash
     * @param length Length of data in bytes
     * @param out Output buffer (must be 32 bytes)
     */
    inline void sha256_oneshot(const uint8_t* data, uint32_t length, uint8_t out[32]) {
        sha256_ctx ctx;
        sha256_init(ctx);
        sha256_update(ctx, data, length);
        sha256_final(ctx, out);
    }

    // ============================================================================
    // Ed25519 Signature Verification
    // ============================================================================

    /**
     * @brief Verify Ed25519 signature.
     * 
     * Ed25519 provides:
     * - Fast signature verification using SHA-512
     * - 256-bit security level
     * - Deterministic signatures (no random number needed)
     * - Small key and signature sizes
     * - RFC 8032 compliant (Ed25519 with SHA-512)
     * 
     * @param sig Signature (64 bytes)
     * @param pub Public key (32 bytes)
     * @param msg Message data
     * @param msg_len Message length in bytes
     * @return true if signature is valid, false otherwise
     */
    inline bool ed25519_verify(const uint8_t sig[64],
                               const uint8_t pub[32],
                               const uint8_t* msg,
                               uint32_t msg_len)
    {
        // Use Ed25519 (SHA-512) from monocypher-ed25519
        // Monocypher returns 0 on success, -1 on failure
        return crypto_ed25519_check(sig, pub, msg, msg_len) == 0;
    }

    // ============================================================================
    // Secure Memory Operations
    // ============================================================================

    /**
     * @brief Constant-time memory comparison.
     * 
     * Compares two memory regions in constant time to prevent timing attacks.
     * Use this for comparing cryptographic hashes, MACs, etc.
     * 
     * @param a First buffer
     * @param b Second buffer
     * @param length Length to compare in bytes
     * @return true if buffers are equal, false otherwise
     */
    inline bool secure_compare(const uint8_t* a, const uint8_t* b, size_t length) {
        uint8_t diff = 0;
        for (size_t i = 0; i < length; ++i) {
            diff |= (a[i] ^ b[i]);
        }
        return diff == 0;
    }

    /**
     * @brief Constant-time 32-byte hash comparison.
     * 
     * Specialized version for comparing 32-byte hashes.
     * 
     * @param a First hash (32 bytes)
     * @param b Second hash (32 bytes)
     * @return true if hashes are equal, false otherwise
     */
    inline bool secure_compare_hash(const uint8_t a[32], const uint8_t b[32]) {
        return secure_compare(a, b, 32);
    }

    /**
     * @brief Securely zero memory.
     * 
     * Zeros memory in a way that won't be optimized away by the compiler.
     * Use this to clear sensitive data (keys, passwords, etc.).
     * 
     * @param data Buffer to zero
     * @param length Length in bytes
     */
    inline void secure_zero(uint8_t* data, size_t length) {
        crypto_wipe(data, length);
    }

    // ============================================================================
    // Hash Verification Helpers
    // ============================================================================

    /**
     * @brief Verify data matches expected hash.
     * 
     * Computes hash of data and compares with expected hash in constant time.
     * 
     * @param data Data to verify
     * @param length Length of data in bytes
     * @param expected_hash Expected hash (32 bytes)
     * @return true if hash matches, false otherwise
     */
    inline bool verify_hash(const uint8_t* data, uint32_t length, const uint8_t expected_hash[32]) {
        uint8_t computed_hash[32];
        sha256_oneshot(data, length, computed_hash);
        return secure_compare_hash(computed_hash, expected_hash);
    }

    /**
     * @brief Check if hash is all zeros (uninitialized or optional).
     * 
     * @param hash Hash to check (32 bytes)
     * @return true if hash is all zeros, false otherwise
     */
    inline bool is_hash_zero(const uint8_t hash[32]) {
        uint8_t zero_hash[32] = {0};
        return secure_compare_hash(hash, zero_hash);
    }

    // ============================================================================
    // Key Management Helpers
    // ============================================================================

    /**
     * @brief Check if public key is valid (not all zeros).
     * 
     * @param pubkey Public key to check (32 bytes)
     * @return true if key appears valid, false if all zeros
     */
    inline bool is_pubkey_valid(const uint8_t pubkey[32]) {
        return !is_hash_zero(pubkey); // Reuse hash check since size is same
    }

} // namespace lzx
