# Videomancer SDK Test Suite



Comprehensive test suite for the Videomancer SDK C++ headers and Python tools.



## Test Summary



- **Total C++ Unit Tests**: 118 tests across 6 test suites

  - test_vmprog_crypto: 15 tests

  - test_videomancer_abi: 6 tests

  - test_vmprog_format: 41 tests

  - test_vmprog_stream_reader: 37 tests

  - test_vmprog_public_keys: 8 tests

  - test_videomancer_fpga_controller: 11 tests

- **VHDL Unit Tests**: 22 tests across 4 test suites

  - tb_sync_slv: 5 tests

  - tb_yuv422_to_yuv444: 7 tests

  - tb_yuv444_to_yuv422: 5 tests

  - tb_blanking_yuv444: 6 tests

- **Python Tests**: 2 test modules

- **Shell Tests**: 2 integration tests

- **Test Coverage**: All SDK C++ headers and core FPGA RTL modules are tested



## Test Organization



The test suite is organized by language and purpose:



```

tests/

├── cpp/                    # C++ unit tests for SDK headers

│   ├── test_vmprog_crypto.cpp

│   ├── test_videomancer_abi.cpp

│   ├── test_vmprog_format.cpp

│   ├── test_vmprog_stream_reader.cpp

│   ├── test_vmprog_public_keys.cpp

│   ├── test_videomancer_fpga_controller.cpp

│   └── CMakeLists.txt

├── vhdl/                   # VHDL unit tests for FPGA RTL modules

│   ├── run.py             # VUnit test runner

│   ├── tb_sync_slv.vhd

│   ├── tb_yuv422_to_yuv444.vhd

│   ├── tb_yuv444_to_yuv422.vhd

│   ├── tb_blanking_yuv444.vhd

│   └── README.md

├── python/                 # Python tool tests

│   ├── test_converter.py

│   └── test_ed25519_signing.py

├── shell/                  # Shell script integration tests

│   ├── test_conversion.sh

│   └── test_vmprog_pack.sh

└── run_tests.sh           # Master test runner script

```



## Running Tests



### Quick Start



Run all tests with a single command:



```bash

cd tests

./run_tests.sh

```



### C++ Unit Tests Only



Build and run C++ tests:



```bash

# From SDK root directory

./build_sdk.sh --test



# Or manually from build directory

cd build

ctest --output-on-failure

```



Run specific C++ test:



```bash

cd build/tests/cpp

./test_vmprog_crypto

./test_videomancer_abi

./test_vmprog_format

./test_vmprog_stream_reader

```



### Python Tests Only



```bash

cd tests

./run_tests.sh --python-only



# Or run individual tests

python3 python/test_converter.py

python3 python/test_ed25519_signing.py

```



### Shell Tests Only



```bash

cd tests

./run_tests.sh --shell-only



# OrVHDL Tests Only



```bash

cd tests

./run_tests.sh --vhdl-only



# Or run from vhdl directory

cd tests/vhdl

python3 run.py



# Run specific test

python3 run.py 'rtl_lib.tb_sync_slv.test_two_ff_delay'

```



###  run individual tests

bash shell/test_conversion.sh

bash shell/test_vmprog_pack.sh

```



### Advanced Options



```bash

# Verbose output

./run_tests.sh --verbose



# Build in debug mode with tests

cd ..

./build_sdk.sh --test --debug



# Run CTest with specific options

cd build

ctest --output-on-failure --verbose

ctest -R crypto  # Run only crypto tests

```



## Test Coverage



### C++ Header Tests



#### `test_vmprog_crypto.cpp`

Tests cryptographic functions from `vmprog_crypto.hpp`:

- SHA-256/BLAKE2b-256 hashing (initialization, incremental, one-shot)

- Ed25519 signature verification with RFC 8032 test vectors

- Constant-time memory comparison

- Secure memory wiping

- Hash determinism and large data handling

- Ed25519 corrupted signature rejection and API safety



**Note**: Uses standard Ed25519 (SHA-512) as specified in RFC 8032.



#### `test_videomancer_abi.cpp`

Tests ABI constants and enumerations from `videomancer_abi.hpp`:

- Register address validation

- Toggle switch bit positions and masks

- Video timing ID enumeration completeness

- Range validation for all constants



#### `test_vmprog_format.cpp`

Tests VMProg format structures from `vmprog_format.hpp`:

- Struct size and alignment verification

- Magic number validation

- Safe string copying with truncation

- Initialization functions for headers, TOC entries, configs

- Validation functions with invalid/valid data

- Enum value uniqueness and type sizes



#### `test_vmprog_stream_reader.cpp`

Tests stream-based reading from `vmprog_stream_reader.hpp`:

