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
rtl_lib.add_source_files(utils_dir / "clamp_pkg.vhd")

# Add DSP modules
dsp_dir = fpga_dir / "common" / "rtl" / "dsp"
rtl_lib.add_source_files(dsp_dir / "multiplier.vhd")
rtl_lib.add_source_files(dsp_dir / "interpolator.vhd")
rtl_lib.add_source_files(dsp_dir / "proc_amp.vhd")
rtl_lib.add_source_files(dsp_dir / "edge_detector.vhd")
rtl_lib.add_source_files(dsp_dir / "lfsr.vhd")
rtl_lib.add_source_files(dsp_dir / "lfsr16.vhd")
rtl_lib.add_source_files(dsp_dir / "frequency_doubler.vhd")
rtl_lib.add_source_files(dsp_dir / "sin_cos_full_lut_10x10.vhd")
rtl_lib.add_source_files(dsp_dir / "variable_delay_u.vhd")
rtl_lib.add_source_files(dsp_dir / "diff_multiplier_s.vhd")
rtl_lib.add_source_files(dsp_dir / "variable_filter_s.vhd")

# Add serial modules
serial_dir = fpga_dir / "common" / "rtl" / "serial"
rtl_lib.add_source_files(serial_dir / "spi_peripheral.vhd")

# Add video sync modules
rtl_lib.add_source_files(video_sync_dir / "video_field_detector.vhd")
rtl_lib.add_source_files(video_sync_dir / "video_sync_generator.vhd")
rtl_lib.add_source_files(video_sync_dir / "dual_sync_delay.vhd")

# Add video processing modules
rtl_lib.add_source_files(video_stream_dir / "yuv422_20b_to_yuv444_30b.vhd")
rtl_lib.add_source_files(video_stream_dir / "yuv444_30b_to_yuv422_20b.vhd")
rtl_lib.add_source_files(video_stream_dir / "yuv444_30b_blanking.vhd")
rtl_lib.add_source_files(video_stream_dir / "gbr444_30b_blanking.vhd")
rtl_lib.add_source_files(video_stream_dir / "gbr422_20b_to_gbr444_30b.vhd")
rtl_lib.add_source_files(video_stream_dir / "gbr444_30b_to_gbr422_20b.vhd")
rtl_lib.add_source_files(video_stream_dir / "adv7181c_rgb_ddr_to_gbr444.vhd")
rtl_lib.add_source_files(video_stream_dir / "video_line_buffer.vhd")

# Add video timing modules
rtl_lib.add_source_files(video_timing_dir / "resolution_pkg.vhd")
rtl_lib.add_source_files(video_timing_dir / "video_timing_accumulator.vhd")
rtl_lib.add_source_files(video_timing_dir / "video_timing_generator.vhd")
rtl_lib.add_source_files(video_timing_dir / "pixel_counter.vhd")
rtl_lib.add_source_files(video_timing_dir / "frame_counter.vhd")
rtl_lib.add_source_files(video_timing_dir / "frame_phase_accumulator.vhd")

# Add platform modules (iCE40)
platform_ice40_dir = fpga_dir / "platform" / "ice40" / "rtl"
rtl_lib.add_source_files(platform_ice40_dir / "glitch_free_clock_mux.vhd")

# Behavioural SB_PLL40_CORE simulation stub.  The Lattice SiliconBlue
# component file in third_party/ is synthesis-only (black-box declarations);
# this stub provides a GHDL-friendly behavioural architecture so that any
# wrapper instantiating SB_PLL40_CORE can be simulated end-to-end.  Must be
# elaborated before standalone_hd_video_clk_pll so the component binding
# resolves to the simulation entity.
rtl_lib.add_source_files(test_dir / "sb_pll40_core_sim.vhd")
rtl_lib.add_source_files(platform_ice40_dir / "standalone_hd_video_clk_pll.vhd")

# Add test library
test_lib = vu.add_library("test_lib")
# Enumerate testbenches explicitly so we can skip in-progress files that
# do not yet compile (e.g. tb_program_top_alignment.vhd, which depends on
# a per-program program_top architecture not present in the SDK rtl_lib).
_TEST_LIB_EXCLUDES = {
    "tb_program_top_alignment.vhd",  # WIP: depends on program_top entity
    "sb_pll40_core_sim.vhd",         # belongs to rtl_lib (added above)
}
for _tb in sorted(test_dir.glob("tb_*.vhd")):
    if _tb.name in _TEST_LIB_EXCLUDES:
        continue
    test_lib.add_source_files(_tb)

