# Videomancer ABI Format Specification

**Version:** 1.0  
**Date:** December 15, 2025

## Overview

The Videomancer Application Binary Interface (ABI) defines the communication protocol between the RP2040 MCU and the FPGA program during runtime. This specification describes the SPI-based register map and timing requirements for controlling video processing parameters.

## SPI Protocol

### Communication Parameters

- **Interface:** SPI (Serial Peripheral Interface)
- **Mode:** Standard SPI with chip select
- **Transfer Size:** 16 bits per transaction
- **Bit Order:** MSB first

### Frame Structure

Each SPI transaction consists of a 16-bit frame with the following structure:

```
┌────┬────────────┬──────────────────────┬─────┐
│ Bit│  15        │  14-10               │ 9-0 │
├────┼────────────┼──────────────────────┼─────┤
│Field│ R/W̅       │ Address[4:0]         │ Data│
└────┴────────────┴──────────────────────┴─────┘
```

| Field | Bits | Description |
|-------|------|-------------|
| R/W̅  | 15 | Read/Write flag (must be 0 for write) |
| Address | 14:10 | 5-bit register address (0x00 - 0x1F) |
| Data | 9:0 | 10-bit data payload |

**Important:** All control registers are **write-only**. Read operations (R/W̅ = 1) are not supported and will be ignored by the FPGA. The MCU application must maintain its own state tracking for control values.

### Timing Diagram

#### Write Transaction

```
CS̅   ────┐                                                      ┌────
         └──────────────────────────────────────────────────────┘

SCK  ────────┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐   ┐
             └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─┐ └─

MOSI ────────┤ 0 │A4 │A3 │A2 │A1 │A0 │D9 │D8 │...│D1 │D0 │───
             └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───
              R/W̅  ├────Address────┤  ├────────Data────────┤
```

**Transaction Sequence:**

1. MCU asserts CS̅ (Chip Select) LOW
2. MCU clocks out 16 bits on MOSI:
   - Bit 15: R/W̅ flag (0 for write)
   - Bits 14-10: 5-bit register address
   - Bits 9-0: 10-bit data value
3. MCU de-asserts CS̅ HIGH
4. FPGA latches data on CS̅ rising edge

### Timing Requirements

| Parameter | Min | Typ | Max | Unit | Notes |
|-----------|-----|-----|-----|------|-------|
| SPI Clock Frequency | 100 | 1000 | 10000 | kHz | |
| CS̅ Setup Time | 10 | - | - | ns | Before first clock edge |
| CS̅ Hold Time | 10 | - | - | ns | After last clock edge |
| Inter-transaction Gap | 100 | - | - | ns | CS̅ high between transactions |

## Register Map

### Control Registers

| Address | Bit Range | Field Name | Type | Description |
|---------|-----------|------------|------|-------------|
| 0x00 | [9:0] | `rotary_potentiometer_1` | W | Rotary potentiometer 1 value (0-1023) |
| 0x01 | [9:0] | `rotary_potentiometer_2` | W | Rotary potentiometer 2 value (0-1023) |
| 0x02 | [9:0] | `rotary_potentiometer_3` | W | Rotary potentiometer 3 value (0-1023) |
| 0x03 | [9:0] | `rotary_potentiometer_4` | W | Rotary potentiometer 4 value (0-1023) |
| 0x04 | [9:0] | `rotary_potentiometer_5` | W | Rotary potentiometer 5 value (0-1023) |
| 0x05 | [9:0] | `rotary_potentiometer_6` | W | Rotary potentiometer 6 value (0-1023) |
| 0x06 | [0] | `toggle_switch_7` | W | Toggle switch 7 state (0=OFF, 1=ON) |
| 0x06 | [1] | `toggle_switch_8` | W | Toggle switch 8 state (0=OFF, 1=ON) |
| 0x06 | [2] | `toggle_switch_9` | W | Toggle switch 9 state (0=OFF, 1=ON) |
| 0x06 | [3] | `toggle_switch_10` | W | Toggle switch 10 state (0=OFF, 1=ON) |
| 0x06 | [4] | `toggle_switch_11` | W | Toggle switch 11 state (0=OFF, 1=ON) |
| 0x06 | [9:5] | - | Reserved | Reserved for future use |
| 0x07 | [9:0] | `linear_potentiometer_12` | W | Linear potentiometer 12 value (0-1023) |
| 0x08 | [3:0] | `video_timing_id` | W | Video timing mode identifier (0-15) |
| 0x08 | [9:4] | - | Reserved | Reserved for future use |
| 0x09-0x1F | - | - | Reserved | Reserved for future expansion |

