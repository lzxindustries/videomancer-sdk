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
| 0x09 | [9:0] | `sync_phase_advance_clks` | W | Core-only: Sync Out horizontal phase advance in `vid_clk` pixels (`processing_delay_clks` + core post-delay). Latched on the same HSYNC edge as `video_timing_id` into a core-only register (not program-visible). |
| 0x09 | [15:10] | - | Reserved | Reserved (write as 0; SPI frame uses bits 9-0 only) |
| 0x0A | [6:0] | `h_phase_sync_out` | W | Dual IO only: H Phase Out trim for Sync Out generator (0–127, **64 = 0 px**). Latched on `i_hdmi_rx_clk` HSYNC. Ignored on standalone / HDMI-only configs. |
| 0x0A | [9:7] | - | Reserved | Reserved (write as 0) |
| 0x0B | [6:0] | `h_phase_analog_in` | W | Dual IO only: H Phase In trim for EXT analog-in sync path (0–127, **64 = 0 px**). Latched on `i_hdmi_rx_clk` HSYNC together with factory base delay. Ignored when FPGA does not drive decoder sync. |
| 0x0B | [9:7] | - | Reserved | Reserved (write as 0) |
| 0x0C-0x1F | - | - | Reserved | Reserved for future expansion |

### Register Details

**Access Mode:** All registers are **write-only**. The FPGA does not support read operations.

#### Potentiometer Registers (0x00-0x05, 0x07)

**Format:** 10-bit unsigned integer
**Range:** 0-1023 (0x000-0x3FF)
**Resolution:** 10 bits (~0.1% per step)

Potentiometer values are read from ADC inputs and transmitted to the FPGA for real-time video parameter control. The FPGA program is responsible for scaling and mapping these values to meaningful video processing parameters.

**Shadow RAM latch:** The MCU writes the live SPI RAM (`s_spi_ram`); programs read
the shadow copy (`s_spi_ram_d`, registers 0x00–0x08). On each **HSYNC falling edge**
of the program video input the core latches 0x00–0x08 into program shadow RAM and
latches 0x09 into a core-only phase-advance register used by `video_sync_generator`.
Line-rate snapshot of 0x00–0x07 is required for firmware per-line modulation.

#### Switch Register (0x06)

**Format:** Bit field
**Active Bits:** [4:0]

Individual toggle switches are mapped to bits 0-4. Each bit represents the state of one toggle switch:
- `0` = Switch OFF/Open
- `1` = Switch ON/Closed

Bits [9:5] are reserved and should be written as 0.

#### Video Timing ID (0x08)

**Format:** 4-bit unsigned integer in bits [3:0]
**Range:** 0-14 valid, 15 reserved

The firmware writes the current video timing mode to register 0x08 once at
program load time, and again whenever the video standard changes. Programs
can read `registers_in(8)(3 downto 0)` to adapt processing to the active
video format.

**Timing ID Values:**

| ID (hex) | ID (binary) | VHDL Constant | Standard | Frame W×H | Clocks/Line | Lines/Frame | Interlaced | Clock |
|----------|-------------|---------------|----------|-----------|-------------|-------------|------------|-------|
| 0x0 | `0000` | `C_NTSC`       | 480i 59.94 Hz  | 720×486   | 858  | 525  | Yes | 13.5 MHz  |
| 0x1 | `0001` | `C_1080I50`    | 1080i 50 Hz    | 1920×1080 | 2640 | 1125 | Yes | 74.25 MHz |
| 0x2 | `0010` | `C_1080I5994`  | 1080i 59.94 Hz | 1920×1080 | 2200 | 1125 | Yes | 74.25 MHz |
| 0x3 | `0011` | `C_1080P24`    | 1080p 24 Hz    | 1920×1080 | 2750 | 1125 | No  | 74.25 MHz |
| 0x4 | `0100` | `C_480P`       | 480p 59.94 Hz  | 720×480   | 858  | 525  | No  | 27 MHz    |
| 0x5 | `0101` | `C_720P50`     | 720p 50 Hz     | 1280×720  | 1980 | 750  | No  | 74.25 MHz |
| 0x6 | `0110` | `C_720P5994`   | 720p 59.94 Hz  | 1280×720  | 1650 | 750  | No  | 74.25 MHz |
| 0x7 | `0111` | `C_1080P30`    | 1080p 30 Hz    | 1920×1080 | 2200 | 1125 | No  | 74.25 MHz |
| 0x8 | `1000` | `C_PAL`        | 576i 50 Hz     | 720×576   | 864  | 625  | Yes | 13.5 MHz  |
| 0x9 | `1001` | `C_1080P2398`  | 1080p 23.98 Hz | 1920×1080 | 2750 | 1125 | No  | 74.25 MHz |
| 0xA | `1010` | `C_1080I60`    | 1080i 60 Hz    | 1920×1080 | 2200 | 1125 | Yes | 74.25 MHz |
| 0xB | `1011` | `C_1080P25`    | 1080p 25 Hz    | 1920×1080 | 2640 | 1125 | No  | 74.25 MHz |
| 0xC | `1100` | `C_576P`       | 576p 50 Hz     | 720×576   | 864  | 625  | No  | 27 MHz    |
| 0xD | `1101` | `C_1080P2997`  | 1080p 29.97 Hz | 1920×1080 | 2200 | 1125 | No  | 74.25 MHz |
| 0xE | `1110` | `C_720P60`     | 720p 60 Hz     | 1280×720  | 1650 | 750  | No  | 74.25 MHz |
| 0xF | `1111` | _(reserved)_   | —              | —         | —    | —    | —   | —         |

