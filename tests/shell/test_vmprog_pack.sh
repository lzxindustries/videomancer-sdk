#!/bin/bash
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
#
# Test script for vmprog_pack.py
# Tests package creation and validation

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================================================"
echo "vmprog_pack Test Suite"
echo "========================================================================"
echo "Project root: $PROJECT_ROOT"
echo

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found"
    exit 1
fi

echo "✓ Python: $(python3 --version)"
echo

# Test 1: Passthru program
echo "========================================================================"
echo "Test 1: Package passthru program"
echo "========================================================================"

INPUT_DIR="$PROJECT_ROOT/build/programs/passthru/rev_a"
OUTPUT_FILE="$PROJECT_ROOT/build/passthru.vmprog"

if [ ! -d "$INPUT_DIR" ]; then
    echo "SKIP: Input directory not found: $INPUT_DIR"
    echo "      (Run build system first to generate bitstreams)"
else
    echo "Input: $INPUT_DIR"
    echo "Output: $OUTPUT_FILE"
    echo

    python3 "$PROJECT_ROOT/tools/vmprog-packer/vmprog_pack.py" --no-sign "$INPUT_DIR" "$OUTPUT_FILE"

    if [ -f "$OUTPUT_FILE" ]; then
        echo
        echo "✓ Test 1 PASSED"
        echo "  Created: $OUTPUT_FILE"
        echo "  Size: $(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null) bytes"
    else
        echo
        echo "✗ Test 1 FAILED: Output file not created"
        exit 1
    fi
fi

echo

# Test 2: YUV Amplifier program (if available)
echo "========================================================================"
echo "Test 2: Package yuv_amplifier program"
echo "========================================================================"

INPUT_DIR="$PROJECT_ROOT/build/programs/yuv_amplifier/rev_a"
OUTPUT_FILE="$PROJECT_ROOT/build/yuv_amplifier.vmprog"

if [ ! -d "$INPUT_DIR" ]; then
    echo "SKIP: Input directory not found: $INPUT_DIR"
    echo "      (Build yuv_amplifier program first)"
else
    echo "Input: $INPUT_DIR"
    echo "Output: $OUTPUT_FILE"
    echo

    python3 "$PROJECT_ROOT/tools/vmprog-packer/vmprog_pack.py" --no-sign "$INPUT_DIR" "$OUTPUT_FILE"

    if [ -f "$OUTPUT_FILE" ]; then
        echo
        echo "✓ Test 2 PASSED"
        echo "  Created: $OUTPUT_FILE"
        echo "  Size: $(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null) bytes"
    else
        echo
        echo "✗ Test 2 FAILED: Output file not created"
        exit 1
    fi
fi

echo

# Summary
echo "========================================================================"
echo "Test Suite Complete"
echo "========================================================================"
echo "All tests passed successfully!"
echo

exit 0
