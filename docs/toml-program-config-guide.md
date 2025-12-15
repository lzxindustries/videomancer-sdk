# Videomancer Program Configuration Guide

This guide explains how to create TOML configuration files for Videomancer programs. These files define program metadata and parameter mappings that control how your FPGA program interacts with hardware controls.

## File Structure

A program configuration file consists of two main sections:

```toml
[program]
# Program metadata goes here

[[parameter]]
# First parameter configuration

[[parameter]]
# Second parameter configuration
# ... up to 12 parameters total
```

## Program Section

The `[program]` section contains metadata about your program. All fields use strings with maximum lengths specified below.

### Required Fields

**program_id** (max 63 characters)  
Unique identifier for your program using reverse DNS notation or a similar naming convention.

```toml
program_id = "com.lzxindustries.example.waveform_generator"
```

**program_name** (max 31 characters)  
Human-readable name displayed to users.

```toml
program_name = "Waveform Generator"
```

**program_version** (SemVer format)  
Version number in semantic versioning format: `major.minor.patch`

```toml
program_version = "1.2.3"
```

**abi_version** (range notation)  
Specifies which ABI versions your program is compatible with using range notation: `>=min_version,<max_version`

```toml
abi_version = ">=1.0,<2.0"  # Compatible with ABI 1.x
```

### Optional Fields

All optional fields default to empty strings if not specified.

**author** (max 63 characters)  
Name of the program author or organization.

```toml
author = "LZX Industries LLC"
```

**license** (max 31 characters)  
License identifier, preferably in SPDX format.

```toml
license = "GPL-3.0"
license = "MIT"
license = "Proprietary"
```

**category** (max 31 characters)  
Category for organizing programs.

```toml
category = "Signal Generation"
```

**description** (max 127 characters)  
Detailed description of what the program does.

```toml
description = "A versatile waveform generator with multiple controls."
```

**url** (max 127 characters)  
Project or documentation URL (http/https).

```toml
url = "https://github.com/lzxindustries/videomancer-sdk"
```

## Parameters

Parameters map physical hardware controls to your program's functionality. You can define up to 12 parameters using `[[parameter]]` sections. Each parameter must specify which hardware control it uses and how values are interpreted.

### Parameter Modes

Parameters operate in one of two modes:

1. **Numeric Mode**: Continuous or discrete numeric values with scaling and display options
2. **Label Mode**: Predefined text labels for discrete positions

### Required Fields (All Parameters)

**parameter_id**  
Hardware control assignment. Each parameter must use a unique control.

Available controls:
- `rotary_potentiometer_1` through `rotary_potentiometer_6`
- `toggle_switch_7` through `toggle_switch_11`
- `linear_potentiometer_12`

```toml
parameter_id = "rotary_potentiometer_1"
```

**name_label** (max 31 characters)  
Display name for the parameter.

```toml
name_label = "Frequency"
```

### Numeric Mode

Use numeric mode for parameters with continuous or stepped numeric values. When using numeric mode, you must specify `control_mode`.

**control_mode** (required for numeric mode)  
Defines how the hardware value is interpreted and scaled. Available modes:

*Linear scaling:*
- `linear` - Direct 1:1 mapping
- `linear_half` - Half speed scaling
- `linear_quarter` - Quarter speed scaling
- `linear_double` - Double speed scaling

*Discrete steps:*
- `boolean` - Two-state on/off
- `steps_4`, `steps_8`, `steps_16`, `steps_32`, `steps_64`, `steps_128`, `steps_256`

*Angular/polar:*
- `polar_degs_90`, `polar_degs_180`, `polar_degs_360`, `polar_degs_720`, `polar_degs_1440`, `polar_degs_2880`

*Easing curves:*
- `quad_in`, `quad_out`, `quad_in_out`
- `sine_in`, `sine_out`, `sine_in_out`
- `circ_in`, `circ_out`, `circ_in_out`
- `quint_in`, `quint_out`, `quint_in_out`
- `quart_in`, `quart_out`, `quart_in_out`
- `expo_in`, `expo_out`, `expo_in_out`

```toml
control_mode = "linear"
```

#### Optional Numeric Fields

**min_value** (0-1023, default: 0)  
Minimum hardware value the parameter will use.

**max_value** (0-1023, default: 1023)  
Maximum hardware value the parameter will use. Must be greater than `min_value`.

**initial_value** (0-1023, default: 512)  
Default value when the program starts. Must be between `min_value` and `max_value`.

```toml
min_value = 100
max_value = 900
initial_value = 500
```

**display_min_value** (-32768 to 32767, default: same as min_value)  
Minimum value shown in the user interface. Allows scaling for display purposes.

**display_max_value** (-32768 to 32767, default: same as max_value)  
Maximum value shown in the user interface.

```toml
# Hardware uses 0-1023, but display shows 0-100
min_value = 0
max_value = 1023
display_min_value = 0
display_max_value = 100
```

