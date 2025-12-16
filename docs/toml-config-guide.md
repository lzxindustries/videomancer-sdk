# TOML Configuration Guide



Defines program metadata and parameter mappings for Videomancer FPGA programs.



## File Structure



```toml

[program]

program_id = "com.example.my_program"

program_name = "My Program"

program_version = "1.0.0"

abi_version = ">=1.0,<2.0"

author = "Your Name"           # Optional

license = "GPL-3.0"            # Optional

category = "Effects"           # Optional

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

[[parameter.value_label]]      # Label mode

value = 0

label = "Off"

[[parameter.value_label]]

value = 1

label = "On"

```



## Program Fields



**Required:**

- `program_id` (max 63 chars) - Unique identifier

- `program_name` (max 31 chars) - Display name

- `program_version` - SemVer format (e.g., "1.2.3")

- `abi_version` - Range notation (e.g., ">=1.0,<2.0")



**Optional:**

- `author`, `license`, `category` (max 31-63 chars)

- `description`, `url` (max 127 chars)



## Parameters



Up to 12 parameters. Each requires:

- `parameter_id` - Hardware control (see available controls below)

- `name_label` (max 31 chars) - Display name



**Available Controls:**

`rotary_potentiometer_1` through `6`, `toggle_switch_7` through `11`, `linear_potentiometer_12`



### Numeric Mode



**Control Modes:** `linear`, `linear_half`, `linear_quarter`, `linear_double`, `boolean`, `steps_4/8/16/32/64/128/256`, `polar_degs_90/180/360/720/1440/2880`, easing curves: `quad/sine/circ/quint/quart/expo` with `_in/_out/_in_out`



### Label Mode



Define `[[parameter.value_label]]` sections with `value` (0-1023) and `label` (max 31 chars). Up to 256 labels per parameter.



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



