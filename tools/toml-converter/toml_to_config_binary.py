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
    - vmprog_program_config_v1_0: 7372 bytes
"""

import struct
import sys
import re
from pathlib import Path
from typing import Dict, Any, Tuple

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
URL_MAX_LENGTH = 128
NUM_PARAMETERS = 12
CONFIG_STRUCT_SIZE = 7372

# Enum value bounds
MAX_PARAMETER_ID = 12  # linear_potentiometer_12
MAX_CONTROL_MODE = 35  # expo_in_out

# Enum string to integer mappings
PARAMETER_ID_MAP = {
    'none': 0,
    'rotary_potentiometer_1': 1,
    'rotary_potentiometer_2': 2,
    'rotary_potentiometer_3': 3,
    'rotary_potentiometer_4': 4,
    'rotary_potentiometer_5': 5,
    'rotary_potentiometer_6': 6,
    'toggle_switch_7': 7,
    'toggle_switch_8': 8,
    'toggle_switch_9': 9,
    'toggle_switch_10': 10,
    'toggle_switch_11': 11,
    'linear_potentiometer_12': 12
}

CONTROL_MODE_MAP = {
    'linear': 0,
    'linear_half': 1,
    'linear_quarter': 2,
    'linear_double': 3,
    'boolean': 4,
    'steps_4': 5,
    'steps_8': 6,
    'steps_16': 7,
    'steps_32': 8,
    'steps_64': 9,
    'steps_128': 10,
    'steps_256': 11,
    'polar_degs_90': 12,
    'polar_degs_180': 13,
    'polar_degs_360': 14,
    'polar_degs_720': 15,
    'polar_degs_1440': 16,
    'polar_degs_2880': 17,
    'quad_in': 18,
    'quad_out': 19,
    'quad_in_out': 20,
    'sine_in': 21,
    'sine_out': 22,
    'sine_in_out': 23,
    'circ_in': 24,
    'circ_out': 25,
    'circ_in_out': 26,
    'quint_in': 27,
    'quint_out': 28,
    'quint_in_out': 29,
    'quart_in': 30,
    'quart_out': 31,
    'quart_in_out': 32,
    'expo_in': 33,
    'expo_out': 34,
    'expo_in_out': 35
}

# Hardware compatibility flags
HARDWARE_FLAGS_MAP = {
    'videomancer_core_reva': 0x00000001,
    'videomancer_core_revb': 0x00000002,
}

# Core architecture identifiers
CORE_ID_MAP = {
    'none': 0,
    'yuv444_30b': 1,
    'yuv422_20b': 2,
}

# Global flag for quiet mode
QUIET = False


# =============================================================================
# Helper Functions
# =============================================================================

def parse_semver(version_str: str) -> Tuple[int, int, int]:
    """
    Parse a semantic version string into major, minor, patch integers.

    Args:
        version_str: Version string in format "major.minor.patch" (e.g., "1.2.3")

    Returns:
        Tuple of (major, minor, patch) as integers

    Raises:
        ValueError: If version string is invalid
    """
    match = re.match(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$', version_str)
    if not match:
        raise ValueError(f"Invalid SemVer format: '{version_str}' (expected 'major.minor.patch')")

    major, minor, patch = match.groups()
    return int(major), int(minor), int(patch)


def parse_abi_version_range(range_str: str) -> Tuple[int, int, int, int]:
    """
    Parse ABI version range string into min/max major/minor integers.

    Args:
        range_str: Range string in format ">=min_major.min_minor,<max_major.max_minor"
                  (e.g., ">=1.0,<2.0")

    Returns:
        Tuple of (min_major, min_minor, max_major, max_minor) as integers

    Raises:
        ValueError: If range string is invalid
    """
    match = re.match(r'^>=?(0|[1-9]\d*)\.(0|[1-9]\d*),<(0|[1-9]\d*)\.(0|[1-9]\d*)$', range_str)
    if not match:
        raise ValueError(
            f"Invalid ABI version range: '{range_str}' "
            f"(expected '>=major.minor,<major.minor')"
        )

    min_major, min_minor, max_major, max_minor = match.groups()
    return int(min_major), int(min_minor), int(max_major), int(max_minor)


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
    # Check parameter_id (convert string to int if needed)
    param_id = param.get('parameter_id', 0)
    if isinstance(param_id, str):
        if param_id not in PARAMETER_ID_MAP:
            raise ValueError(
                f"Parameter {index}: invalid parameter_id '{param_id}' (must be one of: {', '.join(PARAMETER_ID_MAP.keys())})"
            )
        param_id = PARAMETER_ID_MAP[param_id]

    if param_id > MAX_PARAMETER_ID:
        raise ValueError(
            f"Parameter {index}: invalid parameter_id {param_id} (max: {MAX_PARAMETER_ID})"
        )

    # Check control_mode (convert string to int if needed)
    control_mode = param.get('control_mode', 0)
    if isinstance(control_mode, str):
        if control_mode not in CONTROL_MODE_MAP:
            raise ValueError(
                f"Parameter {index}: invalid control_mode '{control_mode}' (must be one of: {', '.join(CONTROL_MODE_MAP.keys())})"
            )
        control_mode = CONTROL_MODE_MAP[control_mode]

    if control_mode > MAX_CONTROL_MODE:
        raise ValueError(
            f"Parameter {index}: invalid control_mode {control_mode} (max: {MAX_CONTROL_MODE})"
        )

    # Check for value_labels vs numeric fields mutual exclusivity
    value_labels = param.get('value_labels', [])
    has_value_labels = len(value_labels) > 0
    numeric_fields = ['min_value', 'max_value', 'initial_value', 'display_min_value',
                      'display_max_value', 'suffix_label', 'display_float_digits']
    has_numeric_fields = any(field in param for field in numeric_fields)

    if has_value_labels and has_numeric_fields:
        present_fields = [f for f in numeric_fields if f in param]
        raise ValueError(
            f"Parameter {index}: value_labels cannot be used with numeric fields. "
            f"Remove these fields: {', '.join(present_fields)}"
        )

    # Check control_mode mutual exclusivity with value_labels
    if has_value_labels and 'control_mode' in param:
        raise ValueError(
            f"Parameter {index}: control_mode should not be defined when value_labels are present. "
            f"Remove control_mode field."
        )

    if has_value_labels:
        # Validate value_labels requirements
        if len(value_labels) < 2:
            raise ValueError(
                f"Parameter {index}: value_labels must have at least 2 items (got {len(value_labels)})"
            )

        if len(value_labels) > PARAM_MAX_VALUE_LABELS:
            raise ValueError(
                f"Parameter {index}: too many value_labels ({len(value_labels)}, max: {PARAM_MAX_VALUE_LABELS})"
            )

        # Validate initial_value_label if present
        if 'initial_value_label' in param:
            initial_label = param['initial_value_label']
            if initial_label not in value_labels:
                raise ValueError(
                    f"Parameter {index}: initial_value_label '{initial_label}' not found in value_labels"
                )
    else:
        # Numeric mode validation
        if 'initial_value_label' in param:
            raise ValueError(
                f"Parameter {index}: initial_value_label can only be used with value_labels"
            )

        # Check value ranges for numeric mode
        min_val = param.get('min_value', 0)
        max_val = param.get('max_value', 1023)
        init_val = param.get('initial_value', 512)

        # Validate ranges
        if min_val < 0:
            raise ValueError(
                f"Parameter {index}: min_value ({min_val}) cannot be negative"
            )

        if max_val > 1023:
            raise ValueError(
                f"Parameter {index}: max_value ({max_val}) cannot exceed 1023"
            )

        if init_val < 0 or init_val > 1023:
            raise ValueError(
                f"Parameter {index}: initial_value ({init_val}) must be in range [0, 1023]"
            )

        if min_val >= max_val:
            raise ValueError(
                f"Parameter {index}: min_value ({min_val}) must be less than max_value ({max_val})"
            )

        if init_val < min_val or init_val > max_val:
            raise ValueError(
                f"Parameter {index}: initial_value ({init_val}) not in range [{min_val}, {max_val}]"
            )

    # Warn if value_label_count is specified (deprecated)
    if 'value_label_count' in param:
        specified_count = param['value_label_count']
        if specified_count != auto_count:
            print(f"WARNING: Parameter {index}: value_label_count ({specified_count}) ignored, using actual count ({auto_count})")



def pack_parameter_config(param: Dict[str, Any]) -> bytes:
    """
    Pack a single parameter configuration into binary format.

    Structure layout (572 bytes):
        - parameter_id: uint32_t (4 bytes)
        - control_mode: uint32_t (4 bytes)
        - min_value: uint16_t (2 bytes)
        - max_value: uint16_t (2 bytes)
        - initial_value: uint16_t (2 bytes)
        - display_min_value: int16_t (2 bytes)
        - display_max_value: int16_t (2 bytes)
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

    # Convert string enums to integers if needed
    param_id = param.get('parameter_id', 0)
    if isinstance(param_id, str):
        param_id = PARAMETER_ID_MAP.get(param_id, 0)

    # Handle control_mode: default to linear (0) if not defined or if value_labels present
    value_labels = param.get('value_labels', [])
    has_value_labels = len(value_labels) > 0

    if has_value_labels or 'control_mode' not in param:
        control_mode = 0  # linear
    else:
        control_mode = param.get('control_mode', 0)
        if isinstance(control_mode, str):
            control_mode = CONTROL_MODE_MAP.get(control_mode, 0)

    # Pack parameter ID and control mode
    data += struct.pack('<I', param_id)
    data += struct.pack('<I', control_mode)

    # Handle value_labels mode vs numeric mode
    value_labels = param.get('value_labels', [])
    has_value_labels = len(value_labels) > 0

    if has_value_labels:
        # Value labels mode - auto-calculate all numeric values
        num_labels = len(value_labels)
        min_val = 0
        max_val = num_labels - 1

        # Determine initial_value from initial_value_label if present
        if 'initial_value_label' in param:
            initial_label = param['initial_value_label']
            init_val = value_labels.index(initial_label)
        else:
            init_val = 0

        # Value range (uint16_t x 3)
        data += struct.pack('<H', min_val)
        data += struct.pack('<H', max_val)
        data += struct.pack('<H', init_val)

        # Display range (int16_t x 2) - same as value range for labels
        data += struct.pack('<h', min_val)
        data += struct.pack('<h', max_val)

        # Display float digits (uint8_t) - 0 for label mode
        data += struct.pack('<B', 0)

        # Value label count (uint8_t)
        data += struct.pack('<B', num_labels)
    else:
        # Numeric mode - use provided values or defaults
        min_val = param.get('min_value', 0)
        max_val = param.get('max_value', 1023)
        init_val = param.get('initial_value', 512)

        data += struct.pack('<H', min_val)
        data += struct.pack('<H', max_val)
        data += struct.pack('<H', init_val)

        # Display fields default to min/max values if not specified
        data += struct.pack('<h', param.get('display_min_value', min_val))
        data += struct.pack('<h', param.get('display_max_value', max_val))
        data += struct.pack('<B', param.get('display_float_digits', 0))

        # Value label count (uint8_t) - 0 for numeric mode
        data += struct.pack('<B', 0)

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

    # Check required fields (only program_id and program_name are mandatory)
    required_fields = ['program_id', 'program_name']
    for field in required_fields:
        if field not in program or not program[field]:
            raise ValueError(f"Missing or empty required field: program.{field}")

    # Check version format (support both old and new formats)
    has_semver = 'program_version' in program
    has_numeric = all(f in program for f in ['program_version_major', 'program_version_minor', 'program_version_patch'])

    if not has_semver and not has_numeric:
        raise ValueError(
            "Program version must be specified using either:\n"
            "  - program_version (SemVer string, e.g., '1.2.3'), or\n"
            "  - program_version_major, program_version_minor, program_version_patch (integers)"
        )

    if has_semver:
        try:
            parse_semver(program['program_version'])
        except ValueError as e:
            raise ValueError(f"Invalid program_version: {e}")

    # Check ABI version format (support both old and new formats)
    has_abi_range = 'abi_version' in program
    has_abi_numeric = all(f in program for f in ['abi_min_major', 'abi_min_minor', 'abi_max_major', 'abi_max_minor'])

    if not has_abi_range and not has_abi_numeric:
        raise ValueError(
            "ABI version must be specified using either:\n"
            "  - abi_version (range string, e.g., '>=1.0,<2.0'), or\n"
            "  - abi_min_major, abi_min_minor, abi_max_major, abi_max_minor (integers)"
        )

    if has_abi_range:
        try:
            min_maj, min_min, max_maj, max_min = parse_abi_version_range(program['abi_version'])
            # Validate range
            abi_min = (min_maj << 16) | min_min
            abi_max = (max_maj << 16) | max_min
            if abi_min >= abi_max:
                raise ValueError(
                    f"Invalid ABI range: min ({min_maj}.{min_min}) >= max ({max_maj}.{max_min})"
                )
        except ValueError as e:
            raise ValueError(f"Invalid abi_version: {e}")
    else:
        # Validate numeric ABI version ranges
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
    actual_count = len(parameters)

    # Check if parameter_count was specified (deprecated)
    if 'parameter_count' in program:
        declared_count = program['parameter_count']
        if declared_count != actual_count:
            print(f"WARNING: parameter_count ({declared_count}) ignored, using actual parameter count ({actual_count})")

    if actual_count > NUM_PARAMETERS:
        raise ValueError(
            f"Too many parameters ({actual_count}, maximum: {NUM_PARAMETERS})"
        )

    # Check for unique parameter_ids
    param_ids = []
    for i, param in enumerate(parameters):
        param_id = param.get('parameter_id')
        if param_id and param_id != 'none' and param_id != 'No parameter assigned':
            if param_id in param_ids:
                raise ValueError(
                    f"Duplicate parameter_id '{param_id}' found. Each parameter must have a unique parameter_id."
                )
            param_ids.append(param_id)

    # Validate each parameter
    for i, param in enumerate(parameters):
        validate_parameter_config(param, i)


