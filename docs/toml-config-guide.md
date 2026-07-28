# TOML Configuration Guide

Defines program metadata and parameter mappings for Videomancer FPGA programs.

## File Structure

```toml
[program]
program_id = "com.example.my_program"
program_name = "My Program"
program_version = "1.0.0"
abi_version = ">=1.0,<2.0"
hardware_compatibility = ["rev_b"]
core = "yuv444_30b"           # Optional: yuv444_30b | yuv422_20b | gbr444_30b | gbr422_20b
author = "Your Name"           # Optional
license = "GPL-3.0"            # Optional
categories = ["Color"]          # Optional — see program-categories.md
program_type = "processing"    # Required — "processing" or "synthesis"
description = "Description"   # Optional
url = "https://example.com"   # Optional

[[parameter]]
parameter_id = "rotary_potentiometer_1"
name_label = "Frequency"
control_mode = "linear"        # Numeric mode
min_value = 0                  # Optional, default 0
max_value = 1023               # Optional, default 1023
initial_value = 512            # Optional, default 512

[[parameter]]
parameter_id = "toggle_switch_7"
name_label = "Mode"
value_labels = ["Off", "On"]
initial_value_label = "Off"
```

## Program Fields

**Required:**
- `program_id` (max 63 chars) - Unique identifier
- `program_name` (max 31 chars) - Display name
- `program_version` - SemVer format (e.g., "1.2.3")
- `abi_version` - Range notation (e.g., ">=1.0,<2.0")
- `hardware_compatibility` - Array of compatible platforms (e.g., ["rev_b"])
- `program_type` - `"processing"` (transforms input video) or `"synthesis"` (generates output without input)

**Optional:**
- `core` - Core architecture: `"yuv444_30b"` (default), `"yuv422_20b"`, `"gbr444_30b"`, or `"gbr422_20b"`
- `author`, `license` (max 31-63 chars)
- `categories` - Array of up to 8 [predefined categories](program-categories.md) (max 31 chars each)
- `description`, `url` (max 127 chars)
- `supported_timings` - Array of video timing IDs the program supports (see below)

### Supported Timings

The optional `supported_timings` field declares which video timing modes the
program is compatible with. When omitted, the program is assumed to work with
all 15 timing modes (the default for most programs).

```toml
[program]
# ... required fields ...
supported_timings = ["ntsc", "pal", "480p", "576p"]
```

The firmware checks this field before loading a program. If the currently
active video standard is not in the program's supported list, the firmware
will reject the load with a `timing_not_supported` error.

**Available timing names:**

| Name | Standard | Resolution | Frame Rate | Type |
|------|----------|------------|------------|------|
| `ntsc` | NTSC | 720×486 | 59.94 Hz | SD interlaced |
| `pal` | PAL | 720×576 | 50 Hz | SD interlaced |
| `480p` | 480p | 720×480 | 59.94 Hz | SD progressive |
| `576p` | 576p | 720×576 | 50 Hz | SD progressive |
| `720p50` | 720p | 1280×720 | 50 Hz | HD progressive |
| `720p5994` | 720p | 1280×720 | 59.94 Hz | HD progressive |
| `720p60` | 720p | 1280×720 | 60 Hz | HD progressive |
| `1080i50` | 1080i | 1920×1080 | 50 Hz | HD interlaced |
| `1080i5994` | 1080i | 1920×1080 | 59.94 Hz | HD interlaced |
| `1080i60` | 1080i | 1920×1080 | 60 Hz | HD interlaced |
| `1080p2398` | 1080p | 1920×1080 | 23.98 Hz | HD progressive |
| `1080p24` | 1080p | 1920×1080 | 24 Hz | HD progressive |
| `1080p25` | 1080p | 1920×1080 | 25 Hz | HD progressive |
| `1080p2997` | 1080p | 1920×1080 | 29.97 Hz | HD progressive |
| `1080p30` | 1080p | 1920×1080 | 30 Hz | HD progressive |

**Common patterns:**

```toml
# SD-only program (e.g., uses BRAM-based delay that fits only SD line widths)
supported_timings = ["ntsc", "pal", "480p", "576p"]

# HD-only program
supported_timings = [
    "720p50", "720p5994", "720p60",
    "1080i50", "1080i5994", "1080i60",
    "1080p2398", "1080p24", "1080p25", "1080p2997", "1080p30"
]

# Omit field entirely for programs that work at any resolution (most programs)
# supported_timings = [...]  -- not needed
```

**Validation rules:**
- Each entry must be one of the 15 valid timing names listed above
- No duplicates allowed
- An empty array `[]` is treated the same as omitting the field (all timings supported)

**Hardware Platforms:**
- `rev_a` - Videomancer Core Rev A hardware
- `rev_b` - Videomancer Core Rev B hardware

## Parameters

Up to 12 parameters. Each requires:
- `parameter_id` - Hardware control (see available controls below)
- `name_label` (max 31 chars) - Display name

**Available Controls:**
`rotary_potentiometer_1` through `6`, `toggle_switch_7` through `11`, `linear_potentiometer_12`

### Numeric Mode

**Control Modes:** `linear`, `linear_half`, `linear_quarter`, `linear_double`, `boolean`, `steps_4/8/16/32/64/128/256`, `polar_degs_90/180/360/720/1440/2880`, easing curves: `quad/sine/circ/quint/quart/expo` with `_in/_out/_in_out`

### Label Mode

Use a `value_labels` array of strings (2–16 labels, max 31 characters each). The hardware range is divided evenly across labels. Mutually exclusive with numeric mode fields.

## Tools

**Visual Editor:**
```bash
open tools/toml-editor/toml-editor.html
```

**Command-Line:**
```bash
# Validate
cd tools/toml-validator
python3 toml_schema_validator.py your_program.toml

# Convert to binary
cd tools/toml-converter
python3 toml_to_config_binary.py your_program.toml output.bin
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
categories = ["Color"]
program_type = "processing"
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

### Visual Editor (Recommended)

The easiest way to create and validate TOML configuration files is using the **TOML Editor** web application:

```bash
# Open the editor in your browser (from the SDK root directory)
open tools/toml-editor/toml-editor.html
# or on Linux:
xdg-open tools/toml-editor/toml-editor.html
```

**Features:**
- **Live validation** - Errors and warnings appear as you type
- **Visual form interface** - Edit all fields through an intuitive UI
- **Import/Export** - Load existing TOML files or export your configuration
- **Offline capable** - Works without internet connection (all dependencies embedded)
- **Syntax highlighting** - View and edit raw TOML with syntax highlighting
- **Schema-aware** - Automatically enforces all validation rules and constraints

The editor provides instant feedback on:
- Required fields and data types
- String length limits (with character counts)
- Numeric ranges and control modes
- Parameter mode conflicts (label vs numeric)
- Duplicate parameter IDs
- ABI version compatibility

### Command-Line Tools

For automated workflows or CI/CD integration, use the command-line tools:

**Validate a TOML file:**

```bash
cd tools/toml-validator
python3 toml_schema_validator.py your_program.toml
```

**Convert to binary format:**

```bash
cd tools/toml-converter
python3 toml_to_config_binary.py your_program.toml output.bin
```

