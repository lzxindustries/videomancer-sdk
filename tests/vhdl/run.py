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
fpga_dir = project_root / "fpga"
test_dir = Path(__file__).parent

# Add RTL source library
rtl_lib = vu.add_library("rtl_lib")

# Add common video packages (in dependency order)
video_stream_dir = fpga_dir / "common" / "rtl" / "video_stream"
video_timing_dir = fpga_dir / "common" / "rtl" / "video_timing"
video_sync_dir = fpga_dir / "common" / "rtl" / "video_sync"

# Add packages first
rtl_lib.add_source_files(video_stream_dir / "video_stream_pkg.vhd")
rtl_lib.add_source_files(video_timing_dir / "video_timing_pkg.vhd")
rtl_lib.add_source_files(video_sync_dir / "video_sync_pkg.vhd")

# Add core package files (using yuv444_30b as default for testing)
core_rtl_dir = fpga_dir / "core" / "yuv444_30b" / "rtl"
rtl_lib.add_source_files(core_rtl_dir / "core_pkg.vhd")

# Add utility modules
utils_dir = fpga_dir / "common" / "rtl" / "utils"
rtl_lib.add_source_files(utils_dir / "sync_slv.vhd")

# Add video processing modules
rtl_lib.add_source_files(video_stream_dir / "yuv422_20b_to_yuv444_30b.vhd")
rtl_lib.add_source_files(video_stream_dir / "yuv444_30b_to_yuv422_20b.vhd")
rtl_lib.add_source_files(video_stream_dir / "yuv444_30b_blanking.vhd")

# Add test library
test_lib = vu.add_library("test_lib")
test_lib.add_source_files(test_dir / "tb_*.vhd")

# Main entry point
if __name__ == "__main__":
    try:
        vu.main()
    except SystemExit as e:
        sys.exit(e.code)
