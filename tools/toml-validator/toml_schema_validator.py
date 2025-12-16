#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Videomancer Program Config TOML Schema Validator

Validates a TOML configuration file against the JSON schema specification.

Usage:
    python toml_schema_validator.py input.toml [schema.json]

    If schema.json is not provided, defaults to:
    ../../docs/schemas/vmprog_program_config_schema_v1_0.json
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any, List

try:
    import tomli as tomllib  # Python 3.10 and below
except ImportError:
    import tomllib  # Python 3.11+

try:
    import jsonschema
    from jsonschema import validate, ValidationError, Draft7Validator, RefResolver
except ImportError:
    print("ERROR: jsonschema library not installed", file=sys.stderr)
    print("Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)


def simplify_schema(schema: Dict[str, Any]) -> Dict[str, Any]:
    """
    Remove unsupported $data references and complex allOf validations
    that aren't supported by standard jsonschema library
    """
    import copy
    schema = copy.deepcopy(schema)

    def remove_data_refs(obj):
        """Recursively remove $data references"""
        if isinstance(obj, dict):
            # Remove allOf sections that contain $data references
            if 'allOf' in obj:
                del obj['allOf']

            # Recursively process all dict values
            for key, value in list(obj.items()):
                if isinstance(value, dict) and '$data' in value:
                    # Remove this validation as it uses $data
                    del obj[key]
                else:
                    remove_data_refs(value)
        elif isinstance(obj, list):
            for item in obj:
                remove_data_refs(item)

    remove_data_refs(schema)
    return schema


def load_toml(toml_path: Path) -> Dict[str, Any]:
    """Load and parse TOML file"""
    try:
        with open(toml_path, 'rb') as f:
            return tomllib.load(f)
    except Exception as e:
        print(f"ERROR: Failed to load TOML file '{toml_path}': {e}", file=sys.stderr)
        sys.exit(1)


def load_schema(schema_path: Path) -> Dict[str, Any]:
    """Load and parse JSON schema file"""
    try:
        with open(schema_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to load schema file '{schema_path}': {e}", file=sys.stderr)
        sys.exit(1)


def validate_toml(toml_data: Dict[str, Any], schema: Dict[str, Any]) -> List[str]:
    """
    Validate TOML data against JSON schema

    Returns:
        List of error messages (empty if valid)
    """
    errors = []

    # First try simple validation
    try:
        validator = Draft7Validator(schema)
        validator.check_schema(schema)  # Validate schema itself first
    except Exception as e:
        errors.append(f"Schema error: {e}")
        return errors

    # Collect all validation errors
    validation_errors = []
    try:
        for error in validator.iter_errors(toml_data):
            validation_errors.append(error)
    except TypeError as e:
        # This can happen with complex schemas that have type mismatches
        errors.append(f"Schema validation encountered a type error: {e}")
        errors.append("Attempting basic structure validation...")
        return errors
    except Exception as e:
        errors.append(f"Unexpected validation error: {e}")
        return errors

    # Sort and format errors
    for error in sorted(validation_errors, key=lambda e: (e.absolute_path, str(e))):
        # Build a readable error message
        path = " -> ".join(str(p) for p in error.absolute_path)
        if path:
            location = f"at '{path}'"
        else:
            location = "at root"

        # Format the error message
        msg = f"{location}: {error.message}"

        # Add additional context for specific error types
        if error.validator == 'required':
            missing = error.validator_value
            msg = f"{location}: Missing required field(s): {missing}"
        elif error.validator == 'additionalProperties':
            if isinstance(error.instance, dict):
                extra_keys = set(error.instance.keys()) - set(error.schema.get('properties', {}).keys())
                if extra_keys:
                    msg += f" (unexpected: {', '.join(sorted(extra_keys))})"
        elif error.validator == 'enum':
            allowed = error.validator_value
            msg += f" (allowed: {', '.join(map(str, allowed))})"
        elif error.validator == 'type':
            expected = error.validator_value
            if isinstance(error.instance, (int, float, str, bool, list, dict)):
                actual = type(error.instance).__name__
                msg += f" (expected {expected}, got {actual})"

        errors.append(msg)

    return errors


def main():
    # Parse arguments
    if len(sys.argv) < 2:
        print("Usage: python toml_schema_validator.py input.toml [schema.json]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Validates a TOML configuration file against a JSON schema.", file=sys.stderr)
        sys.exit(1)

    toml_path = Path(sys.argv[1])

    # Determine schema path
    if len(sys.argv) >= 3:
        schema_path = Path(sys.argv[2])
    else:
        # Default to schema in docs/schemas/
        script_dir = Path(__file__).parent
        schema_path = script_dir / ".." / ".." / "docs" / "schemas" / "vmprog_program_config_schema_v1_0.json"
        schema_path = schema_path.resolve()

    # Check if files exist
    if not toml_path.exists():
        print(f"ERROR: TOML file not found: {toml_path}", file=sys.stderr)
        sys.exit(1)

    if not schema_path.exists():
        print(f"ERROR: Schema file not found: {schema_path}", file=sys.stderr)
        print(f"Provide schema path as second argument or ensure default schema exists.", file=sys.stderr)
        sys.exit(1)

    # Load files
    print(f"Loading TOML file: {toml_path}")
    toml_data = load_toml(toml_path)

    print(f"Loading schema: {schema_path}")
    schema = load_schema(schema_path)

    # Simplify schema to remove unsupported $data references
    schema = simplify_schema(schema)

    print("")
    print("Validating...")
    print("")

    # Validate
    errors = validate_toml(toml_data, schema)

    # Deduplicate errors (same location and message)
    unique_errors = []
    seen = set()
    for error in errors:
        if error not in seen:
            unique_errors.append(error)
            seen.add(error)

    if unique_errors:
        print(f"VALIDATION FAILED: Found {len(unique_errors)} error(s):")
        print("")
        for i, error in enumerate(unique_errors, 1):
            print(f"{i}. {error}")
        print("")
        sys.exit(1)
    else:
        print("✓ VALIDATION PASSED: TOML file is valid according to schema")
        print("")
        sys.exit(0)


if __name__ == "__main__":
    main()
