
#!/bin/bash
# Videomancer SDK - FPGA Programs Build Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer FPGA Programs Builder${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Root paths - can be overridden by environment variables
VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT:-${SCRIPT_DIR}}"
VIDEOMANCER_PROGRAMS_DIR="${VIDEOMANCER_PROGRAMS_DIR:-${SCRIPT_DIR}/programs/}"
VIDEOMANCER_BUILD_DIR="${VIDEOMANCER_BUILD_DIR:-${SCRIPT_DIR}/build/programs/}"
VIDEOMANCER_OUT_DIR="${VIDEOMANCER_OUT_DIR:-${SCRIPT_DIR}/out/}"

# Hardware configuration
DEVICE=hx4k
PACKAGE=tq144
HARDWARE=videomancer_core_rev_b

cd "${SCRIPT_DIR}"

# Determine which programs to build
PROGRAMS="${1:-$(find "${VIDEOMANCER_PROGRAMS_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)}"
PROGRAM_COUNT=$(echo "$PROGRAMS" | wc -w)

if [ -n "$1" ]; then
    echo -e "${CYAN}Building specific program: ${1}${NC}"
else
    echo -e "${CYAN}Building all programs (${PROGRAM_COUNT} found in ${VIDEOMANCER_PROGRAMS_DIR})${NC}"
fi
echo ""