- Mock stream implementation

- Header reading and validation

- TOC entry reading with buffer size checks

- Payload data reading and verification

- Stream seeking and boundary conditions



#### `test_vmprog_public_keys.cpp`

Tests public key definitions from `vmprog_public_keys.hpp`:

- Public key array existence and size

- Ed25519 key size verification (32 bytes)

- Key data validation (non-zero, proper entropy)

- Array bounds and accessibility

- Constexpr compilation support

- Key copying and memory safety



#### `test_videomancer_fpga_controller.cpp`

Tests FPGA controller from `videomancer_fpga_controller.hpp`:

- Controller initialization and shadow registers

- Rotary potentiometer set/get operations (6 pots)

- Linear potentiometer control

- Toggle switch individual and bulk operations (5 switches)

- Video timing mode configuration

- Bulk update methods (set_all_rotary_pots, set_all_controls)

- Write optimization (no-op for unchanged values)

- Shadow register reset functionality

- SPI frame encoding and format validation

- Chip select assertion during transfers

- Value masking to 10-bit range



### Python Tool Tests



#### `test_converter.py`

Tests TOML to binary configuration conversion:

- TOML file parsing and validation

- Binary format generation

- Field encoding and struct packing



#### `test_ed25519_signing.py`

Tests Ed25519 signing tools:

- Key generation

- Package signing and verification

- Signature validation



### Shell Integration Tests



#### `test_conversion.sh`

End-to-end TOML conversion testing:

- Full conversion pipeline

- File output verification

- Error handling



#### `test_vmprog_pack.sh`

Package creation and signing:

- Complete package generation

- Signed package creation

- Package integrity verification



## Requirements



### C++ Tests

- CMake 3.13+

- C++20 compiler (C++17 on Windows)

- Monocypher library (included in third_party/)



### Python Tests

- Python 3.7+

- Required packages (auto-installed by setup.sh):

  - toml

  - jsonschema

  - pynacl (for Ed25519)



### Shell Tests

- Bash

- Standard Unix tools (grep, sed, diff)



## Test Development



### Adding New C++ Tests



1. Create test file in `tests/cpp/`:

```cpp

#include <lzx/videomancer/your_header.hpp>

#include <iostream>



bool test_your_function() {

    // Your test code

    return true;

}



int main() {

    int passed = 0;

    int total = 1;



    if (test_your_function()) passed++;



    return (passed == total) ? 0 : 1;

}

```



2. Add to `tests/cpp/CMakeLists.txt`:

```cmake

set(TEST_SOURCES

    ...

    test_your_feature.cpp

)

```



3. Rebuild and run:

```bash

./build_sdk.sh --test

```



### Adding Python Tests



1. Create test file in `tests/python/`:

```python

#!/usr/bin/env python3

import sys



def test_feature():

    # Your test code

    return True



if __name__ == "__main__":

    if test_feature():

        print("PASSED")

        sys.exit(0)

    else:

        print("FAILED")

        sys.exit(1)

```



2. Make executable:

```bash

chmod +x tests/python/test_your_feature.py

```



### Adding Shell Tests



1. Create test script in `tests/shell/`:

```bash

#!/bin/bash

set -e



# Your test code

echo "Test passed"

exit 0

```



2. Make executable:

```bash

chmod +x tests/shell/test_your_feature.sh

```



## Continuous Integration



Tests can be integrated into CI/CD pipelines:



```yaml

# Example GitHub Actions workflow

- name: Build and Test

  run: |

    ./build_sdk.sh --test



- name: Run All Tests

  run: |

    cd tests

    ./run_tests.sh

```



## Debugging Failed Tests



### C++ Test Failures



1. Build in debug mode:

```bash

./build_sdk.sh --test --debug

```



2. Run test with debugger:

```bash

cd build/tests/cpp

gdb ./test_vmprog_crypto

```



3. Run with verbose CTest output:

```bash

cd build

ctest --output-on-failure --verbose

```



### Python Test Failures



Run with Python debugger:

```bash

python3 -m pdb tests/python/test_converter.py

```



### Shell Test Failures



Run with bash debugging:

```bash

bash -x tests/shell/test_conversion.sh

```



## Test Maintenance



- Update tests when modifying SDK headers

- Ensure test coverage for new features

- Run full test suite before commits

- Keep test data minimal but comprehensive

- Document test assumptions and requirements



## Support



For issues or questions about tests:

- Check test output for specific failure details

- Review test source code for expected behavior

- See main SDK documentation for API details

- Report test failures as issues with:

  - Full test output

  - SDK version

  - Platform information

  - Steps to reproduce



---



**Copyright (C) 2025 LZX Industries LLC**

Licensed under GPL-3.0-only

