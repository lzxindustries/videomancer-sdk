#!/bin/bash
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
#
# Test script for TOML to binary conversion

set -e

# Get repository root (script is in tests/shell/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools/toml-converter"
EXAMPLES_DIR="$REPO_ROOT/examples/templates"

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
cd "$TOOLS_DIR"
python3 toml_to_config_binary.py "$EXAMPLES_DIR/template.toml" /tmp/test_config.bin
echo

# Verify output
if [ -f "/tmp/test_config.bin" ]; then
    SIZE=$(stat -f%z "/tmp/test_config.bin" 2>/dev/null || stat -c%s "/tmp/test_config.bin")
    echo "=== Verification ==="
    echo "Output file: /tmp/test_config.bin"
    echo "Size: $SIZE bytes (expected: 7368)"
    
    if [ "$SIZE" -eq 7368 ]; then
        echo "✓ Size matches!"
        rm /tmp/test_config.bin
        exit 0
    else
        echo "✗ Size mismatch!"
        rm /tmp/test_config.bin
        exit 1
    fi
else
    echo "✗ Output file not created"
    exit 1
fi
    xxd -l 128 template_test.bin
    
    echo
    echo "=== Test Passed ==="
else
    echo "✗ Output file not created"
    exit 1
fi
