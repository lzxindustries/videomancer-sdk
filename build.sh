#!/bin/bash
# Videomancer SDK Build Script

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
cmake ..

# Build
echo -e "${GREEN}Building project...${NC}"
cmake --build .

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
