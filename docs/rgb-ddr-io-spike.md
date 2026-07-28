# RGB digital I/O spike — ADV7181C / ADV7393 (Rev B)

**Date:** 2026-07-23  
**Board:** Videomancer Rev B — full ADV7181C P0–P19+LLC and ADV7393 P0–P15+DCLK on FPGA.

## ADV7181C → FPGA: 12-bit 4:4:4 RGB DDR (primary)

Silicon supports `cp_output_select = _12bit_ddr` with `ddr_enable`. Effective RGB888 on 12 SDR pins × 2 edges.

### Datasheet packing (Table 10 — Pixel Output Formats)

Uses **P[19:8]** (12 bits). `↑` = rising LLC, `↓` = falling LLC. Confirmed against local `Analog_ADV7181.pdf` (ADV7181C Rev. E):

| Pins | Rising (↑) | Falling (↓) |
|------|------------|-------------|
| P[19:16] | B[7:4] | R[3:0] |
| P[15:12] | B[3:0] | G[7:4] |
| P[11:8] | G[3:0] | R[7:4] |

- Rising: `P[19:12]=B[7:0]`, `P[11:8]=G[3:0]`
- Falling: `P[19:16]=R[3:0]`, `P[15:12]=G[7:4]`, `P[11:8]=R[7:4]`

(Datasheet **Table 9** is ADC mux settings, not pixel packing.)

Firmware: GBR cores set `cp_output_select=_12bit_ddr`, `ddr_enable=true`,
`ddr_red_component_first=red_component_out_last` (B↑ R↓), LLC = pixel clock;
FPGA soft-IDDR unpacks Table 10 into GBR444. `csc_22` stays in 444
(no oversample/decimation); a former raw `0x67=0x13` write that clobbered
this register has been removed.

FPGA: `adv7181c_rgb_ddr_to_gbr444.vhd` on analog/standalone/dual decoder paths.

## ADV7393 ← FPGA: RGB digital input

### SD — supported (16-bit 4:4:4 RGB)

Datasheet: **4:4:4 RGB (SD) only**. Registers:

- `input_mode` = SD
- `sd_rgb_input_enable` = `rgb_input`
- `sd_input_format` = `_10bit_ycbcr_16bit_rgb`
- External HS/VS required (no EAV/SAV in RGB mode)

Pin map (fixed):

| Channel | Pins | LSB |
|---------|------|-----|
| Red | P4–P0 | P0 |
| Green | P10–P5 | P5 |
| Blue | P15–P11 | P11 |

### ED/HD — **not supported for RGB digital**

Datasheet input modes for ED/HD are **4:2:2 YCrCb** only (SDR 16-bit or DDR 8/10-bit). Analog RGB/YPbPr HD outs still take **YCbCr digital** and use on-chip YCbCr→RGB DAC CSC.

**Implication for RGB cores (no FPGA CSC):**

| Timing | Analog out path |
|--------|-----------------|
| SD | RGB 16-bit digital into ADV7393 — OK |
| HD/ED | Cannot feed RGB digitally; YCbCr digital would require fabric RGB→YCbCr — **forbidden by policy** |

**HD RGB-core policy (locked by spike):** HDMI RGB E2E for HD; analog HD out for RGB-core programs uses **GBR422 backup** (lane reinterpret / YCbCr bus + existing DAC CSC) **or** document “HDMI out only” until a fabric pad adapter is explicitly approved. Dual HD RGB passthrough to encoder likewise cannot be true RGB888 on 16 pins without YCbCr.

## ADV7611 / ADV7513

24-bit SDR RGB444 is supported in silicon. Firmware switches via
`set_pixel_format(video_pixel_format::rgb_444)` when `core_id` is GBR
(YCbCr 422 remains the default for YUV cores). ADV7611 datasheet Table 5:
`OP_FORMAT_SEL` `0x40` = 24-bit SDR 4:4:4, `0x8A` = 24-bit SDR 4:2:2.

## Firmware status (2026-07-23)

| Item | Status |
|------|--------|
| HDMI RGB444 for `gbr444_30b` / `gbr422_20b` | Done (7611/7513 + FSM `apply_program_io_policy`) |
| HDMI TX pack (gbr444) | Done — RGB888 aligned +2 clk with encoder 422 |
| HDMI TX demux (gbr422) | Done — `gbr422_20b_to_gbr444_30b` on HDMI-only path |
| Dual HDMI→encoder GBR422 | Done — B/R alternate on C with DE phase |
| ADV7181C 12-bit DDR + FPGA soft-IDDR | Done — Table 10 unpack, DE on FIELD/DE, LLC=1× pixel, `csc_22` 444 |
| SD ADV7393 RGB digital in | **Not used** — GBR422 Y/C + DAC CSC (unified SD/HD) |
| Dual HD true RGB888 to encoder | Blocked by ADV7393 HD |
| SOG Out / Test Pattern / Out Level | Done |

### Bring-up notes (residual bench risk)

1. Soft IDDR (fabric rising+falling FFs) — verify HD 74.25 MHz setup/hold on Rev B; SD/ED are lower risk.
2. Confirm Table 10 nibble packing and `ddr_red_component_first` on a color-bar source.
3. Confirm YPbPr→RGB CSC coefficients (BT.601 /2048) on component in.
4. GBR + CVBS/S-Video is overridden to YPbPr (SDP cannot emit DDR RGB).
5. Full ADI EngineerZone scripts / UG-180 / ADV7513 HW manual are not in-repo — register completeness beyond product datasheets is not offline-certifiable.

## Backups (unchanged)

1. **GBR422** — today’s 20/16-bit Y/C SDR buses; IC CSC / channel abuse.  
2. **YUV422 Dual passthrough** — retain for `yuv444_30b` / `yuv422_20b` bitstreams.


## GBR422 / GBR444 (implemented 2026-07-23)

- `gbr422_20b` — program sees `g`/`c`; pads = Y/C GBR422; HDMI RGB pack/demux.
- `gbr444_30b` — program sees `g`/`b`/`r`; HDMI from blanking RGB888; analog from DDR→GBR444.
- Renamed from `rgb444_30b` so component order matches YUV (primary / chroma0 / chroma1).
- Analog RGB path: ADV7181C `_12bit_ddr` + `adv7181c_rgb_ddr_to_gbr444` soft IDDR (Table 10).
- Bench-verify DDR edge packing and YPbPr→RGB CSC coeffs on hardware.
