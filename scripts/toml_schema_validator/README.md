# TOML Schema Validator

Validates Videomancer program configuration TOML files against the JSON schema specification.

## Usage

```bash
# Validate using default schema
python toml_schema_validator.py <input.toml>

# Validate using custom schema
python toml_schema_validator.py <input.toml> <schema.json>
```

## Examples

```bash
# Validate the example program config
python toml_schema_validator.py ../../scripts/toml_to_config_binary/example_program_config.toml

# Validate with explicit schema path
python toml_schema_validator.py my_program.toml ../../docs/schemas/vmprog_program_config_schema_v1_0.json
```

## Default Schema

If no schema is provided, the validator uses:
```
../../docs/schemas/vmprog_program_config_schema_v1_0.json
```

## Requirements

- Python 3.7 or later
- `jsonschema` library: `pip install jsonschema`
- TOML library (built-in for Python 3.11+, or install `tomli` for earlier versions)

## Output

- **Success**: Prints `✓ VALIDATION PASSED` and exits with code 0
- **Failure**: Prints all validation errors and exits with code 1

## Error Reporting

The validator provides detailed error messages including:
- Location in the TOML file (e.g., `at 'program -> parameter_count'`)
- Description of the validation error
- Expected values for enum fields
- Missing required fields

## Notes

The validator simplifies complex schema validations (such as cross-field comparisons using `$data` references) that aren't supported by the standard `jsonschema` library. These advanced validations should be checked by the `toml_to_config_binary.py` converter during actual binary generation.
