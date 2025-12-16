// Videomancer SDK - Unit Tests for videomancer_abi.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/videomancer_abi.hpp>
#include <iostream>
#include <cassert>

using namespace lzx::videomancer_abi_v1_0;

// Test register address constants
bool test_register_addresses() {
    // Verify register addresses are sequential and within valid range (0-8)
    if (register_address::rotary_pot_1 != 0x00 ||
        register_address::rotary_pot_2 != 0x01 ||
        register_address::rotary_pot_3 != 0x02 ||
        register_address::rotary_pot_4 != 0x03 ||
        register_address::rotary_pot_5 != 0x04 ||
        register_address::rotary_pot_6 != 0x05 ||
        register_address::toggle_switches != 0x06 ||
        register_address::linear_pot_12 != 0x07 ||
        register_address::video_timing_id != 0x08) {
        std::cerr << "FAILED: Register address test - incorrect address values" << std::endl;
        return false;
    }

    std::cout << "PASSED: Register address constants test" << std::endl;
    return true;
}

// Test toggle switch bit positions
bool test_toggle_switch_bits() {
    // Verify bit positions are sequential and within valid range (0-4)
    if (toggle_switch_bit::switch_7 != 0 ||
        toggle_switch_bit::switch_8 != 1 ||
        toggle_switch_bit::switch_9 != 2 ||
        toggle_switch_bit::switch_10 != 3 ||
        toggle_switch_bit::switch_11 != 4) {
        std::cerr << "FAILED: Toggle switch bit test - incorrect bit positions" << std::endl;
        return false;
    }

    // Verify all bits are unique
    const uint8_t bits[] = {
        toggle_switch_bit::switch_7,
        toggle_switch_bit::switch_8,
        toggle_switch_bit::switch_9,
        toggle_switch_bit::switch_10,
        toggle_switch_bit::switch_11
    };

    for (size_t i = 0; i < 5; ++i) {
        for (size_t j = i + 1; j < 5; ++j) {
            if (bits[i] == bits[j]) {
                std::cerr << "FAILED: Toggle switch bit test - duplicate bit positions" << std::endl;
                return false;
            }
        }
    }

    std::cout << "PASSED: Toggle switch bit positions test" << std::endl;
    return true;
}

// Test video timing ID enumeration
bool test_video_timing_ids() {
    // Verify all timing IDs are unique and within valid range (0x0-0xF)
    const uint8_t timing_ids[] = {
        static_cast<uint8_t>(video_timing_id::ntsc),
        static_cast<uint8_t>(video_timing_id::_1080i50),
        static_cast<uint8_t>(video_timing_id::_1080i5994),
        static_cast<uint8_t>(video_timing_id::_1080p24),
        static_cast<uint8_t>(video_timing_id::_480p),
        static_cast<uint8_t>(video_timing_id::_720p50),
        static_cast<uint8_t>(video_timing_id::_720p5994),
        static_cast<uint8_t>(video_timing_id::_1080p30),
        static_cast<uint8_t>(video_timing_id::pal),
        static_cast<uint8_t>(video_timing_id::_1080p2398),
        static_cast<uint8_t>(video_timing_id::_1080i60),
        static_cast<uint8_t>(video_timing_id::_1080p25),
        static_cast<uint8_t>(video_timing_id::_576p),
        static_cast<uint8_t>(video_timing_id::_1080p2997),
        static_cast<uint8_t>(video_timing_id::_720p60),
        static_cast<uint8_t>(video_timing_id::reserved)
    };

    // Check all are within 4-bit range
    for (size_t i = 0; i < 16; ++i) {
        if (timing_ids[i] > 0x0F) {
            std::cerr << "FAILED: Video timing ID test - ID out of range" << std::endl;
            return false;
        }
    }

    // Check all are unique
    for (size_t i = 0; i < 16; ++i) {
        for (size_t j = i + 1; j < 16; ++j) {
            if (timing_ids[i] == timing_ids[j]) {
                std::cerr << "FAILED: Video timing ID test - duplicate IDs" << std::endl;
                return false;
            }
        }
    }

    // Verify specific known values
    if (static_cast<uint8_t>(video_timing_id::ntsc) != 0x0 ||
        static_cast<uint8_t>(video_timing_id::pal) != 0x8 ||
        static_cast<uint8_t>(video_timing_id::reserved) != 0xF) {
        std::cerr << "FAILED: Video timing ID test - incorrect known values" << std::endl;
        return false;
    }

    std::cout << "PASSED: Video timing ID enumeration test" << std::endl;
    return true;
}

