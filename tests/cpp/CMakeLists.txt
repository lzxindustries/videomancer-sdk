# Videomancer SDK - Test Suite CMake Configuration
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

cmake_minimum_required(VERSION 3.13)

# Test configuration
enable_testing()

# Define test executables
set(TEST_SOURCES
    test_vmprog_crypto.cpp
    test_videomancer_abi.cpp
    test_vmprog_format.cpp
    test_vmprog_stream_reader.cpp
    test_videomancer_sdk_version.cpp
    test_vmprog_public_keys.cpp
    test_videomancer_fpga_controller.cpp
)

# Create test executables
foreach(TEST_SOURCE ${TEST_SOURCES})
    # Get test name from source file
    string(REPLACE ".cpp" "" TEST_NAME ${TEST_SOURCE})
    
    # Create executable
    add_executable(${TEST_NAME} ${TEST_SOURCE})
    
    # Link with SDK
    target_link_libraries(${TEST_NAME} PRIVATE videomancer-sdk)
    
    # Set C++ standard (match SDK)
    if(WIN32)
        set_property(TARGET ${TEST_NAME} PROPERTY CXX_STANDARD 17)
    else()
        set_property(TARGET ${TEST_NAME} PROPERTY CXX_STANDARD 20)
    endif()
    set_property(TARGET ${TEST_NAME} PROPERTY CXX_STANDARD_REQUIRED ON)
    
    # Add as CTest test
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
    
    message(STATUS "Configured test: ${TEST_NAME}")
endforeach()

# Optional: Add custom target to run all tests
add_custom_target(run_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    DEPENDS ${TEST_SOURCES}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running all C++ unit tests"
)

message(STATUS "Test suite configured with ${CMAKE_CTEST_COMMAND}")
message(STATUS "Run tests with: make test  or  ctest")
message(STATUS "Run tests with output: make run_tests")
