#!/bin/bash
# Videomancer SDK Clean Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e  # Exit on error

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer SDK Clean Script${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Remove build directory
if [ -d "build" ]; then
    echo -e "${GREEN}Removing build directory...${NC}"
    rm -rf build
    echo -e "${GREEN}Build directory removed.${NC}"
else
    echo "No build directory found."
fi

echo ""
echo -e "${GREEN}Clean completed!${NC}"
echo ""