**SD vs HD classification:**
- **SD modes** (13.5 MHz pixel clock): NTSC (0x0), 480p (0x4), PAL (0x8), 576p (0xC)
- **HD modes** (74.25 MHz pixel clock): All others (0x1-0x3, 0x5-0x7, 0x9-0xE)

SD modes run at 13.5 MHz or 27 MHz (480p/576p are double-rate SD). HD modes
run at 74.25 MHz. The FPGA core applies a clock decimation factor for SD
configs so that programs always see one pixel per clock.

**VHDL references:**
- Timing ID constants: `fpga/common/rtl/video_timing/video_timing_pkg.vhd`
- Full sync parameters: `fpga/common/rtl/video_sync/video_sync_pkg.vhd` (`C_VIDEO_SYNC_CONFIG_ARRAY`)
- C++ mirror: `videomancer_abi.hpp` (`video_timing_configs[]`)

### Register Summary

| Addr | Field | Description |
|------|-------|-------------|
| 0x00-0x05 | `rotary_potentiometer_1-6` | 10-bit value (0-1023) |
| 0x06 | `toggle_switch_7-11` | Bits [4:0], 0=OFF 1=ON |
| 0x07 | `linear_potentiometer_12` | 10-bit value (0-1023) |
| 0x08 | `video_timing_id` | Bits [3:0], timing mode 0-15 |
| 0x09 | `sync_phase_advance_clks` | Bits [9:0], pipeline phase advance (core-only) |
| 0x0A | `h_phase_sync_out` | Bits [6:0], dual IO Sync Out trim (64 = center) |
| 0x0B | `h_phase_analog_in` | Bits [6:0], dual IO EXT analog-in sync trim (64 = center) |

#### H Phase Out / In (0x0A, 0x0B) — dual IO only

On **dual routing** configs (`hd_dual`, `sd_dual`), firmware exposes OLED settings
**H Phase Out** and **H Phase In** (settings IDs 17 and 18) that map to SPI
registers 0x0A and 0x0B. Values are 7-bit unsigned (**0–127**); **64 = no trim**
(±64 pixel range). Firmware writes these on program load and when the setting
changes; shell `remote write 10|11 <val>` accepts the same range.

| Register | Domain | Effect |
|----------|--------|--------|
| 0x0A | Sync Out | Trims HS/VS emitted on the Sync Out jack relative to HDMI RX timebase |
| 0x0B | Analog in (EXT) | Trims sync fed to ADV7181 when FPGA drives decoder sync |

Register 0x09 (`sync_phase_advance_clks`) remains the **factory pipeline**
advance for standalone / program-path Sync Out. On dual IO, firmware sets
0x09 to `processing_delay_clks + core_post_delay` only (raw advance = 0);
user trim is applied separately via 0x0A and 0x0B.

**Access:** Core-only — not latched into program shadow RAM. Standalone and
HDMI-only cores ignore 0x0A/0x0B.

### Processing delay metadata (vmprog 1.1)

`processing_delay_clks` in the program config is the **true `program_top` input→output
latency in `vid_clk` pixels**, including any IO-align register stages at the
program boundary. Firmware writes SPI register 0x09 as
`processing_delay_clks + core_post_delay`, clamped to 1023:
- **yuv444_30b / gbr444_30b:** `core_post_delay` = 4 (blanking 2 + 444→422 sync 2)
- **yuv422_20b / gbr422_20b:** `core_post_delay` = 0

**Sync Out semantics:** Register 0x09 *advances* Sync Out relative to program
**input** by that many `vid_clk` pixels so the external jack pre-compensates the
pipeline and coincides with processed-video H at the encoder / HDMI pins (under
the calibrated per-format `fsync` seeds). Program video ports (analog H/V, SOG,
HDMI TX) keep sync on the **same delayed pipeline** as their pixels — they do
not use the Sync Out generator.

**Alignment rule:** `processing_delay_clks` must be **even** (minimum) and should be
**divisible by 4**. Odd totals invert Cb/Cr relative to Sync Out / ADV7393 HSYNC
phase; totals not divisible by 4 break the house IO-align convention used across
embedded programs.

Declare the same value as `C_PROCESSING_DELAY_CLKS` in VHDL (or set
`processing_delay_clks` explicitly in TOML). Do not report pre-IO-align sync pipe
depth only — that under-counts and misaligns Sync Out after rc.33.

Video timing modes are enumerated in the [Video Timing ID table](#video-timing-id-0x08) above.
Constants defined in `fpga/common/rtl/video_timing/video_timing_pkg.vhd` and
mirrored in C++ via `videomancer_abi.hpp` (`video_timing_configs[]`).

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

**FPGA:** See `fpga/common/rtl/serial/spi_peripheral.vhd`

