# Videomancer SDK - FPGA Build Makefile
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

PROGRAM = yuv_proc_amp
CONFIG = analog
DEVICE = hx4k
PACKAGE = tq144
FREQUENCY = 74.25
HARDWARE = videomancer_core_rev_b

VHD_FILES = $(wildcard ./rtl/*.vhd) \
	$(wildcard ../programs/$(PROGRAM)/*.vhd) \
	./rtl/config/$(CONFIG)_pkg.vhd \
	$(wildcard ../third_party/SiliconBlue/rtl/sb_*.vhd)

PCF_FILE = \
	./constraints/$(HARDWARE)/pin_map.pcf

BUILD_PREFIX = ../build/programs/$(PROGRAM)/bitstreams/
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