# TOML to Binary Converter

Converts Videomancer program configuration TOML files to the binary format required by the SDK.

## Usage

```bash

python toml_to_config_binary.py <input.toml> <output.bin> [--quiet]

```

### Arguments

- `input.toml` - Path to your TOML configuration file

- `output.bin` - Path for the generated binary output

- `--quiet` - (Optional) Suppress informational output

### Examples

```bash

# Basic conversion

python toml_to_config_binary.py my_program.toml program_config.bin

# Quiet mode (for build scripts)

python toml_to_config_binary.py my_program.toml program_config.bin --quiet

```

## Output Format

The converter generates a fixed-size 7372-byte binary file containing:

- Program metadata (strings with null padding)

- Parameter configurations

- Version information

- All fields validated and formatted per the specification

## Validation

The converter performs comprehensive validation:

- **Schema validation** - All required fields, correct data types

- **Range checks** - Numeric values within allowed bounds

- **Enum validation** - Parameter IDs and control modes are valid

- **String lengths** - All strings within maximum character limits

- **ABI compatibility** - Version ranges are valid

- **Parameter modes** - Label vs numeric mode consistency

- **Cross-field validation** - Related fields are compatible

If validation fails, the converter will:

1. Print detailed error messages with field paths

2. Exit with non-zero status code

3. Not create the output file

## Features

- **Automatic calculations** - Parameter count derived from TOML structure

- **Default values** - Optional fields get appropriate defaults

- **Null padding** - Strings properly padded to fixed widths

- **Binary packing** - Efficient C-compatible struct layout

- **Error reporting** - Clear, actionable error messages

## Integration with Build Scripts

The converter is designed for integration into automated build pipelines:

```bash

#!/bin/bash

# Example build integration

# Convert TOML to binary

python tools/toml-converter/toml_to_config_binary.py \

    programs/myprogram/config.toml \

    build/myprogram/program_config.bin --quiet

# Check exit code

if [ $? -ne 0 ]; then

    echo "ERROR: TOML conversion failed"

    exit 1

fi

echo "✓ Binary config generated successfully"

```

## Dependencies

Requires Python 3.7+ with TOML parsing library:

```bash

# Install tomli for Python < 3.11

pip3 install tomli

# Python 3.11+ has built-in tomllib

```

## Output File Usage

The generated `program_config.bin` file is typically used in two contexts:

1. **Development** - Direct testing with hardware/emulator

2. **Packaging** - Bundled into `.vmprog` packages via `vmprog_pack.py`

See [TOML Configuration Guide](../../docs/toml-config-guide.md) for details on the TOML format.

## Related Tools

- [TOML Editor](../toml-editor/README.md) - Visual editor with live validation

- [TOML Validator](../toml-validator/README.md) - Schema validation without conversion

- [VMPROG Packer](../vmprog-packer/README.md) - Package creation tool

## Troubleshooting

**Import Error:**

```

Error: No TOML library found

```

Solution: `pip3 install tomli`

**Validation Error:**

```

Error: String too long at program.program_name

```

Solution: Shorten the field value to meet the character limit

**File Not Found:**

```

Error: Could not read TOML file

```

Solution: Check the input file path is correct and file exists

