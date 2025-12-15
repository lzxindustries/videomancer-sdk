#!/bin/bash
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
#
# Test script for TOML to binary conversion

set -e

echo "=== Videomancer Config Converter Test ==="
echo

# Check Python availability
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found"
    exit 1
fi

echo "Python version:"
python3 --version
echo

# Check for tomllib/tomli
echo "Checking for TOML parser..."
if python3 -c "import tomllib" 2>/dev/null; then
    echo "✓ Using tomllib (Python 3.11+)"
elif python3 -c "import tomli" 2>/dev/null; then
    echo "✓ Using tomli"
else
    echo "Installing tomli..."
    pip3 install tomli
fi
echo

# Run the conversion
echo "Converting TOML to binary..."
python3 toml_to_config_binary.py example_program_config.toml example_program_config.bin
echo

# Verify output
if [ -f "example_program_config.bin" ]; then
    SIZE=$(stat -f%z "example_program_config.bin" 2>/dev/null || stat -c%s "example_program_config.bin")
    echo "=== Verification ==="
    echo "Output file: example_program_config.bin"
    echo "Size: $SIZE bytes (expected: 7240)"
    
    if [ "$SIZE" -eq 7240 ]; then
        echo "✓ Size matches!"
    else
        echo "✗ Size mismatch!"
        exit 1
    fi
    
    echo
    echo "First 128 bytes (hex dump):"
    xxd -l 128 example_program_config.bin
    
    echo
    echo "=== Test Passed ==="
else
    echo "✗ Output file not created"
    exit 1
fi
