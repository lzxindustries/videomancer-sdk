# VHDL Tests



VUnit-based testbenches for Videomancer FPGA RTL modules using GHDL simulator.



## Overview



This directory contains VHDL unit tests for the core FPGA modules. Tests are written using the [VUnit](https://vunit.github.io/) framework and simulated with [GHDL](https://github.com/ghdl/ghdl).



## Test Modules



### tb_sync_slv.vhd

Tests the `sync_slv` clock domain synchronizer module.



**Test Cases:**

- `test_sync_zeros` - Synchronization of zero value

- `test_sync_value` - Synchronization of non-zero value

- `test_value_changes` - Multiple value transitions

- `test_two_ff_delay` - Verify 2-FF delay for metastability protection

- `test_all_bits` - All bits can transition independently



### tb_yuv422_to_yuv444.vhd

Tests the `yuv422_to_yuv444` video format converter.



**Test Cases:**

- `test_basic_conversion` - Basic YUV422 to YUV444 pixel conversion

- `test_sync_delay` - Sync signal propagation with correct 2-cycle delay

- `test_avid_phase_reset` - AVID rising edge resets chroma phase

- `test_black_level` - Black level (Y=16, U=128, V=128) conversion

- `test_white_level` - White level (Y=235, U=128, V=128) conversion

- `test_field_propagation` - Field signal propagates correctly

- `test_continuous_stream` - Continuous pixel stream processing



### tb_yuv444_to_yuv422.vhd

Tests the `yuv444_to_yuv422` video format converter.



**Test Cases:**

- `test_basic_conversion` - Basic YUV444 to YUV422 pixel conversion

- `test_sync_delay` - Sync signal propagation timing

- `test_phase_reset` - Phase reset on AVID rising edge

- `test_chroma_alternation` - Chroma sample alternation

- `test_field_propagation` - Field signal propagates correctly



### tb_blanking_yuv444.vhd

Tests the `blanking_yuv444` video blanking module.



**Test Cases:**

- `test_active_video_passthrough` - Active video passes through unchanged

- `test_blanking_replacement` - Blanking pixels replaced with blanking level

- `test_sync_passthrough` - Sync signals pass through unchanged

- `test_transition_to_blanking` - Transition from active to blanking

- `test_transition_to_active` - Transition from blanking to active

- `test_continuous_blanking` - Continuous blanking period handling



## Prerequisites



Install VUnit and GHDL:



```bash

# Install GHDL (if not already installed via oss-cad-suite)

sudo apt-get install ghdl



# Install VUnit via pip

# On Ubuntu 24.04+, use --break-system-packages flag:

pip3 install --break-system-packages vunit-hdl



# Or use a virtual environment (recommended):

python3 -m venv venv

source venv/bin/activate

pip install vunit-hdl

```



**Note:** If you've run `scripts/setup.sh`, GHDL is already available in `build/oss-cad-suite/bin/`.



**Ubuntu 24.04+ Note:** Python environments are externally managed (PEP 668). The scripts will attempt to install VUnit automatically, or you can install manually with the commands above.



## Running Tests



### Run All VHDL Tests



From the `tests/vhdl` directory:



```bash

python3 run.py

```



### Run Specific Test Suite



```bash

# Run only sync_slv tests

python3 run.py 'rtl_lib.tb_sync_slv.*'



# Run only yuv422_to_yuv444 tests

python3 run.py 'rtl_lib.tb_yuv422_to_yuv444.*'



# Run only yuv444_to_yuv422 tests

python3 run.py 'rtl_lib.tb_yuv444_to_yuv422.*'



# Run only blanking_yuv444 tests

python3 run.py 'rtl_lib.tb_blanking_yuv444.*'

```



### Run Specific Test Case



```bash

# Run a single test case

python3 run.py 'rtl_lib.tb_sync_slv.test_two_ff_delay'

python3 run.py 'rtl_lib.tb_yuv422_to_yuv444.test_basic_conversion'

python3 run.py 'rtl_lib.tb_yuv444_to_yuv422.test_basic_conversion'

python3 run.py 'rtl_lib.tb_blanking_yuv444.test_active_video_passthrough'

```



### Verbose Output



```bash

python3 run.py -v

```



### GUI Waveform Viewing



Generate waveform files for debugging:



```bash

python3 run.py --gtkwave-fmt=vcd

```



Then open with GTKWave:



```bash

gtkwave vunit_out/ghdl/rtl_lib.tb_sync_slv.test_two_ff_delay_xxx/wave.vcd

```



## VUnit Features Used



- **Test runner context** - Provides `test_runner_setup`, `test_runner_cleanup`, etc.

- **Check library** - `check_equal`, `check_not_equal` for assertions

- **Info/error logging** - `info()`, `error()`, `warning()` for test reporting

- **Test watchdog** - Automatic timeout to prevent infinite simulations



## Adding New Tests



1. Create a new testbench file: `tb_<module_name>.vhd`

2. Use the VUnit context and follow the existing pattern:

   ```vhdl

   library vunit_lib;

   context vunit_lib.vunit_context;



   entity tb_<module_name> is

     generic (runner_cfg : string);

   end entity;

   ```

3. Add test cases in the `while test_suite loop`

4. The test will be automatically discovered by VUnit



## Integration



VHDL tests are integrated into:

- **Master test runner**: `tests/run_tests.sh --vhdl-only`

- **GitHub CI workflow**: Runs on every push and PR

- **Build system**: Optional verification step during FPGA builds



## Coverage



Current coverage:

- ✅ Clock domain synchronizer (`sync_slv`)

- ✅ YUV422 to YUV444 converter (`yuv422_to_yuv444`)

- ✅ YUV444 to YUV422 converter (`yuv444_to_yuv422`)

- ✅ Blanking module (`blanking_yuv444`)

- 🔲 SPI peripheral controller (`spi_peripheral`)

- 🔲 Video sync generator (`video_sync_generator`)

- 🔲 Video field detector (`video_field_detector`)



## Resources



- [VUnit Documentation](https://vunit.github.io/)

- [VUnit User Guide](https://vunit.github.io/user_guide.html)

- [GHDL Documentation](https://ghdl.github.io/ghdl/)

