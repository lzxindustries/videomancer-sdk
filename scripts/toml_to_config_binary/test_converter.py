#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Quick verification script to test the TOML to binary converter.
This script runs the conversion and validates the output.
"""

import sys
from pathlib import Path

# Check for TOML library
try:
    import tomli as tomllib
    print("Using tomli library")
except ImportError:
    try:
        import tomllib
        print("Using tomllib (Python 3.11+)")
    except ImportError:
        print("Error: No TOML library found. Install with: pip3 install tomli")
        sys.exit(1)

# Import the converter
try:
    import toml_to_config_binary
except ImportError:
    print("Error: Could not import toml_to_config_binary.py")
    print("Make sure you're running this from the scripts/toml_to_config_binary directory")
    sys.exit(1)

def verify_binary_output(binary_path: Path):
    """Verify the binary output structure."""
    print(f"\n=== Verifying Binary Output ===")
    
    with open(binary_path, 'rb') as f:
        data = f.read()
    
    print(f"File size: {len(data)} bytes (expected: 7240)")
    
    if len(data) != 7240:
        print("✗ Size mismatch!")
        return False
    
    print("✓ Size correct!")
    
    # Parse some fields to verify structure
    import struct
    
    # Read program_id (first 64 bytes)
    program_id = data[0:64].rstrip(b'\x00').decode('utf-8')
    print(f"\nProgram ID: {program_id}")
    
    # Read version fields (bytes 64-76)
    version_major, version_minor, version_patch = struct.unpack('<HHH', data[64:70])
    print(f"Version: {version_major}.{version_minor}.{version_patch}")
    
    # Read ABI fields
    abi_min_major, abi_min_minor = struct.unpack('<HH', data[70:74])
    abi_max_major, abi_max_minor = struct.unpack('<HH', data[74:78])
    print(f"ABI Min: {abi_min_major}.{abi_min_minor}")
    print(f"ABI Max: {abi_max_major}.{abi_max_minor}")
    
    # Read hw_mask
    hw_mask = struct.unpack('<I', data[78:82])[0]
    print(f"HW Mask: 0x{hw_mask:08x}")
    
    # Read program_name (bytes 82-114)
    program_name = data[82:114].rstrip(b'\x00').decode('utf-8')
    print(f"Program Name: {program_name}")
    
    # Read author (bytes 114-178)
    author = data[114:178].rstrip(b'\x00').decode('utf-8')
    print(f"Author: {author}")
    
    # Read license (bytes 178-210)
    license_str = data[178:210].rstrip(b'\x00').decode('utf-8')
    print(f"License: {license_str}")
    
    # Read category (bytes 210-242)
    category = data[210:242].rstrip(b'\x00').decode('utf-8')
    print(f"Category: {category}")
    
    # Read description (bytes 242-370)
    description = data[242:370].rstrip(b'\x00').decode('utf-8')
    print(f"Description: {description}")
    
    # Read parameter_count (bytes 370-372)
    parameter_count = struct.unpack('<H', data[370:372])[0]
    print(f"\nParameter Count: {parameter_count}")
    
    # Read first parameter (starts at byte 374)
    if parameter_count > 0:
        param_offset = 374
        param_id, control_mode = struct.unpack('<II', data[param_offset:param_offset+8])
        min_val, max_val, init_val = struct.unpack('<HHH', data[param_offset+8:param_offset+14])
        print(f"\nParameter 1:")
        print(f"  ID: {param_id}")
        print(f"  Control Mode: {control_mode}")
        print(f"  Min: {min_val}, Max: {max_val}, Initial: {init_val}")
        
        # Read parameter name (at offset 374 + 22 = 396)
        param_name_offset = param_offset + 22
        param_name = data[param_name_offset:param_name_offset+32].rstrip(b'\x00').decode('utf-8')
        print(f"  Name: {param_name}")
    
    print("\n✓ Binary structure verified!")
    return True


def main():
    """Run the test."""
    print("=== Videomancer Config Converter Test ===\n")
    
    toml_path = Path('example_program_config.toml')
    output_path = Path('program_config.bin')
    
    # Check input file exists
    if not toml_path.exists():
        print(f"Error: {toml_path} not found")
        sys.exit(1)
    
    # Run conversion
    print(f"Converting {toml_path} → {output_path}\n")
    try:
        toml_to_config_binary.convert_toml_to_binary(toml_path, output_path)
    except Exception as e:
        print(f"\n✗ Conversion failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    # Verify output
    if not output_path.exists():
        print("✗ Output file not created")
        sys.exit(1)
    
    if not verify_binary_output(output_path):
        sys.exit(1)
    
    print("\n=== All Tests Passed ===")


if __name__ == '__main__':
    main()
