#!/bin/bash
# Videomancer SDK - Clean FPGA Programs Build Artifacts
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer Programs Build Cleaner${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Root paths - can be overridden by environment variables
VIDEOMANCER_BUILD_PROGRAMS_DIR="${VIDEOMANCER_BUILD_DIR:-${SCRIPT_DIR}/build/programs/}"
VIDEOMANCER_OUT_DIR="${VIDEOMANCER_OUT_DIR:-${SCRIPT_DIR}/out/}"

cd "${SCRIPT_DIR}"

# Clean build/programs/ directory
if [ -d "${VIDEOMANCER_BUILD_PROGRAMS_DIR}" ]; then
    echo -e "${CYAN}Cleaning build artifacts in ${VIDEOMANCER_BUILD_PROGRAMS_DIR}...${NC}"

    # Count files before deletion
    FILE_COUNT=$(find "${VIDEOMANCER_BUILD_PROGRAMS_DIR}" -type f 2>/dev/null | wc -l)

    if [ "$FILE_COUNT" -gt 0 ]; then
        # Remove all contents but keep the directory
        rm -rf "${VIDEOMANCER_BUILD_PROGRAMS_DIR}"*
        echo -e "${GREEN}✓ Removed ${FILE_COUNT} build artifact files${NC}"
    else
        echo -e "${YELLOW}  Already clean (no files found)${NC}"
    fi
else
    echo -e "${YELLOW}Build directory ${VIDEOMANCER_BUILD_PROGRAMS_DIR} does not exist${NC}"
fi

echo ""

# Clean out/ directory
if [ -d "${VIDEOMANCER_OUT_DIR}" ]; then
    echo -e "${CYAN}Cleaning packaged programs in ${VIDEOMANCER_OUT_DIR}...${NC}"

    # Count .vmprog files before deletion
    VMPROG_COUNT=$(find "${VIDEOMANCER_OUT_DIR}" -name "*.vmprog" -type f 2>/dev/null | wc -l)

    if [ "$VMPROG_COUNT" -gt 0 ]; then
        # Remove all .vmprog files
        rm -f "${VIDEOMANCER_OUT_DIR}"*.vmprog
        echo -e "${GREEN}✓ Removed ${VMPROG_COUNT} .vmprog package(s)${NC}"
    else
        echo -e "${YELLOW}  Already clean (no .vmprog files found)${NC}"
    fi
else
    echo -e "${YELLOW}Output directory ${VIDEOMANCER_OUT_DIR} does not exist${NC}"
fi

echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}Cleanup complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${CYAN}Note: OSS CAD Suite toolchain and other build artifacts were preserved${NC}"