# ============================================================================
# Generic-parameterized testbenches
# Tests each DUT across multiple width/precision configurations to verify
# pipeline latency formulas, enable/valid timing, and functional correctness.
# ============================================================================

# Multiplier: sweep G_WIDTH from 6 to 16, with symmetric and asymmetric frac
tb_mult_gen = test_lib.entity("tb_multiplier_generics")
for name, width, frac, omin, omax in [
    ("w6_f5",   6,  5,  -32,    31),
    ("w8_f7",   8,  7,  -128,   127),
    ("w10_f9",  10, 9,  -512,   511),
    ("w12_f10", 12, 10, -2048,  2047),
    ("w16_f15", 16, 15, -32768, 32767),
]:
    tb_mult_gen.add_config(name, generics=dict(
        G_WIDTH=width, G_FRAC_BITS=frac,
        G_OUTPUT_MIN=omin, G_OUTPUT_MAX=omax))

# Proc amp: sweep G_WIDTH (internal multiplier width = G_WIDTH + 2)
tb_pa_gen = test_lib.entity("tb_proc_amp_generics")
for name, width in [("w8", 8), ("w10", 10), ("w12", 12)]:
    tb_pa_gen.add_config(name, generics=dict(G_WIDTH=width))

# Interpolator: sweep width, frac bits, and clamp range
tb_interp_gen = test_lib.entity("tb_interpolator_generics")
for name, width, frac, omin, omax in [
    ("w8_f8",               8,  8,  0,   255),
    ("w10_f10",             10, 10, 0,   1023),
    ("w12_f12",             12, 12, 0,   4095),
    ("w8_f12",              8,  12, 0,   255),
    ("w10_f10_narrowclamp", 10, 10, 100, 900),
]:
    tb_interp_gen.add_config(name, generics=dict(
        G_WIDTH=width, G_FRAC_BITS=frac,
        G_OUTPUT_MIN=omin, G_OUTPUT_MAX=omax))

# Diff multiplier: sweep G_WIDTH with matching frac/range
tb_diff_gen = test_lib.entity("tb_diff_multiplier_generics")
for name, width, frac, omin, omax in [
    ("w6_f5",  6,  5,  -32,    31),
    ("w8_f7",  8,  7,  -128,   127),
    ("w10_f9", 10, 9,  -512,   511),
    ("w12_f10", 12, 10, -2048, 2047),
]:
    tb_diff_gen.add_config(name, generics=dict(
        G_WIDTH=width, G_FRAC_BITS=frac,
        G_OUTPUT_MIN=omin, G_OUTPUT_MAX=omax))

# Variable filter: sweep G_WIDTH
tb_vf_gen = test_lib.entity("tb_variable_filter_generics")
for name, width in [("w8", 8), ("w10", 10), ("w12", 12), ("w16", 16)]:
    tb_vf_gen.add_config(name, generics=dict(G_WIDTH=width))

# Variable delay: sweep G_WIDTH and G_DEPTH
tb_vd_gen = test_lib.entity("tb_variable_delay_generics")
for name, width, depth in [
    ("w8_d4",  8,  4),
    ("w10_d6", 10, 6),
    ("w16_d8", 16, 8),
    ("w32_d11", 32, 11),
]:
    tb_vd_gen.add_config(name, generics=dict(G_WIDTH=width, G_DEPTH=depth))

# LFSR: sweep DATA_WIDTH
tb_lfsr_gen = test_lib.entity("tb_lfsr_generics")
for name, width in [("w4", 4), ("w8", 8), ("w10", 10), ("w12", 12), ("w16", 16)]:
    tb_lfsr_gen.add_config(name, generics=dict(G_WIDTH=width))

# Frequency doubler: sweep G_WIDTH
tb_fd_gen = test_lib.entity("tb_freq_doubler_generics")
for name, width in [("w8", 8), ("w9", 9), ("w10", 10), ("w12", 12)]:
    tb_fd_gen.add_config(name, generics=dict(G_WIDTH=width))

# ============================================================================
# Resolution package: verify all 15 timing IDs map to correct active
# pixel dimensions through both unsigned and signed accessors.
# ============================================================================

