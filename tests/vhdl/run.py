#!/usr/bin/env python3
"""
Videomancer SDK - VUnit VHDL Test Runner
Copyright (C) 2025 LZX Industries LLC
SPDX-License-Identifier: GPL-3.0-only

VUnit test runner for VHDL RTL modules.
"""

import sys
from pathlib import Path
from vunit import VUnit

# Create VUnit instance
vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()
# Note: Verification components disabled due to OSVVM compatibility with GHDL
# vu.add_verification_components()

# Get project root directory
project_root = Path(__file__).parent.parent.parent
rtl_dir = project_root / "fpga" / "rtl"
test_dir = Path(__file__).parent

# Add RTL source library
rtl_lib = vu.add_library("rtl_lib")
rtl_lib.add_source_files(rtl_dir / "core_pkg.vhd")
rtl_lib.add_source_files(rtl_dir / "video_timing_pkg.vhd")
rtl_lib.add_source_files(rtl_dir / "sync_slv.vhd")
rtl_lib.add_source_files(rtl_dir / "yuv422_to_yuv444.vhd")
rtl_lib.add_source_files(rtl_dir / "yuv444_to_yuv422.vhd")
rtl_lib.add_source_files(rtl_dir / "video_sync_generator.vhd")
rtl_lib.add_source_files(rtl_dir / "video_field_detector.vhd")
rtl_lib.add_source_files(rtl_dir / "blanking_yuv444.vhd")

# Add test library
test_lib = vu.add_library("test_lib")
test_lib.add_source_files(test_dir / "tb_*.vhd")

# Main entry point
if __name__ == "__main__":
    try:
        vu.main()
    except SystemExit as e:
        sys.exit(e.code)
