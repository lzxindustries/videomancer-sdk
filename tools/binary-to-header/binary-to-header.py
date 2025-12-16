#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Videomancer SDK - Binary to C++ Header/Source Generator

This tool converts a binary file into C++ header and source files,
embedding the binary data as a const uint8_t array.

License: GNU General Public License v3.0
https://github.com/lzxindustries/videomancer-sdk

This file is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
"""

import argparse
import os
import sys
from pathlib import Path


def read_template(template_path: str) -> str:
    """Read a template file and return its contents."""
    try:
        with open(template_path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Error: Template file not found: {template_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading template file {template_path}: {e}", file=sys.stderr)
        sys.exit(1)


def read_binary_file(input_path: str) -> bytes:
    """Read binary file and return its contents."""
    try:
        with open(input_path, 'rb') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file {input_path}: {e}", file=sys.stderr)
        sys.exit(1)


def format_byte_array(data: bytes, bytes_per_line: int = 12) -> str:
    """Format binary data as a C++ byte array initialization."""
    lines = []
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        formatted = ', '.join(f'0x{byte:02X}' for byte in chunk)
        lines.append(f'    {formatted}')

    return ',\n'.join(lines)


def generate_from_template(template_content: str, substitutions: dict) -> str:
    """Generate output by substituting placeholders in template."""
    result = template_content
    for key, value in substitutions.items():
        placeholder = f'{{{{{key}}}}}'
        result = result.replace(placeholder, str(value))
    return result


def sanitize_identifier(name: str) -> str:
    """Convert a filename to a valid C++ identifier."""
    # Remove extension and path
    base = Path(name).stem
    # Replace invalid characters with underscores
    sanitized = ''.join(c if c.isalnum() else '_' for c in base)
    # Ensure it doesn't start with a number
    if sanitized and sanitized[0].isdigit():
        sanitized = '_' + sanitized
    return sanitized


def main():
    parser = argparse.ArgumentParser(
        description='Convert binary files to C++ header and source files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -i firmware.bin -o output/firmware.h -s output/firmware.cpp
  %(prog)s -i data.bin -o data.h -s data.cpp --name my_data
  %(prog)s -i image.png -o include/image.h -s src/image.cpp --header-template custom.h.template
        """
    )

    parser.add_argument('-i', '--input', required=True,
                        help='Input binary file path')
    parser.add_argument('-o', '--output-header', required=True,
                        help='Output header file path (.h)')
    parser.add_argument('-s', '--output-source', required=True,
                        help='Output source file path (.cpp)')
    parser.add_argument('-n', '--name',
                        help='Variable name (default: derived from input filename)')
    parser.add_argument('--header-template',
                        help='Path to custom header template file')
    parser.add_argument('--source-template',
                        help='Path to custom source template file')
    parser.add_argument('--namespace',
                        help='C++ namespace to use (optional)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose output')

    args = parser.parse_args()

    # Determine template paths
    script_dir = Path(__file__).parent
    header_template_path = args.header_template or script_dir / 'header.template'
    source_template_path = args.source_template or script_dir / 'source.template'

    # Read binary data
    if args.verbose:
        print(f"Reading binary file: {args.input}")
    binary_data = read_binary_file(args.input)
    data_size = len(binary_data)

    if args.verbose:
        print(f"Binary file size: {data_size} bytes")

    # Determine variable name
    var_name = args.name or sanitize_identifier(args.input)

    if args.verbose:
        print(f"Variable name: {var_name}")

    # Create output directories if needed
    os.makedirs(os.path.dirname(args.output_header) or '.', exist_ok=True)
    os.makedirs(os.path.dirname(args.output_source) or '.', exist_ok=True)

    # Prepare substitutions
    header_guard = f"{var_name.upper()}_H"
    formatted_data = format_byte_array(binary_data)
    header_filename = os.path.basename(args.output_header)

    substitutions = {
        'HEADER_GUARD': header_guard,
        'VAR_NAME': var_name,
        'DATA_SIZE': data_size,
        'HEADER_FILENAME': header_filename,
        'BINARY_DATA': formatted_data,
        'NAMESPACE': args.namespace or '',
    }

    # Add namespace-specific substitutions
    if args.namespace:
        substitutions['NAMESPACE_BEGIN'] = f'namespace {args.namespace} {{'
        substitutions['NAMESPACE_END'] = f'}} // namespace {args.namespace}'
    else:
        substitutions['NAMESPACE_BEGIN'] = ''
        substitutions['NAMESPACE_END'] = ''

    # Read templates
    if args.verbose:
        print(f"Reading header template: {header_template_path}")
    header_template = read_template(str(header_template_path))

    if args.verbose:
        print(f"Reading source template: {source_template_path}")
    source_template = read_template(str(source_template_path))

    # Generate output
    if args.verbose:
        print(f"Generating header: {args.output_header}")
    header_content = generate_from_template(header_template, substitutions)

    if args.verbose:
        print(f"Generating source: {args.output_source}")
    source_content = generate_from_template(source_template, substitutions)

    # Write output files
    try:
        with open(args.output_header, 'w') as f:
            f.write(header_content)

        with open(args.output_source, 'w') as f:
            f.write(source_content)

        if args.verbose:
            print("Generation complete!")
        else:
            print(f"Generated {args.output_header} and {args.output_source}")

    except Exception as e:
        print(f"Error writing output files: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
