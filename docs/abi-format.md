# ABI Format Specification

SPI communication protocol between RP2040 MCU and FPGA.

## SPI Frame (16 bits)

```

Bit 15: R/W̅ (must be 0 for write)

Bits 14-10: Address (0x00-0x1F)

Bits 9-0: Data (10-bit value)

```

All registers are write-only. No read operations supported.

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

## Register Map

| Addr | Field | Description |
|------|-------|-------------|
| 0x00-0x05 | `rotary_potentiometer_1-6` | 10-bit value (0-1023) |
| 0x06 | `toggle_switch_7-11` | Bits [4:0], 0=OFF 1=ON |
| 0x07 | `linear_potentiometer_12` | 10-bit value (0-1023) |
| 0x08 | `video_timing_id` | Bits [3:0], timing mode 0-15 |

Video timing modes defined in `fpga/rtl/video_timing_pkg.vhd`.

## Implementation

**MCU (RP2040):**

```c

void write_register(uint8_t addr, uint16_t data) {

    uint16_t frame = (0 << 15) | ((addr & 0x1F) << 10) | (data & 0x3FF);

    gpio_put(CS_PIN, 0);

    spi_write16_blocking(spi0, &frame, 1);

    gpio_put(CS_PIN, 1);

}

```

**FPGA:** See `fpga/rtl/spi_peripheral.vhd`

