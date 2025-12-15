# Videomancer SDK - FPGA Build Makefile
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

# Root paths (must be provided by caller)
VIDEOMANCER_SDK_ROOT ?= ..
PROJECT_ROOT ?= $(VIDEOMANCER_SDK_ROOT)/programs/$(PROGRAM)
BUILD_ROOT ?= $(VIDEOMANCER_SDK_ROOT)/build/programs/$(PROGRAM)

PROGRAM = yuv_proc_amp
CONFIG = analog
DEVICE = hx4k
PACKAGE = tq144
FREQUENCY = 74.25
HARDWARE = videomancer_core_rev_b

VHD_FILES = $(wildcard $(VIDEOMANCER_SDK_ROOT)/fpga/rtl/*.vhd) \
	$(wildcard $(PROJECT_ROOT)/*.vhd) \
	$(VIDEOMANCER_SDK_ROOT)/fpga/rtl/config/$(CONFIG)_pkg.vhd \
	$(wildcard $(VIDEOMANCER_SDK_ROOT)/third_party/SiliconBlue/rtl/sb_*.vhd)

PCF_FILE = \
	$(VIDEOMANCER_SDK_ROOT)/fpga/constraints/$(HARDWARE)/pin_map.pcf

BUILD_PREFIX = $(BUILD_ROOT)/bitstreams/
BIN_FILE = $(BUILD_PREFIX)$(CONFIG).bin
JSON_FILE = $(BUILD_PREFIX)$(CONFIG).json
ASC_FILE = $(BUILD_PREFIX)$(CONFIG).asc

all: $(BIN_FILE)

$(JSON_FILE): $(VHD_FILES)
	@mkdir -p $(dir $@)
	yosys -m ghdl -p 'ghdl --std=08 $^ -e top; synth_ice40 -json $@'

$(ASC_FILE): $(JSON_FILE)
	@mkdir -p $(dir $@)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --pcf $(PCF_FILE) --freq $(FREQUENCY) --json $< --asc $@

$(BIN_FILE): $(ASC_FILE)
	icepack $< $@

prog: $(BIN_FILE)
	iceprog $<

clean:
	rm -f $(JSON_FILE) $(ASC_FILE) $(BIN_FILE)

.SECONDARY:

.PHONY: all prog clean