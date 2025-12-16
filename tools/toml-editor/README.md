# TOML Configuration Editor



Visual editor for Videomancer program configuration TOML files with live validation and an intuitive form-based interface.



## Features



- **Visual Form Interface** - Edit all configuration fields through an easy-to-use UI

- **Live Validation** - See errors and warnings in real-time as you type

- **Offline Capable** - All dependencies embedded, works without internet

- **Syntax Highlighting** - View and edit raw TOML with ACE editor integration

- **Import/Export** - Load existing TOML files or export your configuration

- **Schema Enforcement** - Automatically validates all rules and constraints



## Usage



Open the editor directly in your web browser:



```bash

# From the SDK root directory

open tools/toml-editor/toml-editor.html



# Or on Linux:

xdg-open tools/toml-editor/toml-editor.html



# Or on Windows:

start tools/toml-editor/toml-editor.html

```



The editor works entirely offline - no internet connection required after initial loading.



## Interface



### Navigation Sections



- **Program** - Edit main program metadata (name, version, author, etc.)

- **Parameters** - Configure up to 12 hardware control parameters

- **Raw TOML** - View and edit the raw TOML text with syntax highlighting

- **Help** - View usage guide and embedded example



### Real-Time Feedback



The editor provides instant validation feedback:



- **Required fields** - Marked with asterisks (*)

- **String lengths** - Shows character limits (e.g., "max 63")

- **Validation errors** - Red error boxes with specific field paths

- **Warnings** - Yellow warning boxes for potential issues (e.g., duplicate IDs)

- **Status indicator** - Green dot = Valid, Red = Errors, Yellow = Warnings



### Parameter Modes



Each parameter must use exactly one mode:



**Label Mode** - For discrete options:

- Define a list of text labels (e.g., "Sine", "Square", "Triangle")

- Users select from the list

- Best for mode selectors, waveform types, etc.



**Numeric Mode** - For continuous ranges:

- Specify min/max values and control curve

- Optional display scaling and suffix labels

- Best for frequency, amplitude, brightness, etc.



## Workflow



1. **Start with example** - Click "Reset to Example" to load a template

2. **Edit Program fields** - Fill in your program metadata

3. **Add Parameters** - Click "Add Parameter" and configure each control

4. **Validate** - Check the validation panel for any errors

5. **Export** - Click "Export TOML" to save your configuration



## Tips



- **No focus loss** - Type freely in text fields without losing cursor position

- **Dropdown visibility** - All select options clearly visible in light theme

- **Auto-save state** - Browser may preserve your work between sessions

- **Copy TOML** - Use "Copy TOML" button for quick clipboard access

- **Import existing** - Use "Import TOML" to load and modify existing files



## Technical Details



- **No installation required** - Single HTML file with embedded dependencies

- **Embedded libraries:**

  - AJV 6.12.6 (JSON Schema validation)

  - ACE Editor 1.32.6 (syntax highlighting)

  - TOML parser (ESM import for parsing)

- **File size** - ~600KB (includes ~565KB of minified libraries)

- **Browser compatibility** - Modern browsers (Chrome, Firefox, Safari, Edge)

- **Schema version** - vmprog_program_config_v1_0



## Related Documentation



- [TOML Configuration Guide](../../docs/toml-config-guide.md) - Complete field reference

- [TOML Validator](../toml-validator/README.md) - Command-line validation tool

- [TOML Converter](../toml-converter/) - Binary conversion utility



## Development



The editor is designed as a standalone, self-contained tool. To modify:



1. Edit `toml-editor.html` directly

2. Test by opening in a browser

3. All JavaScript, CSS, and dependencies are inline



No build process or compilation required.

