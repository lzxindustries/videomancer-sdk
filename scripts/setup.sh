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
echo -e "${YELLOW}Note: Requires sudo for package installation (Linux)${NC}"
echo -e "${YELLOW}      Requires Homebrew on macOS (https://brew.sh)${NC}"
echo ""

path=$PWD
rm -rf build

# Detect operating system
OS="$(uname -s)"
case "${OS}" in
    Linux*)
        OS_TYPE="Linux"
        ;;
    Darwin*)
        OS_TYPE="macOS"
        ;;
    *)
        echo -e "${RED}ERROR: Unsupported operating system: ${OS}${NC}"
        echo -e "${RED}Supported: Linux, macOS${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Detected OS: ${OS_TYPE}${NC}"
echo ""

if [ "${OS_TYPE}" = "Linux" ]; then
    echo -e "${GREEN}Installing build dependencies...${NC}"
    sudo apt update
    sudo apt install -y cmake git gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib gcc g++ build-essential

    OSS_ARCH="linux-x64"
    DOWNLOAD_CMD="wget"
elif [ "${OS_TYPE}" = "macOS" ]; then
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}ERROR: Homebrew is not installed${NC}"
        echo -e "${YELLOW}Please install Homebrew first:${NC}"
        echo -e "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo -e "${YELLOW}Or visit: https://brew.sh${NC}"
        exit 1
    fi

    echo -e "${GREEN}Installing build dependencies...${NC}"
    brew install --cask gcc-arm-embedded || {
        echo -e "${YELLOW}Warning: gcc-arm-embedded installation failed or already installed${NC}"
    }

    # Detect architecture (Apple Silicon vs Intel)
    ARCH="$(uname -m)"
    if [ "${ARCH}" = "arm64" ]; then
        OSS_ARCH="darwin-arm64"
        echo -e "${GREEN}Detected Apple Silicon (ARM64)${NC}"
    elif [ "${ARCH}" = "x86_64" ]; then
        OSS_ARCH="darwin-x64"
        echo -e "${GREEN}Detected Intel (x86_64)${NC}"
    else
        echo -e "${RED}ERROR: Unsupported macOS architecture: ${ARCH}${NC}"
        exit 1
    fi

    DOWNLOAD_CMD="curl -L -O"
fi

echo -e "${GREEN}Downloading OSS CAD Suite...${NC}"
mkdir build
cd build

# OSS CAD Suite download
OSS_VERSION="20251222"
OSS_FILE="oss-cad-suite-${OSS_ARCH}-${OSS_VERSION}.tgz"
OSS_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2025-12-22/${OSS_FILE}"

if [ -f "${OSS_FILE}" ]; then
    echo -e "${YELLOW}Using existing ${OSS_FILE}${NC}"
else
    if [ "${OS_TYPE}" = "Linux" ]; then
        wget "${OSS_URL}" || {
            echo -e "${RED}ERROR: Failed to download OSS CAD Suite${NC}"
            echo -e "${RED}Please check your internet connection and try again.${NC}"
            exit 1
        }
    elif [ "${OS_TYPE}" = "macOS" ]; then
        curl -L "${OSS_URL}" -o "${OSS_FILE}" || {
            echo -e "${RED}ERROR: Failed to download OSS CAD Suite${NC}"
            echo -e "${RED}Please check your internet connection and try again.${NC}"
            exit 1
        }
    fi
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