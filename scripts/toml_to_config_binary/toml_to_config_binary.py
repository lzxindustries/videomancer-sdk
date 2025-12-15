#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Videomancer Program Config TOML to Binary Converter

Converts a TOML configuration file to a binary vmprog_program_config_v1_0 structure.
The output is compatible with the Videomancer SDK binary format specification.

Usage:
    python toml_to_config_binary.py input.toml output.bin
    python toml_to_config_binary.py input.toml output.bin --quiet

Structure sizes (bytes):
    - vmprog_parameter_config_v1_0: 572 bytes
    - vmprog_program_config_v1_0: 7240 bytes
"""

import struct
import sys
from pathlib import Path
from typing import Dict, Any

try:
    import tomli as tomllib  # Python 3.10 and below
except ImportError:
    import tomllib  # Python 3.11+


# =============================================================================
# Constants from vmprog_format.hpp
# =============================================================================

# vmprog_parameter_config_v1_0 constants
PARAM_NAME_LABEL_MAX_LENGTH = 32
PARAM_VALUE_LABEL_MAX_LENGTH = 32
PARAM_SUFFIX_LABEL_MAX_LENGTH = 4
PARAM_MAX_VALUE_LABELS = 16
PARAM_STRUCT_SIZE = 572

# vmprog_program_config_v1_0 constants
PROGRAM_ID_MAX_LENGTH = 64
PROGRAM_NAME_MAX_LENGTH = 32
AUTHOR_MAX_LENGTH = 64
LICENSE_MAX_LENGTH = 32
CATEGORY_MAX_LENGTH = 32
DESCRIPTION_MAX_LENGTH = 128
NUM_PARAMETERS = 12
CONFIG_STRUCT_SIZE = 7240

# Enum value bounds
MAX_PARAMETER_ID = 12  # linear_potentiometer_12
MAX_CONTROL_MODE = 35  # expo_in_out

# Global flag for quiet mode
QUIET = False


# =============================================================================
# Helper Functions
# =============================================================================

def pack_string(s: str, max_length: int) -> bytes:
    """
    Pack a string into a fixed-length null-terminated byte array.
    
    Args:
        s: String to pack
        max_length: Maximum length of the field including null terminator
    
    Returns:
        Bytes with string data padded with zeros
    
    Raises:
        ValueError: If string is too long
    """
    encoded = s.encode('utf-8')
    if len(encoded) >= max_length:
        raise ValueError(f"String '{s}' is too long ({len(encoded)} bytes, max {max_length - 1})")
    
    # Pad with zeros to max_length
    return encoded + b'\x00' * (max_length - len(encoded))


def validate_parameter_config(param: Dict[str, Any], index: int) -> None:
    """
    Validate a parameter configuration.
    
    Args:
        param: Parameter configuration dictionary
        index: Parameter index (0-based) for error messages
    
    Raises:
        ValueError: If validation fails
    """
    # Check parameter_id
    param_id = param.get('parameter_id', 0)
    if param_id > MAX_PARAMETER_ID:
        raise ValueError(
            f"Parameter {index}: invalid parameter_id {param_id} (max: {MAX_PARAMETER_ID})"
        )
    
    # Check control_mode
    control_mode = param.get('control_mode', 0)
    if control_mode > MAX_CONTROL_MODE:
        raise ValueError(
            f"Parameter {index}: invalid control_mode {control_mode} (max: {MAX_CONTROL_MODE})"
        )
    
    # Check value ranges
    min_val = param.get('min_value', 0)
    max_val = param.get('max_value', 0)
    init_val = param.get('initial_value', 0)
    
    if min_val > max_val:
        raise ValueError(
            f"Parameter {index}: min_value ({min_val}) > max_value ({max_val})"
        )
    
    if init_val < min_val or init_val > max_val:
        raise ValueError(
            f"Parameter {index}: initial_value ({init_val}) not in range [{min_val}, {max_val}]"
        )
    
    # Check value label count
    value_labels = param.get('value_labels', [])
    value_label_count = param.get('value_label_count', len(value_labels))
    
    if value_label_count > PARAM_MAX_VALUE_LABELS:
        raise ValueError(
            f"Parameter {index}: value_label_count ({value_label_count}) exceeds max ({PARAM_MAX_VALUE_LABELS})"
        )
    
    if value_label_count != len(value_labels):
        raise ValueError(
            f"Parameter {index}: value_label_count ({value_label_count}) != actual labels ({len(value_labels)})"
        )


def pack_parameter_config(param: Dict[str, Any]) -> bytes:
    """
    Pack a single parameter configuration into binary format.
    
    Structure layout (572 bytes):
        - parameter_id: uint32_t (4 bytes)
        - control_mode: uint32_t (4 bytes)
        - min_value: uint16_t (2 bytes)
        - max_value: uint16_t (2 bytes)
        - initial_value: uint16_t (2 bytes)
        - display_min_value: uint16_t (2 bytes)
        - display_max_value: uint16_t (2 bytes)
        - display_float_digits: uint8_t (1 byte)
        - value_label_count: uint8_t (1 byte)
        - reserved_pad: uint8_t[2] (2 bytes)
        - name_label: char[32] (32 bytes)
        - value_labels: char[16][32] (512 bytes)
        - suffix_label: char[4] (4 bytes)
        - reserved: uint8_t[2] (2 bytes)
    
    Args:
        param: Dictionary containing parameter configuration
    
    Returns:
        572 bytes of packed binary data
    """
    data = bytearray()
    
    # Pack integer fields (22 bytes)
    data += struct.pack('<I', param.get('parameter_id', 0))
    data += struct.pack('<I', param.get('control_mode', 0))
    data += struct.pack('<H', param.get('min_value', 0))
    data += struct.pack('<H', param.get('max_value', 0))
    data += struct.pack('<H', param.get('initial_value', 0))
    data += struct.pack('<H', param.get('display_min_value', 0))
    data += struct.pack('<H', param.get('display_max_value', 0))
    data += struct.pack('<B', param.get('display_float_digits', 0))
    
    # Value label count
    value_labels = param.get('value_labels', [])
    value_label_count = min(len(value_labels), PARAM_MAX_VALUE_LABELS)
    data += struct.pack('<B', value_label_count)
    
    # Reserved padding (2 bytes)
    data += b'\x00' * 2
    
    # Name label (32 bytes)
    data += pack_string(param.get('name_label', ''), PARAM_NAME_LABEL_MAX_LENGTH)
    
    # Value labels array (512 bytes = 16 * 32)
    for i in range(PARAM_MAX_VALUE_LABELS):
        if i < len(value_labels):
            data += pack_string(value_labels[i], PARAM_VALUE_LABEL_MAX_LENGTH)
        else:
            data += b'\x00' * PARAM_VALUE_LABEL_MAX_LENGTH
    
    # Suffix label (4 bytes)
    data += pack_string(param.get('suffix_label', ''), PARAM_SUFFIX_LABEL_MAX_LENGTH)
    
    # Reserved (2 bytes)
    data += b'\x00' * 2
    
    assert len(data) == PARAM_STRUCT_SIZE, f"Parameter size mismatch: {len(data)} != {PARAM_STRUCT_SIZE}"
    return bytes(data)


def pack_empty_parameter() -> bytes:
    """
    Pack an empty/zeroed parameter configuration.
    
    Returns:
        572 bytes of zeros
    """
    return b'\x00' * PARAM_STRUCT_SIZE


def validate_program_config(config: Dict[str, Any]) -> None:
    """
    Validate a program configuration.
    
    Args:
        config: Complete configuration dictionary from TOML
    
    Raises:
        ValueError: If validation fails
    """
    if 'program' not in config:
        raise ValueError("TOML must contain a [program] section")
    
    program = config['program']
    
    # Check required fields
    required_fields = ['program_id', 'program_name', 'author']
    for field in required_fields:
        if field not in program or not program[field]:
            raise ValueError(f"Missing or empty required field: program.{field}")
    
    # Validate ABI version ranges
    abi_min_major = program.get('abi_min_major', 1)
    abi_min_minor = program.get('abi_min_minor', 0)
    abi_max_major = program.get('abi_max_major', 2)
    abi_max_minor = program.get('abi_max_minor', 0)
    
    abi_min = (abi_min_major << 16) | abi_min_minor
    abi_max = (abi_max_major << 16) | abi_max_minor
    
    if abi_min >= abi_max:
        raise ValueError(
            f"Invalid ABI range: min ({abi_min_major}.{abi_min_minor}) >= max ({abi_max_major}.{abi_max_minor})"
        )
    
    # Validate parameter count
    parameters = config.get('parameter', [])
    declared_count = program.get('parameter_count', len(parameters))
    
    if declared_count > NUM_PARAMETERS:
        raise ValueError(
            f"parameter_count ({declared_count}) exceeds maximum ({NUM_PARAMETERS})"
        )
    
    if declared_count != len(parameters):
        raise ValueError(
            f"parameter_count ({declared_count}) does not match actual parameters ({len(parameters)})"
        )
    
    # Validate each parameter
    for i, param in enumerate(parameters):
        validate_parameter_config(param, i)


def pack_program_config(config: Dict[str, Any]) -> bytes:
    """
    Pack a complete program configuration into binary format.
    
    Structure layout (7240 bytes):
        - program_id: char[64] (64 bytes)
        - program_version_major: uint16_t (2 bytes)
        - program_version_minor: uint16_t (2 bytes)
        - program_version_patch: uint16_t (2 bytes)
        - abi_min_major: uint16_t (2 bytes)
        - abi_min_minor: uint16_t (2 bytes)
        - abi_max_major: uint16_t (2 bytes)
        - abi_max_minor: uint16_t (2 bytes)
        - hw_mask: uint32_t (4 bytes)
        - program_name: char[32] (32 bytes)
        - author: char[64] (64 bytes)
        - license: char[32] (32 bytes)
        - category: char[32] (32 bytes)
        - description: char[128] (128 bytes)
        - parameter_count: uint16_t (2 bytes)
        - reserved_pad: uint16_t (2 bytes)
        - parameters: vmprog_parameter_config_v1_0[12] (6864 bytes)
        - reserved: uint8_t[2] (2 bytes)
    
    Args:
        config: Dictionary containing program configuration from TOML
    
    Returns:
        7240 bytes of packed binary data
    """
    data = bytearray()
    
    program = config.get('program', {})
    
    # Program ID (64 bytes)
    data += pack_string(program.get('program_id', ''), PROGRAM_ID_MAX_LENGTH)
    
    # Version fields (12 bytes)
    data += struct.pack('<H', program.get('program_version_major', 0))
    data += struct.pack('<H', program.get('program_version_minor', 0))
    data += struct.pack('<H', program.get('program_version_patch', 0))
    data += struct.pack('<H', program.get('abi_min_major', 1))
    data += struct.pack('<H', program.get('abi_min_minor', 0))
    data += struct.pack('<H', program.get('abi_max_major', 2))
    data += struct.pack('<H', program.get('abi_max_minor', 0))
    
    # Hardware mask (4 bytes) - handle hex string or integer
    hw_mask = program.get('hw_mask', 0)
    if isinstance(hw_mask, str):
        hw_mask = int(hw_mask, 0)  # Auto-detect base (0x for hex)
    data += struct.pack('<I', hw_mask)
    
    # String metadata fields (288 bytes)
    data += pack_string(program.get('program_name', ''), PROGRAM_NAME_MAX_LENGTH)
    data += pack_string(program.get('author', ''), AUTHOR_MAX_LENGTH)
    data += pack_string(program.get('license', ''), LICENSE_MAX_LENGTH)
    data += pack_string(program.get('category', ''), CATEGORY_MAX_LENGTH)
    data += pack_string(program.get('description', ''), DESCRIPTION_MAX_LENGTH)
    
    # Parameter count and padding (4 bytes)
    parameters = config.get('parameter', [])
    parameter_count = min(len(parameters), NUM_PARAMETERS)
    data += struct.pack('<H', parameter_count)
    data += struct.pack('<H', 0)  # reserved_pad
    
    # Pack parameter array (6864 bytes = 12 * 572)
    for i in range(NUM_PARAMETERS):
        if i < len(parameters):
            data += pack_parameter_config(parameters[i])
        else:
            data += pack_empty_parameter()
    
    # Reserved (2 bytes)
    data += b'\x00' * 2
    
    assert len(data) == CONFIG_STRUCT_SIZE, f"Config size mismatch: {len(data)} != {CONFIG_STRUCT_SIZE}"
    return bytes(data)


# =============================================================================
# Main Converter
# =============================================================================

def convert_toml_to_binary(toml_path: Path, output_path: Path) -> None:
    """
    Convert a TOML configuration file to binary format.
    
    Args:
        toml_path: Path to input TOML file
        output_path: Path to output binary file
    
    Raises:
        ValueError: If validation fails
        IOError: If file operations fail
    """
    # Read and parse TOML
    if not QUIET:
        print(f"Reading TOML from: {toml_path}")
    
    with open(toml_path, 'rb') as f:
        config = tomllib.load(f)
    
    # Validate configuration
    if not QUIET:
        print(f"Validating configuration...")
    validate_program_config(config)
    
    # Pack to binary
    if not QUIET:
        print(f"Packing to binary format ({CONFIG_STRUCT_SIZE} bytes)...")
    binary_data = pack_program_config(config)
    
    # Write output
    if not QUIET:
        print(f"Writing binary to: {output_path}")
    
    with open(output_path, 'wb') as f:
        f.write(binary_data)
    
    if not QUIET:
        program = config['program']
        param_count = len(config.get('parameter', []))
        print(f"✓ Successfully converted {toml_path.name} → {output_path.name}")
        print(f"  Program: {program.get('program_name', 'Unknown')}")
        print(f"  Version: {program.get('program_version_major', 0)}.{program.get('program_version_minor', 0)}.{program.get('program_version_patch', 0)}")
        print(f"  Parameters: {param_count}/{NUM_PARAMETERS}")
        print(f"  Binary size: {len(binary_data)} bytes")


def main():
    """Command-line interface."""
    global QUIET
    
    # Parse arguments
    args = sys.argv[1:]
    if '--quiet' in args:
        QUIET = True
        args.remove('--quiet')
    if '-q' in args:
        QUIET = True
        args.remove('-q')
    
    if len(args) != 2:
        print("Usage: python toml_to_config_binary.py <input.toml> <output.bin> [--quiet]")
        print()
        print("Arguments:")
        print("  input.toml   TOML configuration file to convert")
        print("  output.bin   Output binary file path")
        print("  --quiet, -q  Suppress output messages")
        print()
        print("Example:")
        print("  python toml_to_config_binary.py example_program_config.toml program_config.bin")
        sys.exit(1)
    
    toml_path = Path(args[0])
    output_path = Path(args[1])
    
    if not toml_path.exists():
        print(f"Error: Input file not found: {toml_path}", file=sys.stderr)
        sys.exit(1)
    
    try:
        convert_toml_to_binary(toml_path, output_path)
    except ValueError as e:
        print(f"Validation error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
