#!/bin/bash
# Videomancer SDK Build Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
RUN_TESTS=false
BUILD_TYPE="Release"

while [[ $# -gt 0 ]]; do
    case $1 in
        --test|test)
            RUN_TESTS=true
            shift
            ;;
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test      Build and run unit tests"
            echo "  --debug     Build in debug mode (default: Release)"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer SDK Build Script${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Create build directory
echo -e "${GREEN}Creating build directory...${NC}"
mkdir -p build
cd build

# Configure with CMake
echo -e "${GREEN}Configuring project with CMake...${NC}"
echo -e "${BLUE}Build type: ${BUILD_TYPE}${NC}"
if [ "$RUN_TESTS" = true ]; then
    echo -e "${BLUE}Testing: Enabled${NC}"
    cmake .. -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_TESTS=ON
else
    echo -e "${BLUE}Testing: Disabled (use --test to enable)${NC}"
    cmake .. -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_TESTS=OFF
fi

# Build
echo -e "${GREEN}Building project...${NC}"
cmake --build .

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    echo ""
    echo -e "${YELLOW}====================================${NC}"
    echo -e "${YELLOW}Running Unit Tests${NC}"
    echo -e "${YELLOW}====================================${NC}"
    echo ""
    
    # Run CTest with output on failure
    if ctest --output-on-failure; then
        echo ""
        echo -e "${GREEN}====================================${NC}"
        echo -e "${GREEN}All tests passed!${NC}"
        echo -e "${GREEN}====================================${NC}"
    else
        echo ""
        echo -e "${RED}====================================${NC}"
        echo -e "${RED}Some tests failed!${NC}"
        echo -e "${RED}====================================${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "Build artifacts are in: $(pwd)"
echo ""
echo "To use the SDK in your project:"
echo "  1. Add as subdirectory: add_subdirectory(path/to/videomancer-sdk)"
echo "  2. Link to your target: target_link_libraries(your_target PRIVATE videomancer-sdk)"
echo ""
if [ "$RUN_TESTS" = false ]; then
    echo "To build and run tests:"
    echo "  ./build_sdk.sh --test"
    echo ""
fi
