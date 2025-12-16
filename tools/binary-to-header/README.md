# Binary to C++ Header/Source Generator

This tool converts binary files into C++ header and source files, embedding the binary data as a `const uint8_t` array.

## Features

- Converts any binary file to C++ code
- Uses external template files for easy customization
- Generates both header (.h) and source (.cpp) files
- Supports custom variable names
- Optional C++ namespace support
- Configurable template files

## Usage

### Basic Usage

```bash
python3 binary-to-header.py -i input.bin -o output.h -s output.cpp
```

### With Custom Name

```bash
python3 binary-to-header.py -i firmware.bin -o firmware.h -s firmware.cpp --name my_firmware
```

### With Namespace

```bash
python3 binary-to-header.py -i data.bin -o data.h -s data.cpp --namespace embedded
```

### With Custom Templates

```bash
python3 binary-to-header.py -i file.bin -o file.h -s file.cpp \
    --header-template custom_header.template \
    --source-template custom_source.template
```

## Command Line Options

- `-i, --input`: Input binary file path (required)
- `-o, --output-header`: Output header file path (required)
- `-s, --output-source`: Output source file path (required)
- `-n, --name`: Variable name (default: derived from input filename)
- `--header-template`: Path to custom header template file
- `--source-template`: Path to custom source template file
- `--namespace`: C++ namespace to use (optional)
- `-v, --verbose`: Enable verbose output

## Template Variables

The following variables are available in template files:

- `{{HEADER_GUARD}}`: Include guard macro name
- `{{VAR_NAME}}`: Variable name for the data array
- `{{DATA_SIZE}}`: Size of the binary data in bytes
- `{{HEADER_FILENAME}}`: Name of the generated header file
- `{{BINARY_DATA}}`: Formatted binary data array
- `{{NAMESPACE}}`: Namespace name (if provided)
- `{{NAMESPACE_BEGIN}}`: Namespace opening (empty if no namespace)
- `{{NAMESPACE_END}}`: Namespace closing (empty if no namespace)

## Generated Code Example

For an input file `firmware.bin` (100 bytes), the tool generates:

**firmware.h:**
```cpp
#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <cstdint>
#include <cstddef>

extern const uint8_t firmware_data[];
extern const size_t firmware_size;

#endif // FIRMWARE_H
```

**firmware.cpp:**
```cpp
#include "firmware.h"

const uint8_t firmware_data[] = {
    0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x3E, 0x00, 0x01, 0x00, 0x00, 0x00,
    // ... more data ...
};

const size_t firmware_size = 100;
```

## Customizing Templates

You can create custom template files to change the output format. Templates use `{{VARIABLE}}` syntax for substitution.

Example custom header template:
```cpp
#pragma once

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

extern const uint8_t {{VAR_NAME}}_data[];
extern const size_t {{VAR_NAME}}_size;

#ifdef __cplusplus
}
#endif
```

## Integration Example

Using the generated code in your C++ project:

```cpp
#include "firmware.h"
#include <iostream>

int main() {
    std::cout << "Firmware size: " << firmware_size << " bytes" << std::endl;
    
    // Access the data
    for (size_t i = 0; i < firmware_size; ++i) {
        // Process firmware_data[i]
    }
    
    return 0;
}
```

## License

This tool is part of the Videomancer SDK project.