def pack_program_config(config: Dict[str, Any]) -> bytes:
    """
    Pack a complete program configuration into binary format.

    Structure layout (7372 bytes):
        - program_id: char[64] (64 bytes)
        - program_version_major: uint16_t (2 bytes)
        - program_version_minor: uint16_t (2 bytes)
        - program_version_patch: uint16_t (2 bytes)
        - abi_min_major: uint16_t (2 bytes)
        - abi_min_minor: uint16_t (2 bytes)
        - abi_max_major: uint16_t (2 bytes)
        - abi_max_minor: uint16_t (2 bytes)
        - hw_mask: uint32_t (4 bytes) - built from hardware_compatibility array
        - program_name: char[32] (32 bytes)
        - author: char[64] (64 bytes)
        - license: char[32] (32 bytes)
        - category: char[32] (32 bytes)
        - description: char[128] (128 bytes)
        - url: char[128] (128 bytes)
        - parameter_count: uint16_t (2 bytes)
        - reserved_pad: uint16_t (2 bytes)
        - parameters: vmprog_parameter_config_v1_0[12] (6864 bytes)
        - reserved: uint8_t[2] (2 bytes)

    Args:
        config: Dictionary containing program configuration from TOML

    Returns:
        7372 bytes of packed binary data
    """
    data = bytearray()

    program = config.get('program', {})

    # Program ID (64 bytes)
    data += pack_string(program.get('program_id', ''), PROGRAM_ID_MAX_LENGTH)

    # Version fields (12 bytes) - support both old and new formats
    if 'program_version' in program:
        # Parse SemVer string
        major, minor, patch = parse_semver(program['program_version'])
        data += struct.pack('<H', major)
        data += struct.pack('<H', minor)
        data += struct.pack('<H', patch)
    else:
        # Use individual numeric fields
        data += struct.pack('<H', program.get('program_version_major', 0))
        data += struct.pack('<H', program.get('program_version_minor', 0))
        data += struct.pack('<H', program.get('program_version_patch', 0))

    # ABI version fields (8 bytes) - support both old and new formats
    if 'abi_version' in program:
        # Parse range string
        min_maj, min_min, max_maj, max_min = parse_abi_version_range(program['abi_version'])
        data += struct.pack('<H', min_maj)
        data += struct.pack('<H', min_min)
        data += struct.pack('<H', max_maj)
        data += struct.pack('<H', max_min)
    else:
        # Use individual numeric fields
        data += struct.pack('<H', program.get('abi_min_major', 1))
        data += struct.pack('<H', program.get('abi_min_minor', 0))
        data += struct.pack('<H', program.get('abi_max_major', 2))
        data += struct.pack('<H', program.get('abi_max_minor', 0))

    # Hardware mask (4 bytes) - build from hardware_compatibility array
    hw_mask = 0
    hardware_compat = program.get('hardware_compatibility', [])
    if hardware_compat:
        for hw_name in hardware_compat:
            if hw_name in HARDWARE_FLAGS_MAP:
                hw_mask |= HARDWARE_FLAGS_MAP[hw_name]
            else:
                if not QUIET:
                    print(f"WARNING: Unknown hardware platform '{hw_name}', ignoring", file=sys.stderr)
    else:
        # Default to all platforms if not specified
        hw_mask = 0x00000003  # videomancer_core_reva | videomancer_core_revb
        if not QUIET:
            print("WARNING: No hardware_compatibility specified, defaulting to all platforms", file=sys.stderr)

    data += struct.pack('<I', hw_mask)

    # Core ID (4 bytes)
    core_str = program.get('core', 'yuv444_30b')
    if core_str in CORE_ID_MAP:
        core_id = CORE_ID_MAP[core_str]
    else:
        if not QUIET:
            print(f"WARNING: Unknown core '{core_str}', defaulting to yuv444_30b", file=sys.stderr)
        core_id = CORE_ID_MAP['yuv444_30b']
    data += struct.pack('<I', core_id)

    # String metadata fields (288 bytes)
    data += pack_string(program.get('program_name', ''), PROGRAM_NAME_MAX_LENGTH)
    data += pack_string(program.get('author', ''), AUTHOR_MAX_LENGTH)
    data += pack_string(program.get('license', ''), LICENSE_MAX_LENGTH)
    data += pack_string(program.get('category', ''), CATEGORY_MAX_LENGTH)
    data += pack_string(program.get('description', ''), DESCRIPTION_MAX_LENGTH)

    # URL field (128 bytes)
    data += pack_string(program.get('url', ''), URL_MAX_LENGTH)

    # Parameter count and padding (4 bytes) - auto-calculated from array
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

        # Display version - support both new and old formats
        if 'program_version' in program:
            version_str = program['program_version']
        else:
            major = program.get('program_version_major', 0)
            minor = program.get('program_version_minor', 0)
            patch = program.get('program_version_patch', 0)
            version_str = f"{major}.{minor}.{patch}"

        # Display hardware compatibility
        hw_compat = program.get('hardware_compatibility', [])
        hw_str = ', '.join(hw_compat) if hw_compat else 'all platforms (default)'

        # Display core architecture
        core_str = program.get('core', 'yuv444_10b')

        print(f"✓ Successfully converted {toml_path.name} → {output_path.name}")
        print(f"  Program: {program.get('program_name', 'Unknown')}")
        print(f"  Version: {version_str}")
        print(f"  Hardware: {hw_str}")
        print(f"  Core: {core_str}")
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