tb_res = test_lib.entity("tb_resolution_pkg")
for name, tid, h_act, v_act, h_cen, v_cen in [
    ("ntsc",      0,  720,  486, 360, 243),
    ("1080i50",   1, 1920, 1080, 960, 540),
    ("1080i5994", 2, 1920, 1080, 960, 540),
    ("1080p24",   3, 1920, 1080, 960, 540),
    ("480p",      4,  720,  480, 360, 240),
    ("720p50",    5, 1280,  720, 640, 360),
    ("720p5994",  6, 1280,  720, 640, 360),
    ("1080p30",   7, 1920, 1080, 960, 540),
    ("pal",       8,  720,  576, 360, 288),
    ("1080p2398", 9, 1920, 1080, 960, 540),
    ("1080i60",  10, 1920, 1080, 960, 540),
    ("1080p25",  11, 1920, 1080, 960, 540),
    ("576p",     12,  720,  576, 360, 288),
    ("1080p2997",13, 1920, 1080, 960, 540),
    ("720p60",   14, 1280,  720, 640, 360),
]:
    tb_res.add_config(name, generics=dict(
        G_TIMING_ID=tid, G_H_ACTIVE=h_act, G_V_ACTIVE=v_act,
        G_H_CENTER=h_cen, G_V_CENTER=v_cen))

# ============================================================================
# Video sync generator formats: exercise the sync generator with every
# timing ID. Verifies HSYNC pulse generation, trisync config, and line
# period for each video standard.
# ============================================================================

tb_syncfmt = test_lib.entity("tb_video_sync_gen_formats")
for name, tid, cpl, intlc, tri in [
    ("ntsc",       0,  858, 1, 0),
    ("1080i50",    1, 2640, 1, 1),
    ("1080i5994",  2, 2200, 1, 1),
    ("1080p24",    3, 2750, 0, 1),
    ("480p",       4,  858, 0, 0),
    ("720p50",     5, 1980, 0, 1),
    ("720p5994",   6, 1650, 0, 1),
    ("1080p30",    7, 2200, 0, 1),
    ("pal",        8,  864, 1, 0),
    ("1080p2398",  9, 2750, 0, 1),
    ("1080i60",   10, 2200, 1, 1),
    ("1080p25",   11, 2640, 0, 1),
    ("576p",      12,  864, 0, 0),
    ("1080p2997", 13, 2200, 0, 1),
    ("720p60",    14, 1650, 0, 1),
]:
    tb_syncfmt.add_config(name, generics=dict(
        G_TIMING_ID=tid, G_CLOCKS_PER_LINE=cpl,
        G_IS_INTERLACED=intlc, G_TRISYNC_EN=tri))

for name, tid, cpl, intlc, tri in [
    ("ntsc_phase",       0,  858, 1, 0),
    ("1080i50_phase",    1, 2640, 1, 1),
    ("1080i5994_phase",  2, 2200, 1, 1),
    ("1080p24_phase",    3, 2750, 0, 1),
    ("480p_phase",       4,  858, 0, 0),
    ("720p50_phase",     5, 1980, 0, 1),
    ("720p5994_phase",   6, 1650, 0, 1),
    ("1080p30_phase",    7, 2200, 0, 1),
    ("pal_phase",        8,  864, 1, 0),
    ("1080p2398_phase",  9, 2750, 0, 1),
    ("1080i60_phase",   10, 2200, 1, 1),
    ("1080p25_phase",   11, 2640, 0, 1),
    ("576p_phase",      12,  864, 0, 0),
    ("1080p2997_phase", 13, 2200, 0, 1),
    ("720p60_phase",    14, 1650, 0, 1),
]:
    tb_syncfmt.add_config(name, generics=dict(
        G_TIMING_ID=tid, G_CLOCKS_PER_LINE=cpl,
        G_IS_INTERLACED=intlc, G_TRISYNC_EN=tri,
        G_PHASE_ADVANCE=1, G_PHASE_ADVANCE_CLKS=20))

tb_syncfmt.add_config("1080i5994_phase22", generics=dict(
    G_TIMING_ID=2, G_CLOCKS_PER_LINE=2200,
    G_IS_INTERLACED=1, G_TRISYNC_EN=1,
    G_PHASE_ADVANCE=1, G_PHASE_ADVANCE_CLKS=22))

# Dual EXT-sync delay: production uses G_DELAY_CLKS=50; also cover a
# short chain so the pulse-edge checks stay fast in the suite.
tb_dual_delay = test_lib.entity("tb_dual_sync_delay")
tb_dual_delay.add_config("delay4", generics=dict(G_DELAY_CLKS=4))
tb_dual_delay.add_config("delay50", generics=dict(G_DELAY_CLKS=50))

# Main entry point
if __name__ == "__main__":
    try:
        vu.main()
    except SystemExit as e:
        sys.exit(e.code)