**display_float_digits** (0-255, default: 0)  
Number of decimal places to show when displaying values.

```toml
display_float_digits = 1  # Shows values like 12.3
display_float_digits = 2  # Shows values like 12.34
```

**suffix_label** (max 3 characters)  
Unit suffix displayed after the value.

```toml
suffix_label = "Hz"   # Frequency
suffix_label = "%"    # Percentage
suffix_label = "°"    # Degrees
suffix_label = "dB"   # Decibels
```

#### Complete Numeric Example

```toml
[[parameter]]
parameter_id = "rotary_potentiometer_1"
control_mode = "linear"
name_label = "Frequency"
min_value = 0
max_value = 1023
initial_value = 512
display_min_value = 20
display_max_value = 20000
display_float_digits = 1
suffix_label = "Hz"
```

### Label Mode

Use label mode for parameters with discrete, named positions. This mode is mutually exclusive with numeric mode fields.

**value_labels** (2-16 labels, max 31 characters each)  
Array of text labels for discrete parameter positions. The hardware range is automatically divided evenly across the labels.

```toml
value_labels = ["Off", "Low", "Medium", "High"]
value_labels = ["Sine", "Triangle", "Sawtooth", "Square"]
```

**initial_value_label** (optional)  
Specifies which label should be the default. Must exactly match one of the strings in `value_labels`.

```toml
value_labels = ["Sine", "Triangle", "Sawtooth", "Square"]
initial_value_label = "Sine"
```

#### Complete Label Example

```toml
[[parameter]]
parameter_id = "rotary_potentiometer_3"
name_label = "Waveform"
value_labels = ["Sine", "Triangle", "Sawtooth", "Square"]
initial_value_label = "Sine"
```

## Important Constraints

### Parameter Mode Rules

- **Cannot mix modes**: If you use `value_labels`, you cannot use numeric mode fields (`min_value`, `max_value`, `initial_value`, `display_min_value`, `display_max_value`, `suffix_label`, `display_float_digits`, `control_mode`)
- **Numeric mode requires control_mode**: If you don't use `value_labels`, you must specify `control_mode`

### Hardware Limits

- Maximum 12 parameters per program
- Each parameter must use a unique `parameter_id` (no duplicate hardware assignments)
- Hardware values range from 0 to 1023 (10-bit resolution)

### Value Ranges

- `min_value` must be less than `max_value`
- `initial_value` must be between `min_value` and `max_value` (inclusive)
- Display values can be negative (range: -32768 to 32767) for signed display purposes

## Complete Example

```toml
[program]
program_id = "com.example.video.colorizer"
program_name = "Color Processor"
program_version = "1.0.0"
abi_version = ">=1.0,<2.0"
author = "Jane Doe"
license = "MIT"
category = "Video Processing"
description = "Advanced color processing with hue, saturation, and brightness controls."
url = "https://github.com/example/colorizer"

# Hue control with full range
[[parameter]]
parameter_id = "rotary_potentiometer_1"
control_mode = "polar_degs_360"
name_label = "Hue"
suffix_label = "°"

# Saturation control (0-100%)
[[parameter]]
parameter_id = "rotary_potentiometer_2"
control_mode = "linear"
name_label = "Saturation"
min_value = 0
max_value = 1023
initial_value = 512
display_min_value = 0
display_max_value = 100
suffix_label = "%"

# Brightness with quadratic easing
[[parameter]]
parameter_id = "rotary_potentiometer_3"
control_mode = "quad_in_out"
name_label = "Brightness"
display_min_value = -100
display_max_value = 100

# Mode selector with discrete options
[[parameter]]
parameter_id = "rotary_potentiometer_4"
name_label = "Color Mode"
value_labels = ["Normal", "Vibrant", "Pastel", "Monochrome"]
initial_value_label = "Normal"
```

## Validation and Conversion

After creating your TOML file, validate it using the schema validator:

```bash
python3 toml_schema_validator.py your_program.toml
```

Convert it to binary format for use with the SDK:

```bash
python3 toml_to_config_binary.py your_program.toml output.bin
```

The converter automatically:
- Calculates parameter count from the number of `[[parameter]]` sections
- Applies default values for optional fields
- Validates all constraints and ranges
- Generates a 7368-byte binary file in the required format

## Tips

1. **Start simple**: Begin with basic numeric parameters using `linear` control mode, then explore other modes
2. **Test thoroughly**: Use the validator to catch errors before converting to binary
3. **Use meaningful names**: Choose descriptive `name_label` values that users will understand
4. **Consider display scaling**: Use `display_min_value` and `display_max_value` to show user-friendly ranges while maintaining full hardware resolution
5. **Label mode for discrete choices**: When parameters have distinct states (waveforms, modes, etc.), use `value_labels` instead of numeric mode
6. **Keep descriptions concise**: The 127-character limit for descriptions requires clear, focused text