### Register Details

**Access Mode:** All registers are **write-only**. The FPGA does not support read operations.

#### Potentiometer Registers (0x00-0x05, 0x07)

**Format:** 10-bit unsigned integer  
**Range:** 0-1023 (0x000-0x3FF)  
**Resolution:** 10 bits (~0.1% per step)

Potentiometer values are read from ADC inputs and transmitted to the FPGA for real-time video parameter control. The FPGA program is responsible for scaling and mapping these values to meaningful video processing parameters.

#### Switch Register (0x06)

**Format:** Bit field  
**Active Bits:** [4:0]

Individual toggle switches are mapped to bits 0-4. Each bit represents the state of one toggle switch:
- `0` = Switch OFF/Open
- `1` = Switch ON/Closed

Bits [9:5] are reserved and should be written as 0.

#### Video Timing ID (0x08)

**Format:** 4-bit unsigned integer  
**Range:** 0-15 (0x0-0xF)

Selects the video timing mode for the output generator. The following timing modes are defined in the video timing package:

| ID (Hex) | ID (Dec) | Mode | Description |
|----------|----------|------|-------------|
| 0x0 | 0 | NTSC | 480i59.94 NTSC (525 lines, interlaced) |
| 0x1 | 1 | 1080i50 | 1080i 50 Hz (interlaced) |
| 0x2 | 2 | 1080i59.94 | 1080i 59.94 Hz (interlaced) |
| 0x3 | 3 | 1080p24 | 1080p 24 Hz (progressive) |
| 0x4 | 4 | 480p | 480p 59.94 Hz (progressive) |
| 0x5 | 5 | 720p50 | 720p 50 Hz (progressive) |
| 0x6 | 6 | 720p59.94 | 720p 59.94 Hz (progressive) |
| 0x7 | 7 | 1080p30 | 1080p 30 Hz (progressive) |
| 0x8 | 8 | PAL | 576i50 PAL (625 lines, interlaced) |
| 0x9 | 9 | 1080p23.98 | 1080p 23.98 Hz (progressive) |
| 0xA | 10 | 1080i60 | 1080i 60 Hz (interlaced) |
| 0xB | 11 | 1080p25 | 1080p 25 Hz (progressive) |
| 0xC | 12 | 576p | 576p 50 Hz (progressive) |
| 0xD | 13 | 1080p29.97 | 1080p 29.97 Hz (progressive) |
| 0xE | 14 | 720p60 | 720p 60 Hz (progressive) |
| 0xF | 15 | Reserved | Reserved for future use |

**Note:** All timing modes are defined in [fpga/rtl/video_timing_pkg.vhd](../fpga/rtl/video_timing_pkg.vhd).

## Implementation Notes

### RP2040 MCU Side

1. **Initialization:**
   - Configure SPI peripheral in Mode 0 (CPOL=0, CPHA=0)
   - Set appropriate clock divider for target SPI frequency
   - Configure CS̅ as GPIO output, initially HIGH

2. **Write Operation:**
   ```c
   void write_register(uint8_t addr, uint16_t data) {
       uint16_t frame = (0 << 15) |          // Write bit
                        ((addr & 0x1F) << 10) | // 5-bit address
                        (data & 0x3FF);        // 10-bit data
       
       gpio_put(CS_PIN, 0);              // Assert CS̅
       spi_write16_blocking(spi0, &frame, 1);
       gpio_put(CS_PIN, 1);              // De-assert CS̅
   }
   ```

### FPGA Side

The FPGA implements an SPI peripheral module that:
1. Detects CS̅ assertion
2. Shifts in 16-bit frames on SCK rising edges
3. Decodes address and R/W̅ flag
4. Writes data to internal registers on CS̅ rising edge (write operations only)
5. Ignores transactions with R/W̅ = 1 (read operations not supported)

Register values are made available to the video processing pipeline through a parallel interface.

**Important:** Application code on the MCU must maintain its own shadow copy of register values since read operations are not supported.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-15 | Initial ABI specification |

## References

- [VMPROG Format Specification](vmprog-format.md)
- [ED25519 Signing Guide](vmprog-ed25519-signing.md)
- SPI peripheral RTL: `fpga/rtl/spi_peripheral.vhd`
- Core integration: `fpga/rtl/core.vhd`