// Test toggle switch bit mask creation
bool test_toggle_switch_masks() {
    // Create bit masks for each switch
    uint8_t mask_7 = 1 << toggle_switch_bit::switch_7;
    uint8_t mask_8 = 1 << toggle_switch_bit::switch_8;
    uint8_t mask_9 = 1 << toggle_switch_bit::switch_9;
    uint8_t mask_10 = 1 << toggle_switch_bit::switch_10;
    uint8_t mask_11 = 1 << toggle_switch_bit::switch_11;

    // Verify masks are unique and non-zero
    if (mask_7 == 0 || mask_8 == 0 || mask_9 == 0 || mask_10 == 0 || mask_11 == 0) {
        std::cerr << "FAILED: Toggle switch mask test - zero mask created" << std::endl;
        return false;
    }

    // Verify no overlapping bits
    uint8_t combined = mask_7 | mask_8 | mask_9 | mask_10 | mask_11;
    uint8_t sum = mask_7 + mask_8 + mask_9 + mask_10 + mask_11;

    if (combined != sum) {
        std::cerr << "FAILED: Toggle switch mask test - overlapping bits detected" << std::endl;
        return false;
    }

    // Expected pattern: bits 0-4 should be set
    if (combined != 0x1F) {
        std::cerr << "FAILED: Toggle switch mask test - unexpected bit pattern" << std::endl;
        return false;
    }

    std::cout << "PASSED: Toggle switch bit mask creation test" << std::endl;
    return true;
}

// Test register address range validation
bool test_register_address_range() {
    // All register addresses should be <= 0x08
    const uint8_t max_register = 0x08;

    if (register_address::rotary_pot_1 > max_register ||
        register_address::rotary_pot_2 > max_register ||
        register_address::rotary_pot_3 > max_register ||
        register_address::rotary_pot_4 > max_register ||
        register_address::rotary_pot_5 > max_register ||
        register_address::rotary_pot_6 > max_register ||
        register_address::toggle_switches > max_register ||
        register_address::linear_pot_12 > max_register ||
        register_address::video_timing_id > max_register) {
        std::cerr << "FAILED: Register address range test - address exceeds maximum" << std::endl;
        return false;
    }

    std::cout << "PASSED: Register address range validation test" << std::endl;
    return true;
}

// Test video timing ID completeness (all 4-bit values covered)
bool test_video_timing_completeness() {
    bool covered[16] = {false};

    covered[static_cast<uint8_t>(video_timing_id::ntsc)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080i50)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080i5994)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080p24)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_480p)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_720p50)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_720p5994)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080p30)] = true;
    covered[static_cast<uint8_t>(video_timing_id::pal)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080p2398)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080i60)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080p25)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_576p)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_1080p2997)] = true;
    covered[static_cast<uint8_t>(video_timing_id::_720p60)] = true;
    covered[static_cast<uint8_t>(video_timing_id::reserved)] = true;

    // Verify all 16 possible values are covered
    for (size_t i = 0; i < 16; ++i) {
        if (!covered[i]) {
            std::cerr << "FAILED: Video timing completeness test - missing ID: 0x"
                      << std::hex << i << std::dec << std::endl;
            return false;
        }
    }

    std::cout << "PASSED: Video timing ID completeness test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "======================================" << std::endl;
    std::cout << "Videomancer videomancer_abi.hpp Tests" << std::endl;
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

    RUN_TEST(test_register_addresses);
    RUN_TEST(test_register_address_range);
    RUN_TEST(test_toggle_switch_bits);
    RUN_TEST(test_toggle_switch_masks);
    RUN_TEST(test_video_timing_ids);
    RUN_TEST(test_video_timing_completeness);

    std::cout << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "======================================" << std::endl;

    return (passed == total) ? 0 : 1;
}
