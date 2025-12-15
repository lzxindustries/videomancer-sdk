
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
cd "$SCRIPT_DIR"

# Determine which programs to build
PROGRAMS="${1:-$(find ./programs/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)}"
PROGRAM_COUNT=$(echo "$PROGRAMS" | wc -w)

DEVICE=hx4k
PACKAGE=tq144
HARDWARE=videomancer_core_rev_b

if [ -n "$1" ]; then
    echo -e "${CYAN}Building specific program: ${1}${NC}"
else
    echo -e "${CYAN}Building all programs (${PROGRAM_COUNT} found)${NC}"
fi
echo ""

# Check for OSS CAD Suite
if [ ! -d "build/oss-cad-suite" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite not found!${NC}"
    echo -e "${RED}Please run ./setup.sh first to install the FPGA toolchain.${NC}"
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
mkdir -p build/programs
mkdir -p out

# Track build statistics
TOTAL_PROGRAMS=0
SUCCESSFUL_PROGRAMS=0
FAILED_PROGRAMS=0

for PROGRAM in $PROGRAMS; do
    TOTAL_PROGRAMS=$((TOTAL_PROGRAMS + 1))
    
    echo ""
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}Program ${TOTAL_PROGRAMS}/${PROGRAM_COUNT}: ${PROGRAM}${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    
    # Check if program directory exists
    if [ ! -d "programs/${PROGRAM}" ]; then
        echo -e "${RED}ERROR: Program directory 'programs/${PROGRAM}' not found${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi
    
    # Create output directories
    echo -e "${GREEN}Creating output directories...${NC}"
    mkdir -p build/programs/${PROGRAM}/bitstreams
    
    # Synthesize FPGA bitstreams (6 variants)
    echo -e "${GREEN}Synthesizing FPGA bitstreams...${NC}"
    cd fpga
    
    echo -e "${CYAN}  [1/6] HD Analog (80 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=hd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    echo -e "${CYAN}  [2/6] SD Analog (30 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=sd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    echo -e "${CYAN}  [3/6] HD HDMI (80 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=hd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    echo -e "${CYAN}  [4/6] SD HDMI (30 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=sd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    echo -e "${CYAN}  [5/6] HD Dual (80 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=hd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=80 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    echo -e "${CYAN}  [6/6] SD Dual (30 MHz)...${NC}"
    make PROGRAM=$PROGRAM CONFIG=sd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=30 HARDWARE=$HARDWARE > /dev/null 2>&1
    
    cd ..
    echo -e "${GREEN}✓ All 6 bitstream variants generated${NC}"
    
    # Convert TOML configuration to binary
    echo -e "${GREEN}Converting TOML configuration to binary...${NC}"
    cd scripts/toml_to_config_binary
    python3 toml_to_config_binary.py ../../programs/${PROGRAM}/${PROGRAM}.toml ../../build/programs/${PROGRAM}/program_config.bin --quiet
    cd ../..
    echo -e "${GREEN}✓ Configuration binary created (7,240 bytes)${NC}"
    
    # Clean up intermediate files
    echo -e "${GREEN}Cleaning intermediate files...${NC}"
    cd build/programs/${PROGRAM}/bitstreams
    rm -f *.asc *.json
    cd ../../../..
    
    # Package into .vmprog format
    echo -e "${GREEN}Packaging ${PROGRAM}.vmprog...${NC}"
    cd scripts/vmprog_pack
    
    if [ "$SIGN_PACKAGES" = true ]; then
        echo -e "${CYAN}  Signing package with Ed25519...${NC}"
        python3 vmprog_pack.py ../../build/programs/${PROGRAM} ../../out/${PROGRAM}.vmprog > /dev/null 2>&1
    else
        python3 vmprog_pack.py --no-sign ../../build/programs/${PROGRAM} ../../out/${PROGRAM}.vmprog > /dev/null 2>&1
    fi
    
    cd ../..
    
    # Verify output file
    if [ -f "out/${PROGRAM}.vmprog" ]; then
        FILESIZE=$(stat -f%z "out/${PROGRAM}.vmprog" 2>/dev/null || stat -c%s "out/${PROGRAM}.vmprog" 2>/dev/null)
        if [ "$SIGN_PACKAGES" = true ]; then
            echo -e "${GREEN}✓ Successfully created: out/${PROGRAM}.vmprog (${FILESIZE} bytes, SIGNED)${NC}"
        else
            echo -e "${GREEN}✓ Successfully created: out/${PROGRAM}.vmprog (${FILESIZE} bytes, unsigned)${NC}"
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
if [ "$SIGN_PACKAGES" = true ]; then
    echo -e "${GREEN}All packages cryptographically signed with Ed25519${NC}"
else
    echo -e "${YELLOW}Packages are unsigned (no Ed25519 keys found)${NC}"
fi
    echo -e "${RED}Failed:                    ${FAILED_PROGRAMS}${NC}"
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
