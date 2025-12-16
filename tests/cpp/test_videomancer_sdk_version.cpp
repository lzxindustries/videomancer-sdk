// Videomancer SDK - Unit Tests for videomancer_sdk_version.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/videomancer_sdk_version.hpp>
#include <iostream>
#include <cassert>
#include <cstring>

using namespace lzx::videomancer_sdk_version;

// Test version constants exist and are valid
bool test_version_constants() {
    // Verify major, minor, patch are defined
    if (major > 999 || minor > 999 || patch > 999) {
        std::cerr << "FAILED: Version constants test - version numbers out of range" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Version constants test (v" << major << "." << minor << "." << patch << ")" << std::endl;
    return true;
}

// Test git tag format
bool test_git_tag() {
    if (git_tag == nullptr || strlen(git_tag) == 0) {
        std::cerr << "FAILED: Git tag test - tag is null or empty" << std::endl;
        return false;
    }
    
    // Verify it's a null-terminated string
    size_t len = strlen(git_tag);
    if (len > 100) {
        std::cerr << "FAILED: Git tag test - tag suspiciously long" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Git tag test (" << git_tag << ")" << std::endl;
    return true;
}

// Test git hash format
bool test_git_hash() {
    if (git_hash == nullptr || strlen(git_hash) == 0) {
        std::cerr << "FAILED: Git hash test - hash is null or empty" << std::endl;
        return false;
    }
    
    // Verify it starts with 'g' (abbreviated hash format)
    if (git_hash[0] != 'g') {
        std::cerr << "FAILED: Git hash test - hash doesn't start with 'g'" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Git hash test (" << git_hash << ")" << std::endl;
    return true;
}

// Test git commits count
bool test_git_commits() {
    // Commits should be a reasonable number (not negative, not absurdly large)
    if (git_commits > 100000) {
        std::cerr << "FAILED: Git commits test - unreasonable commit count" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Git commits test (" << git_commits << " commits)" << std::endl;
    return true;
}

// Test version consistency
bool test_version_consistency() {
    // Tag should contain version numbers in some form
    // This is a basic sanity check
    const char* tag_str = git_tag;
    bool has_digit = false;
    
    for (size_t i = 0; tag_str[i] != '\0'; ++i) {
        if (tag_str[i] >= '0' && tag_str[i] <= '9') {
            has_digit = true;
            break;
        }
    }
    
    if (!has_digit) {
        std::cerr << "FAILED: Version consistency test - tag has no digits" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Version consistency test" << std::endl;
    return true;
}

// Test version constants are accessible
bool test_namespace_access() {
    // Verify we can access all constants without errors
    auto m = major;
    auto n = minor;
    auto p = patch;
    auto c = git_commits;
    const char* t = git_tag;
    const char* h = git_hash;
    
    // Use variables to prevent compiler warnings
    (void)m; (void)n; (void)p; (void)c; (void)t; (void)h;
    
    std::cout << "PASSED: Namespace access test" << std::endl;
    return true;
}

// Test string constants are null-terminated
bool test_string_safety() {
    // Verify strings are properly null-terminated by attempting to get length
    size_t tag_len = strlen(git_tag);
    size_t hash_len = strlen(git_hash);
    
    if (tag_len == 0 || hash_len == 0) {
        std::cerr << "FAILED: String safety test - zero length strings" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: String safety test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "================================================" << std::endl;
    std::cout << "Videomancer videomancer_sdk_version.hpp Tests" << std::endl;
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
    
    RUN_TEST(test_version_constants);
    RUN_TEST(test_git_tag);
    RUN_TEST(test_git_hash);
    RUN_TEST(test_git_commits);
    RUN_TEST(test_version_consistency);
    RUN_TEST(test_namespace_access);
    RUN_TEST(test_string_safety);
    
    std::cout << std::endl;
    std::cout << "================================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "================================================" << std::endl;
    
    return (passed == total) ? 0 : 1;
}
