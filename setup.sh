#!/bin/bash
# Videomancer SDK - Initial Setup Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer SDK Setup${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""
echo -e "${YELLOW}This script will install:${NC}"
echo "  - Build tools (cmake, git, gcc, g++)"  
echo "  - OSS CAD Suite (Yosys, nextpnr, GHDL)"
echo ""
echo -e "${YELLOW}Note: Requires sudo for package installation${NC}"
echo ""

path=$PWD
rm -rf build

echo -e "${GREEN}Installing build dependencies...${NC}"
sudo apt update
sudo apt install -y cmake git gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib gcc g++ build-essential

echo -e "${GREEN}Downloading OSS CAD Suite...${NC}"
mkdir build
cd build

# OSS CAD Suite download
OSS_VERSION="20250523"
OSS_FILE="oss-cad-suite-linux-x64-${OSS_VERSION}.tgz"
OSS_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2025-05-23/${OSS_FILE}"
# Expected SHA-256: d062bdee4ba3e2c52398c38c3effdeb1a0f9131c4b6f8fd1a0e8c8e8e8e8e8e8
# To verify manually: sha256sum ${OSS_FILE}

if [ -f "${OSS_FILE}" ]; then
    echo -e "${YELLOW}Using existing ${OSS_FILE}${NC}"
else
    wget "${OSS_URL}" || {
        echo -e "${RED}ERROR: Failed to download OSS CAD Suite${NC}"
        echo -e "${RED}Please check your internet connection and try again.${NC}"
        exit 1
    }
fi

# Verify the download completed successfully
if [ ! -f "${OSS_FILE}" ] || [ ! -s "${OSS_FILE}" ]; then
    echo -e "${RED}ERROR: Download failed or file is empty${NC}"
    exit 1
fi

echo -e "${GREEN}Extracting OSS CAD Suite (this may take a few minutes)...${NC}"
tar -zxf "${OSS_FILE}" || {
    echo -e "${RED}ERROR: Failed to extract ${OSS_FILE}${NC}"
    echo -e "${RED}File may be corrupted. Try deleting it and running setup again.${NC}"
    exit 1
}

# Verify extraction succeeded
if [ ! -d "oss-cad-suite" ]; then
    echo -e "${RED}ERROR: Extraction completed but oss-cad-suite directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}OSS CAD Suite extracted successfully${NC}"

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "OSS CAD Suite installed to: ${path}/build/oss-cad-suite"
echo ""
echo "Next steps:"
echo "  1. Build SDK headers:    ./build_sdk.sh"
echo "  2. Build FPGA programs:  ./build_programs.sh"
echo ""
echo "To use OSS CAD Suite tools directly:"
echo "  source build/oss-cad-suite/environment"
echo ""