# Check for OSS CAD Suite
if [ ! -d "build/oss-cad-suite" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite not found!${NC}"
    echo -e "${RED}Please run ./setup.sh first to install the FPGA toolchain.${NC}"
    exit 1
fi

# Validate OSS CAD Suite installation
if [ ! -f "build/oss-cad-suite/environment" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite installation is incomplete or corrupted!${NC}"
    echo -e "${RED}Missing environment setup script. Please run ./setup.sh again.${NC}"
    exit 1
fi

if [ ! -d "build/oss-cad-suite/bin" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite binaries not found!${NC}"
    echo -e "${RED}Installation appears incomplete. Please run ./setup.sh again.${NC}"
    exit 1
fi

# Check for Ed25519 signing keys BEFORE loading OSS CAD Suite environment
# (OSS CAD Suite may use its own Python that doesn't see system packages)
SIGN_PACKAGES=false
if [ -f "keys/lzx_official_signed_descriptor_priv.bin" ] && [ -f "keys/lzx_official_signed_descriptor_pub.bin" ]; then
    # Check if cryptography library is available
    if python3 -c "import cryptography" 2>/dev/null; then
        SIGN_PACKAGES=true
        echo -e "${GREEN}✓ Ed25519 signing keys found - packages will be signed${NC}"
    else
        echo -e "${YELLOW}⚠ Ed25519 keys found but cryptography library not available${NC}"
        echo -e "${YELLOW}  Packages will be unsigned. Install with:${NC}"
        echo -e "${YELLOW}    sudo apt install python3-cryptography${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Ed25519 signing keys not found - packages will be unsigned${NC}"
    echo -e "${YELLOW}  To enable signing, run: ./scripts/setup_ed25519_signing.sh${NC}"
fi
echo ""

echo -e "${GREEN}Loading OSS CAD Suite environment...${NC}"
cd build/oss-cad-suite
source environment
cd ../..

# Create output directories
mkdir -p build
mkdir -p build/programs
mkdir -p out

# Track build statistics
TOTAL_PROGRAMS=0
SUCCESSFUL_PROGRAMS=0
FAILED_PROGRAMS=0
    
for PROGRAM in $PROGRAMS; do
    TOTAL_PROGRAMS=$((TOTAL_PROGRAMS + 1))
    PROJECT_ROOT="${VIDEOMANCER_PROGRAMS_DIR}${PROGRAM}/"
    BUILD_ROOT="${VIDEOMANCER_BUILD_DIR}${PROGRAM}/"
    
    echo ""
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}Program ${TOTAL_PROGRAMS}/${PROGRAM_COUNT}: ${PROGRAM}${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    
    # Check if program directory exists
    if [ ! -d "${PROJECT_ROOT}" ]; then
        echo -e "${RED}ERROR: Program directory '${PROJECT_ROOT}' not found${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    
    # Create output directories
    echo -e "${GREEN}Creating output directories...${NC}"
    mkdir -p "${BUILD_ROOT}bitstreams"
    
    # Synthesize FPGA bitstreams (6 variants)
    echo -e "${GREEN}Synthesizing FPGA bitstreams...${NC}"
    cd fpga
    
    # Temporary file for capturing make errors
    MAKE_LOG=$(mktemp)
    
    # Track total bitstream generation time
    BITSTREAM_START=$(date +%s.%N)
    
    echo -e "${CYAN}  [1/6] HD Analog (80 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    echo -e "${CYAN}  [2/6] SD Analog (30 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    echo -e "${CYAN}  [3/6] HD HDMI (80 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    echo -e "${CYAN}  [4/6] SD HDMI (30 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    echo -e "${CYAN}  [5/6] HD Dual (80 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    echo -e "${CYAN}  [6/6] SD Dual (30 MHz)...${NC}"
    START=$(date +%s.%N)
    if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > "$MAKE_LOG" 2>&1; then
        echo -e "${RED}Build failed. Error output:${NC}"
        cat "$MAKE_LOG"
        rm -f "$MAKE_LOG"
        cd ..
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
    
    BITSTREAM_END=$(date +%s.%N)
    TOTAL_BITSTREAM_TIME=$(echo "$BITSTREAM_END - $BITSTREAM_START" | bc)
    
    rm -f "$MAKE_LOG"
    cd ..
    echo -e "${GREEN}✓ All 6 bitstream variants generated in ${TOTAL_BITSTREAM_TIME}s${NC}"
    
    # Convert TOML configuration to binary
    echo -e "${GREEN}Converting TOML configuration to binary...${NC}"
    cd tools/toml-converter
    python3 toml_to_config_binary.py "${PROJECT_ROOT}${PROGRAM}.toml" "${BUILD_ROOT}program_config.bin" --quiet
    cd ../..
    echo -e "${GREEN}✓ Configuration binary created (7,368 bytes)${NC}"
    
    # Clean up intermediate files
    echo -e "${GREEN}Cleaning intermediate files...${NC}"
    cd build/programs/${PROGRAM}/bitstreams
    rm -f *.asc *.json
    cd ../../../..
    
    # Package into .vmprog format
    echo -e "${GREEN}Packaging ${PROGRAM}.vmprog...${NC}"
    cd tools/vmprog-packer
    
    PACK_LOG=$(mktemp)
    if [ "$SIGN_PACKAGES" = true ]; then
        echo -e "${CYAN}  Signing package with Ed25519...${NC}"
        if ! python3 vmprog_pack.py "${BUILD_ROOT%/}" "${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog" > "$PACK_LOG" 2>&1; then
            echo -e "${RED}Packaging failed. Error output:${NC}"
            cat "$PACK_LOG"
            rm -f "$PACK_LOG"
            cd ../..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue
        fi
    else
        if ! python3 vmprog_pack.py --no-sign "${BUILD_ROOT%/}" "${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog" > "$PACK_LOG" 2>&1; then
            echo -e "${RED}Packaging failed. Error output:${NC}"
            cat "$PACK_LOG"
            rm -f "$PACK_LOG"
            cd ../..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue
        fi
    fi
    rm -f "$PACK_LOG"
    
    cd ../..
    
    # Verify output file
    if [ -f "out/${PROGRAM}.vmprog" ]; then
        FILESIZE=$(stat -f%z "${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog" 2>/dev/null || stat -c%s "${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog" 2>/dev/null)
        if [ "$SIGN_PACKAGES" = true ]; then
            echo -e "${GREEN}✓ Successfully created: ${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog (${FILESIZE} bytes, SIGNED)${NC}"
        else
            echo -e "${GREEN}✓ Successfully created: ${VIDEOMANCER_OUT_DIR%/}/${PROGRAM}.vmprog (${FILESIZE} bytes, unsigned)${NC}"
        fi
        SUCCESSFUL_PROGRAMS=$((SUCCESSFUL_PROGRAMS + 1))
    else
        echo -e "${RED}✗ Failed to create output file${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
    fi
done

echo ""
echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Build Summary${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""
echo -e "${CYAN}Total programs processed:  ${TOTAL_PROGRAMS}${NC}"
echo -e "${GREEN}Successfully built:        ${SUCCESSFUL_PROGRAMS}${NC}"

if [ $FAILED_PROGRAMS -gt 0 ]; then
    echo -e "${RED}Failed:                    ${FAILED_PROGRAMS}${NC}"
fi

if [ "$SIGN_PACKAGES" = true ]; then
    echo -e "${GREEN}All packages cryptographically signed with Ed25519${NC}"
else
    echo -e "${YELLOW}Packages are unsigned (no Ed25519 keys found)${NC}"
fi

echo ""
echo -e "${GREEN}Output directory: ${SCRIPT_DIR}/out/${NC}"
echo ""

if [ $SUCCESSFUL_PROGRAMS -eq $TOTAL_PROGRAMS ]; then
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}All programs built successfully!${NC}"
    echo -e "${GREEN}====================================${NC}"
    exit 0
else
    echo -e "${YELLOW}====================================${NC}"
    echo -e "${YELLOW}Build completed with errors${NC}"
    echo -e "${YELLOW}====================================${NC}"
    exit 1
fi
