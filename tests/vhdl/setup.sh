#!/bin/bash
# Videomancer SDK - Quick VHDL Test Setup Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e

echo "Setting up VHDL testing environment..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not found."
    exit 1
fi

# Install VUnit
echo "Installing VUnit..."

# Try different installation methods
if pip3 install --user vunit-hdl 2>/dev/null; then
    echo "VUnit installed successfully (user installation)"
elif pip3 install --break-system-packages vunit-hdl 2>/dev/null; then
    echo "VUnit installed successfully (system installation)"
    echo "Note: Used --break-system-packages flag (Ubuntu 24.04+)"
else
    echo ""
    echo "Error: Could not install VUnit via pip."
    echo ""
    echo "On Ubuntu 24.04+, Python environment is externally managed."
    echo "Options:"
    echo "  1. Install with break-system-packages (quick but not ideal):"
    echo "     pip3 install --break-system-packages vunit-hdl"
    echo ""
    echo "  2. Use a virtual environment (recommended):"
    echo "     python3 -m venv venv"
    echo "     source venv/bin/activate"
    echo "     pip install vunit-hdl"
    echo ""
    exit 1
fi

# Check for GHDL
if ! command -v ghdl &> /dev/null; then
    echo ""
    echo "Warning: GHDL not found in PATH."
    echo "Options:"
    echo "  1. Run scripts/setup.sh from project root to get GHDL via OSS CAD Suite"
    echo "  2. Install GHDL separately: sudo apt-get install ghdl"
    echo ""
    
    # Check if OSS CAD Suite is available
    if [ -f "../../build/oss-cad-suite/bin/ghdl" ]; then
        echo "Found GHDL in oss-cad-suite. Adding to PATH for this session..."
        export PATH="$(cd ../../build/oss-cad-suite/bin && pwd):$PATH"
        echo "GHDL found: $(which ghdl)"
    else
        echo "To use GHDL from OSS CAD Suite, run from project root:"
        echo "  bash scripts/setup.sh"
        exit 1
    fi
fi

echo ""
echo "Setup complete! GHDL version:"
ghdl --version | head -n 1

echo ""
echo "Run tests with: python3 run.py"
