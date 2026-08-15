# Changelog

All notable changes to the Videomancer SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-rc.47] - 2026-08-14

### Fixed

- **SD/ED YUV HDMI color accuracy** — Standalone `yuv444_30b` HDMI pack remaps
  full-range Y/U/V to limited range before ADV7513; Table 59 CSC (SDTV YCbCr
  limited → RGB full) then produces primary-accurate Colorbars on RGB HDMI
  sinks. Fixes oversaturated / hue-shifted bars after rc.46 limited-range CSC
  was fed full-range FPGA data.
- **HD YUV HDMI colorimetry** — AVI InfoFrame colorimetry is BT.601 for all
  YUV/422 output (was BT.709 at HD). Matches the BT.601 working space used on
  analog out and across the FPGA pipeline.

## [1.0.0-rc.46] - 2026-08-07

### Fixed

- **SD/ED YUV HDMI false-color** — ADV7513 now loads ADI Table 35 CSC
  (SDTV YCbCr limited → RGB full) for SD/ED YUV cores on Style-1 444 pack.
  HDMI out is true RGB with AVI RGB (fixes pink whites / scrambled bars on
  RGB sinks such as Roland V-4EX input 4). HD YUV 422 and GBR RGB paths
  unchanged. Previously Style-1 Y|U|V was announced as RGB AVI with CSC off
  (“false-color capture parity”).

## [1.0.0-rc.45] - 2026-08-05

### Fixed

- **Desk HIL gate** — vmtest harness fixes for YYY 1V, dual HD offset/reload, and 1080p shift search; acceptance **180/184** on desk (r0 HDMI-only residual). Firmware unchanged vs rc.44.

## [1.0.0-rc.44] - 2026-08-05

### Fixed

- **RGsB dual loopback (a4-3)** — FPGA EXT HS/VS on `r_gs_b` at HD; STDI/SOG alone failed 720p/1080p return leg lock.
- **Composite / S-Video dual loopback** — Restore FPGA EXT sync on YPbPr CP when Dual remaps CVBS/Y-C at HD; fixes hue shift and `cb_cr_swapped` bar failures (regression from selective `fpga_drives_decoder_sync()`).
- **YPbPr AC dual loopback (a1-2)** — Restore FPGA EXT sync for `analog_video_in_mode::ypbpr` at HD (anchor leg same regression as composite).
- **Gate E program scan** — Pre-release filter SD-only; all 27 embedded programs visible on `program scan`.

## [1.0.0-rc.43] - 2026-08-03

### Added

- **H Phase Out / In (dual IO)** — SPI registers `0x0A` / `0x0B`, unified Sync Out
  on program-input reference, EXT analog-in delay trim, ABI docs, vmtest serial +
  HIL gate.

### Fixed

- **`dual_sync_delay`** — split read/write BRAM inference (`syn_ramstyle =
  block_ram`); registered read compensated in `dual_ext_sync_delay_total`.
- **Dual Sync Out LC budget** — unified single `video_sync_generator` on
  `vid_clk` with program-input reference (dual and non-dual); removes duplicate
  HDMI-RX-domain generator that broke HX4K placement on heavy vmprogs.
- **All 27 embedded vmprogs rebuild** — Lumarian pipeline delay trim + packed
  sync shift; Mycelium wet-only chroma mix on HD Dual (luma wet/dry unchanged);
  Moire/Pinwheel/Howler fit with unified core alone.

### Changed

- **Mycelium HD Dual** — U/V wet/dry mix is wet-only (saves two `interpolator_u`
  instances); luma mix unchanged.

## [1.0.0-rc.42] - 2026-08-03

### Fixed

- **HD dual passthru (720p60 / 1080p30)** — Stop NTSC HS-position CP overrides on HD
  progressive dual lock; `invert_cr_cb` for external-sync HD. Fixes offset, Cb/Cr
  swap, and bar-level failures on YPbPr and RGB 1V loopback.
- **RTL dual sync delay** — HD progressive uses 17 LLC clocks in
  `dual_ext_sync_delay_clks`; passthru bitstream rebuilt.
- **Desk HIL** — `banding_spectral` ignores full-width shallow-ramp false positives.

## [1.0.0-rc.41] - 2026-08-02

### Fixed

- **PAL dual 576i passthru** — ADV7181 CP lock and RTL external-sync delay for 576i50
  dual YPbPr loopback; geometry HIL green after interlaced-UVC policy.

## [1.0.0-rc.40] - 2026-07-31

### Fixed

- **Program-library upload reset** — Feed RP2040 watchdog during `fs put` /
  FatFS commits so long Connect program-pack transfers no longer reset
  mid-upload (host USB hangup / broken pipe). Pairs with LZX Connect 1.3.5.

### Added

- **Shell developer hooks** — `screen dump` and `ui inject` (developer mode
  only) for desk vmtest automation.

## [1.0.0-rc.39] - 2026-07-31

### Fixed

- **Dual RGB 1V clamp / bar crush** — HDMI RX HS/VS into ADV7181C EXT sync
  delayed ~50 LLC clocks (`dual_sync_delay` on all four cores) so clamp
  recovery overshoot clears before active video. Delay line uses a small
  circular BRAM (not an FF shift register) so Lumarian HD Dual still fits
  the HX4K. RGB 1V DAC path keeps `sync_on_rgb` off (sync tips on 1V rails
  were crushing auto-clamp). ADV7393 HD CSC chroma coeffs scaled ×0.92
  (GY unchanged) to cut G→R/B leak on the dual RGB 1V loopback while greys
  stay accurate.
- **Dual analog loopback CSC / mode switch** — correct R/B mapping and
  dual-leg YPbPr AC ↔ RGB 1V switching; FPGA reload on dual `analog_in`
  changes. All release-stage embedded packs rebuilt and Ed25519-signed
  from this RTL.

### Fixed (prior Unreleased backlog)

- **Standalone progressive blank (480p/576p/720p/1080p)** — freerun
  ADV7181C programs the shared FIELD/DE pin as FIELD, which is constant
  on progressive standards and therefore useless as AVID. Standalone
  cores (`yuv444_30b`, `yuv422_20b`, `gbr444_30b`, `gbr422_20b`) now take
  only the LLC clock from the decoder and free-run
  `video_sync_generator` (`G_LOCK_TO_REF => not C_ENABLE_STANDALONE`) for
  HS/VS/AVID. Generator H/V is inverted once onto the active-low stream
  nets. NTSC/PAL `hsync_clks_*` in `video_sync_pkg` aligned to the same
  active-high pulse convention as the other 13 timings. Full-tier
  vmtest: all 15 standalone YUV timings pass with decoder sync idle.

- **YUV SD standalone 480p/576p HDMI still blank after freerun-sync fix** —
  HIL: sideloaded `colorbars` (YUV) stayed flat ~0.027 at 480p/576p while
  interlaced and HD worked; sideloaded `colorbars_rgb` (GBR) passed
  480p/576p. Root cause: any fabric mux on `vid_clk` (PLL vs ÷2, or even
  LLC vs ÷2) blanked ED on ICE40; GBR never muxes — `vid_clk <= LLC` always.
  YUV SD standalone now matches GBR (`vid_clk <= i_vid_dec_clk`; encoder
  27 MHz from LLC on ED or 2× PLL on interlaced). Firmware master-PLL
  freerun sets interlaced YUV LLC to 13.5 MHz (was 27 MHz) so the pin is
  the pixel clock for both rate classes.

- **YUV ED HDMI Style-3 422 @ 27 MHz still blank after LLC fix** — HIL
  diagnostic: configuring ADV7513 identically to working RGB ED
  (`r15=00 r16=38`) while the FPGA still drove YUV left 480p flat-black,
  so the blank is on the YUV HDMI pack path. SD standalone HDMI always
  drives 8-bit YUV444 (Y/U/V on the Style-1 pin groups) with a GBR-style
  2-cycle H/V align; firmware programs SD+ED as Input ID 0 / Style 1 /
  RGB AVI (false-color capture parity). Interlaced keeps pixel-rep ×2.

- **YUV ED still blank after Style-1 444 pack (HIL)** — ADV7513 readback
  at 480p matched working RGB (`r15/r16/DE` identical) while capture stayed
  unique=1 black (not blanking teal), so DE was not locking. Standalone
  **ED** (`is_ed` 480p/576p) now forces ADV7181C CP 12-bit DDR RGB LLC pad
  mode for YUV as well as GBR (freerun AVID does not use decoder pixels).
  Interlaced SD keeps SDR LLC (already HIL-green). HD keeps SDR LLC —
  forcing DDR for all standalone or for SD+ED poisoned first HD after SD.

- **Embedded Colorbars shipped pre-freerun-fix RTL** — HIL of the product path
  (embedded program, no sideload) blanked 8 of 15 standalone timings while the
  workspace pack passed all 15, because the generated blob predated the
  standalone freerun/HDMI RTL fixes. Colorbars rebuilt from current RTL
  (206770 B) and re-embedded. Product-path HIL now passes all 15 timings
  including 1080i60 (previously untested) with firmware-driven SD↔HD variant
  reloads and no host re-sideload.

- **All other embedded packs also predated freerun-fix RTL** — the same
  staleness applied to every shipping program except the refreshed Colorbars.
  All 27 embedded packs rebuilt from current RTL and re-embedded
  (`videomancer-1.0.0-rc.38+30`). Glorious needed `firmware.seed = 2` (nextpnr
  router assert on seed 1 for `hd_standalone`). Lumarian overflows the HX4K
  by ~20 LCs under default `synth_ice40`; `firmware.synth_opts = "-abc2"`
  recovers ~24 LCs and fits (build system now forwards the TOML field).

- **Sideloaded standalone SD↔HD left first HD blank** — `_streamed_program_active`
  made `video_timing` changes call `configure_video_chain()` only, without
  reloading the matching bitstream variant inside the .vmprog. When the
  stream was named after a registry program (e.g. `colorbars`), standalone
  timing changes that cross SD↔HD now clear the streamed latch and
  reload-by-name for the new variant. Pure `Sideload` names still need the
  host to re-stream (hil/session.py passthru bounce). The streamed bitstream
  is never retained (MCU RAM is ~98% full), so the registry reload is the
  only in-device option; firmware now logs a warning when it substitutes.

- **HDMI YUV Cb/Cr swap (rc.37 co-timing regression)** — `yuv444_30b`
  HDMI TX again drives H/V with the 444→422 converter's native 1-clk sync
  lead over Y/C. ADV7513 Style-3 + on-chip DE gen treats the first active
  sample after DE as Cb; the rc.37 1-clk H/V delay aligned sync to pixels
  and swapped Cb/Cr on HDMI out (vmtest HIL: Yellow↔Cyan, Red↔Blue). Analog
  encoder sync was already undelayed and unaffected. `gbr422` HDMI align
  pipe unchanged (RGB path).

- **video_sync_generator simulation initialization** — the ~45
  per-format threshold/table signals (and `s_timing`) had no initial
  values; until the first timing-change event they carried 'U', and the
  generator's per-clock compares flooded ~8 metavalue warnings per
  clock (~450k per 3 simulated frames). All now zero-initialize —
  synthesis-neutral (iCE40 GSR) — and the vmtest x-prop audit tier
  (IEEE asserts enabled, zero-warnings contract after a 10 us settle
  grace) holds the whole tree at zero across every config and core.

- **Sync Out processing-delay compensation direction (VMT-F004)** — the
  phase register (0x09) was applied as a true phase ADVANCE, moving the
  jack waveform earlier while the processed video it must track emerges
  later: jack sync led jack video by 2x (prog_delay + core_post),
  growing with program pipeline depth (+38 clk with howler, +54 with
  kintsugi vs the passthru baseline; clock-exact across timings). The
  generator now applies the register as a delay (subtract-with-borrow
  mirroring the rc.37 Fix C wrap), the port keeps its ABI name, and the
  firmware formula is unchanged. Validated in simulation: jack phase is
  bit-identical across passthru/howler/kintsugi in both output-sync
  domains, and the register sweep moves the waveform linearly in the
  tracking direction. Bench note: absolute jack phase moves by
  2x the passthru advance (10 clk yuv cores, 2 clk gbr422) vs prior
  builds — re-verify sync-out alignment at next bench session.
- **mycelium output timing, blanking, and range bug** — same co-timing
  class as the kintsugi fix (sync chain missing the 4-clk mix latency:
  video +4 px vs its own sync; AVID from mix-valid; video-level junk in
  blanking) plus a sim-fatal bound-check overflow in the diffusion-shift
  decode (pre-clamp intermediate exceeded `integer range 2 to 9` at low
  Diffusion with Spots). Sync/field/AVID now share one delay chain with
  the dry tap mix-latency short, outputs gate to studio blanking
  outside AVID, and `C_PROCESSING_DELAY_CLKS` declares the true total
  (36, %4-conformant). Dry-path fiducial offsets now match passthru
  exactly.
- **video_line_buffer simulation initialization** — the dual-bank RAMs
  had no initial value; before the first written line, simulation read
  'U', which poisons downstream arithmetic ('U' * 0 = 'U') — mycelium's
  entire output (including the dry mix leg) decoded as black. Both
  banks now zero-initialize, matching iCE40 EBR power-up.

- **kintsugi output timing and blanking** — three co-timing defects found
  by the vmtest processing-delay validation: (1) the dry video path runs
  through the mix interpolators (4-clk pipeline) but H/V/field bypassed
  them, so video trailed the program's own delayed sync by 4 px;
  (2) `data_out.avid` came from the mix valid chain instead of the input
  AVID delay-matched to H/V; (3) the mix interpolators free-run during
  blanking, emitting video-level junk (~Y=177 every 4th clock) across
  H-blank and VBI — which also skewed frame reconstruction by a line.
  The sync/field/AVID delay chain now includes the mix latency
  (`C_MIX_LATENCY_CLKS`), the dry tap is shortened to compensate, output
  data is gated to studio blanking outside AVID, and
  `C_PROCESSING_DELAY_CLKS` now declares the true total latency
  (28 = 24 + crack centering), which also corrects the Sync Out phase
  advance the firmware derives from it. Verified: fiducial offsets and
  blanking now match the passthru baseline exactly in simulation.

- **gbr444 HDMI-input B/R pairing (VMT-F001)** — the DE-phased B/R input mux
  led the downstream 422 phase logic's pair grid by one sample (the grid drops
  the first sample after AVID rise and pairs from the second), producing an
  exact R<->B swap on every HDMI-input `gbr444_30b` bitstream regardless of the
  receiver's DE-to-data phase. The mux phase now advances off a registered DE
  so the B slot lands on the converter's first-of-pair sample. Found and
  verified by the vmtest simulation matrix (all 8 configs x 15 timings green
  under emulated ADV7611 streams at both DE phases); `gbr422_20b` uses a
  self-consistent mux/demux grid and is intentionally unchanged. Hardware
  confirmation on an HDMI-input `passthru_rgb` loop should gate release.

### Added

- **`colorbars_rgb` diagnostic program** — direct full-range RGB/GBR444
  companion to YUV `colorbars`, with matching EBU/SMPTE, 75/100%,
  blue-only, mono, and bypass controls. Embedded as
  `videomancer_colorbars_rgb_vmprog`; standalone HIL now defaults to both
  programs across all 15 timings (30 cases) so YUV SDR and DDR RGB paths
  are validated independently.
- **`gbr422_20b` core** — GBR 4:2:2 program interface (`core_id` = 4);
  pad protocol G on Y bus / B/R on C; `passthru_gbr422` example.
- **Passthru split** — `passthru_yuv` (yuv444) and `passthru_rgb` (gbr444).
- **Embedded `passthru_rgb`** — `videomancer_passthru_rgb_vmprog` (`gbr444_30b`)
  packed into firmware alongside YUV `passthru.vmprog`.

- **Analog Out — YYY** — triple luma on all three DAC channels with sync on
  every output (ADV7393 manual CSC: R=G=B=Y, `sync_on_rgb`).
- **Analog In — YPbPr 1V** — component sampling on the 1V DC jacks (same AFE
  as RGB 1V, identity CSC / no RGB matrix).
- **Analog In — YYY 1V** — triple luma on the 1V DC jacks; ADV7181C CSC mixes
  channels with BT.601 luma weights into Y and forces neutral Cb/Cr.
- **`gbr444_30b` program core** — RGB ABI (`vmprog_core_id` = 3), HDMI RGB444
  IO policy (ADV7611/7513), example `passthru_rgb`. Analog in uses ADV7181C
  12-bit DDR RGB + FPGA soft-IDDR (`adv7181c_rgb_ddr_to_gbr444`); analog out
  stays GBR422 on Y/C into ADV7393 YCbCr digital (HD has no RGB digital in).
- **HDMI RGB888 pack (gbr444)** — TX packed from GBR444 blanking (full G/B/R),
  not from the post-422 bus (which duplicated C onto R and B).
- **HDMI RGB888 demux (gbr422)** — TX via `gbr422_20b_to_gbr444_30b` (proper
  B/R from consecutive C samples); encoder remains native GBR422.
- **Dual HDMI→encoder (gbr\*)** — C bus alternates B/R with DE phase (was B-only).
- **ADV7181C DDR policy** — `ivideo_decoder::set_rgb_ddr_output` from GBR
  `core_id`; identity CSC for RGB/YYY, YPbPr→RGB CSC for component.
- **Analog Out — SOG** — true sync-on-green-only (`r_gs_b`); **RGsB** remains
  sync on all three channels.
- **SYSTEM — Test Pattern** — ADV7393 bars/hatch toggle.
- **SYSTEM — Out Level** — Studio (EIA-770) vs Full-range ED/HD DAC levels.
- Dual/Standalone Analog In override annotations in SYSTEM menu and status.

### Changed

- **Analog Out label** — former **RGB** option renamed **RGsB** (behavior
  unchanged: RGB colorspace with sync on all channels).
- Firmware applies IO pixel format from loaded program `core_id` on
  `evt_fpga_program_loaded`.
- **Sync Out documentation** — ABI clarifies that SPI reg 0x09 *advances*
  Sync Out vs program input so the jack pre-compensates pipeline latency to
  processed video H; program video ports keep H/V on the delayed pixel pipeline.

### Fixed

- **Sync Out phase-advance line wrap (Fix C)** — when `phase_advance_clks`
  wraps `v_eff_clks` across a line boundary, line-gated compares
  (`eq_pulses`, `vsync_a/b`, AVID-V) now use `v_eff_lines` (counter lines + 1
  mod frame) so interlaced eq/VBI stay coupled to the advanced horizontal
  phase. Completes the rc.35 eq/VBI clk unification; addresses residual 1080i
  Sync Out strobing under external ramp extraction.
- **SPI reg 0x09 latch** — `sync_phase_advance_clks` latches on the same HSYNC
  edge as `video_timing_id` into a core-only register (programs still see
  only 0x00–0x08).
- **HDMI sync↔pixel co-timing** — `gbr444` HDMI RGB align pipe is +3 (matches
  444→422 *data* latency); `yuv444` / `gbr422` HDMI H/V delayed 1 clk so TX
  sync matches post-converter pixel data (encoder HSYNC may still lead data
  by 1 clk by ADV7393 design).
- **ADV7181C CP `csc_22` clobber** — removed raw IO-map `0x67=0x13` after CSC
  setup (that register is decimation/soft-filter, not clamp speed). DDR RGB
  now keeps 444 filter; YUV restores 422+soft via typed fields.
- **ADV7181C SD YPbPr lock (rc.37 follow-up)** — restore clamp average
  `none` (pre-rc.37 `0xC5=0x01` behavior; `average_1_8` slowed SOG recovery);
  apply `cp_update` only on timing *change* (was ~100 Hz double-write);
  STDI prefers LCF field counts over a flaky interlaced flag so NTSC/PAL is
  not misclassified as 480p/576p (double-wide frames / TV invalid format).
- **Datasheet Table refs** — DDR packing is Rev. E **Table 10** (Table 9 is
  ADC mux); ADV7393 CSC layout comment points at 0x03–0x09 / Table 48.

## [1.0.0-rc.35] - 2026-07-22

### Fixed

- **Sync Out eq/VBI phase advance (Fix B)** — all horizontal sync edge compares
  now use `v_eff_clks` (counter + phase advance modulo line length) uniformly
  for `hsync`, `hsync_2x`, `csync`, `csync_2x`, `eq_pulses`, `csync_serration`,
  and vsync clk events. Fixes interlaced tri-level mux misalignment that caused
  1080i Sync Out strobing on external ramp sync extraction.

### Added

- **VUnit phase-advance suite** — 15 format `_phase` configs plus
  `1080i5994_phase22`; tests for hsync edge lead, line period, and eq trisync under advance.

## [1.0.0-rc.34] - 2026-07-22

### Fixed

- **Processing-delay chroma inversion** — `processing_delay_clks` now reflects
  true `program_top` boundary latency (including IO-align). Packer validates
  ÷4 alignment; embedded programs with under-counted or odd delays corrected;
  Sync Out phase advance matches processed video H/chroma.

### Changed

- **Delay resolver** — `toml_to_config_binary.py` infers total I/O latency from
  VHDL constants, IO-align stage chains, and dry/sync pipe patterns.
- **Documentation** — `abi-format.md` and program development guide define
  `C_PROCESSING_DELAY_CLKS` as full boundary delay.

## [1.0.0-rc.33] - 2026-07-21

### Added

- **vmprog format 1.1** — `processing_delay_clks` field in program config for
  per-program pipeline delay metadata used by sync phase compensation.
- **SPI register 0x09** — `sync_phase_advance_clks` (core-only): horizontal
  phase advance in `vid_clk` pixels, written at program load.
- **`video_sync_generator` phase advance** — `G_PHASE_ADVANCE` generic and
  `phase_advance_clks` port advance horizontal sync/AVID comparisons (modulo
  line length) so sync output leads program input by pipeline latency.
  Horizontal pulse registers use level windows for `s_hsync` / `s_csync`
  when phase advance is enabled; `hsync_2x` / `csync_2x` stay edge-driven.

- **Standalone RGB 1V input sampling** — `sd_standalone` / `hd_standalone` bitstreams
  reconnect the ADV7181C 20-bit Y/C datapath and HS/VS/DE into the pipeline.
  Firmware enables RGB 1V AFE with frozen midpoint clamp while keeping manual
  CP-PLL master-clock programming (`force_master_pll`). Incoming voltages are
  assumed synchronous with the programmed timing; no FPGA → decoder external
  sync feedback.

### Changed

- **Sync output (all routing modes)** — unified program-input sync path in
  `core_top.vhd` (yuv422_20b and yuv444_30b): sync generator locks to
  `s_program_in` on `vid_clk` with `G_LOCK_TO_REF` and applies SPI reg 0x09
  phase advance (`processing_delay_clks` + core post-delay). Replaces
  per-mode routing (HDMI RX domain in Dual, free-run standalone, program-
  output lock in HDMI/Analog).

- **SPI shadow RAM latch (all bitstreams)** — `core_top.vhd` (yuv422_20b and
  yuv444_30b) latches MCU SPI register writes into program-visible shadow RAM
  on every HSYNC falling edge for **all** bitstream variants, including
  standalone. Standalone previously latched on VSYNC (field rate), which
  blocked per-line CV/Audio modulation from reaching FPGA programs. Input-
  routing bitstreams (`sd/hd_{analog,hdmi,dual}`) were already HSYNC-latched
  since SDK 0.5.1.

### Fixed

- **Sync output vs processed video alignment** — external sync jack pre-compensates
  for program-specific pipeline delay so sync out aligns with processed video
  on HDMI TX / analog enc across Analog, HDMI, Dual, and Standalone modes.
- **SD standalone 480p/576p vid_clk** — mux selects 27 MHz PLL output for ED
  progressive timings instead of always using 13.5 MHz.

## [0.5.1] - 2026-06-20

### Fixed

- **rc.26 regression — original 6 bitstream sync architecture restored**
  - Input-routing bitstreams (`sd/hd_{analog,hdmi,dual}`) again gate the video
    pipeline with external HSYNC/VSYNC/DE from the ADV7611 or ADV7181C, matching
    SDK 0.5.0 / firmware rc.25 behavior.
  - Sync generator reference for non-dual input modes restored to program output
    timing (`s_video_out`), not external input pins.
  - Shadow SPI register latch restored to HSYNC falling edge for input-routing
    modes (VSYNC latch retained for standalone only).
  - HD clock decimation path and `C_HD_CLOCK_DIVISOR` restored in `core_config`
    packages for community builds using divisor 2/4.
- **Standalone bitstreams unchanged** — `sd_standalone` / `hd_standalone` retain
  internal sync generator gating, ADV7181C LLC clock tree, and free-run sync ref.

### Changed

- `core_top.vhd` (yuv444_30b and yuv422_20b): sync/FPGA interaction is now
  bifurcated on `C_ENABLE_STANDALONE` instead of applied globally.

## [0.5.0] - 2026-04-08

### Added

- **8 Example Programs** - Moved from proprietary firmware to open-source SDK
  - `colorbars` — Reference color bar test pattern (EBU 8-bar / SMPTE+PLUGE)
  - `howler` — Video feedback loop with zoom, decay, and hue rotation
  - `kintsugi` — Gold crack-repair edge overlay
  - `mycelium` — Reaction-diffusion organic pattern growth
  - `perlin` — Gradient noise synthesizer with animated palettes
  - `pong` — Classic two-player Pong game with AI opponent
  - `sabattier` — Pseudo-solarization with Mackie line edge glow
  - `stic` — Intellivision STIC retro 16-color palette quantizer
  - SDK now ships 10 example programs (up from 2)
- **AI Program Generation Guide** - New documentation for using Claude AI to create programs
  - Step-by-step workflow: context setup, prompt structure, review checklists, build/test
  - SDK DSP library quick reference table
  - Common issues and iteration patterns

### Changed

- **Documentation Audit** - Comprehensive accuracy and consistency pass across all docs
  - Fixed entity name references: `program_yuv444` → `program_top` throughout
  - Fixed type name references: `t_video_stream_yuv444` → `t_video_stream_yuv444_30b`
  - Fixed hash algorithm descriptions: clarified BLAKE2b-256 (not SHA-256) where applicable
  - Fixed TOML value_labels syntax: corrected `[[parameter.value_label]]` sub-table → `value_labels` array
  - Fixed max label count: "256 labels" → "2–16 labels" per parameter
  - Fixed clock frequencies in CHANGELOG v0.1.0: "SD (30 MHz) / HD (80 MHz)" → "SD (27 MHz) / HD (74.25 MHz)"
  - Fixed test path in package-signing-guide: points to `tests/python/test_ed25519_signing.py`
  - Aligned Python version requirement to 3.10+ across all docs and tool READMEs
  - Expanded program examples lists from 2 to 10 in README and program-development-guide
  - Expanded project structure in CONTRIBUTING.md from 4 to 10 entries
- **TOML Schema Compliance** - All SDK program TOML files now pass schema validation
  - Added `program_type = "processing"` to all 10 programs
  - Migrated `category` (singular) → `categories` (array) in passthru and yuv_amplifier
  - All programs validated against JSON schema

## [Unreleased]

### Added

- **Multi-Category Support & Program Type** - Replaced singular category with multi-tag system
  - `categories` field: array of up to 8 category tag strings (8×32 bytes) at offset 214
  - `category_count` field: uint8_t at offset 729 (valid range 1–8)
  - `program_type` field: uint8_t at offset 7916 (0=processing, 1=synthesis)
  - New `vmprog_program_type_v1_0` enum with `processing` (0) and `synthesis` (1)
  - Struct size increased from 7372 to 7936 bytes (reserved reduced from 20 to 19 bytes)
  - 37 predefined categories validated against JSON schema
  - Moved category definitions from repository root to SDK `docs/program-categories.md`
  - All 343 program TOML files migrated from `category` string to `categories` array
  - Updated all tools (toml-converter, vmprog-packer, toml-editor) with backward compatibility
  - JSON schema updated with `categories` array and `program_type` enum constraints
- **Core Architecture Field** - Added core_id field to vmprog_program_config_v1_0
  - New `vmprog_core_id_v1_0` enum: none (0), yuv444_30b (1), yuv422_20b (2)
  - Core architecture field at offset 82 (4 bytes)
  - Struct size increased from 7368 to 7372 bytes
  - Build system parses core field from TOML and passes to Makefile
  - Updated all tools (toml-converter, vmprog-packer) to handle new field
  - Updated JSON schema with core enum validation
  - Documentation updated throughout
- **Build System Enhancements** - Added timing and resource utilization reporting
  - Extracts actual max frequency (Fmax) from nextpnr timing analysis
  - Reports resource usage: Logic Cells (LCs), IOs, RAMs, PLLs with used/max values
  - Build completion messages show: "Fmax: XX.X MHz, LCs: XXXX/YYYY, IOs: XX/YY"
  - Start messages updated to show minimum frequency requirement: "Fmin: XX MHz"
- **Clean Script** - Added clean_programs.sh for artifact cleanup
  - Removes all build artifacts from build/programs/ directory
  - Cleans packaged .vmprog files from out/ directory
  - Preserves build/ directory structure and OSS CAD Suite toolchain
  - Provides summary of files removed

### Changed

- **Parameter Control Curve API** - Enhanced to support full int32_t input range
  - Changed `apply_parameter_control_curve()` to accept `int32_t` instead of `uint16_t`
  - Changed `apply_parameter_control_curve_and_scaling()` to accept `int32_t` instead of `uint16_t`
  - Polar modes (polar_degs_90 through polar_degs_2880) now wrap around 0-1023 for out-of-range inputs
  - All non-polar modes clamp out-of-range inputs to [0, 1023] before processing
  - Wrapping is applied BEFORE clamping for polar modes to enable continuous rotation
  - Negative input handling: polar modes wrap (e.g., -100 → 924), others clamp to 0
  - Large positive handling: polar modes wrap (e.g., 1500 → 476), others clamp to 1023
  - Maintains backward compatibility - all existing uint16_t inputs work identically
  - Added comprehensive test coverage for negative inputs, wrapping behavior, and edge cases

### Fixed

- **Test Suite Buffer Overflow** - Corrected buffer overflow in parameter utility tests
  - Fixed `test_string_suffix_variations()` attempting to write 6 bytes into 4-byte suffix_label buffer
  - Changed test suffix from "units" (6 bytes with null) to "Hz" (3 bytes with null)
  - Respects suffix_label_max_length = 4 bytes as defined in vmprog_parameter_config_v1_0

## [0.4.0] - 2025-12-16

### Added

- **Parameter Control Curve Utilities** - Complete parameter transformation system
  - Added `vmprog_parameter_utils.hpp` with 36 control curve modes
  - Linear scaling modes (1x, 0.5x, 0.25x, 2x)
  - Boolean on/off threshold
  - Discrete step quantization (4, 8, 16, 32, 64, 128, 256 steps)
  - Polar/angular wrapping modes (90°, 180°, 360°, 720°, 1440°, 2880°)
  - Easing curves: quadratic, sinusoidal, circular, quintic, quartic, exponential
  - Fixed-point arithmetic for embedded systems compatibility
  - Comprehensive unit test suite with 67 tests covering all modes
- **VHDL Test Infrastructure** - VUnit-based hardware description language testing
  - Added VHDL testbenches for core RTL modules
  - Testbenches for YUV422↔YUV444 conversion, blanking, and sync modules
  - Automated VHDL testing integrated into test suite
  - Python-based VUnit test runner for hardware verification

### Changed

- **Documentation** - Improved project documentation structure
  - Cleaned up broken links and dead references
  - Minimized and reorganized documentation
  - Updated README with clearer structure

### Fixed

- **SPI Peripheral** - Corrected SPI peripheral implementation
  - Fixed errors in SPI peripheral RTL
  - Corrected SPI peripheral testbench
  - Resolved VHDL testbench issues for SPI module
- **CI/CD** - Resolved continuous integration workflow issues
  - Fixed stalling CI workflows
  - Removed slow tests causing timeouts
  - Fixed VHDL testbench execution in CI environment

## [0.3.3] - 2025-12-15

### Changed

- **Documentation** - Cleanup of GitHub CI documentation
  - Removed redundant GitHub CI readme file
  - Streamlined project documentation structure

## [0.3.2] - 2025-12-15

### Changed

- **Test Suite** - Platform compatibility improvements
  - Removed version header tests for better cross-platform compatibility
  - Removed MacOS CI tests to focus on Linux/WSL testing
  - Improved CI stability and reliability

### Added

- **Continuous Integration** - Initial CI/CD pipeline setup
  - Added GitHub Actions workflow for automated testing
  - Python test integration in CI
  - Documentation link validation

### Fixed

- **Documentation** - Fixed documentation link errors
  - Corrected broken documentation links
  - Fixed trailing whitespace issues

## [0.3.1] - 2025-12-15

### Changed

- **Documentation** - Updated test coverage documentation
  - Updated COVERAGE.md with latest test metrics
  - Minor documentation improvements

## [0.3.0] - 2025-12-15

### Added

- **Comprehensive Test Suite Expansion** - Significantly increased test coverage across all SDK headers
  - **vmprog_crypto.hpp**: Added 4 helper function tests (verify_hash, is_hash_zero, secure_compare_hash, is_pubkey_valid)
  - **vmprog_format.hpp**: Added 21 validation and utility tests covering string helpers, enum operators, endianness conversion, TOC validation, descriptor validation, parameter validation, and edge cases
  - **vmprog_stream_reader.hpp**: Added 19 integration tests with mock package setups covering config reading, signed descriptor reading, signature reading, payload verification, and complete package workflows
  - Total test count increased from 53 to 118 tests across 6 test suites
  - All tests achieve 100% pass rate

- **Ed25519 Signature Algorithm Update** - Switched from EdDSA (Blake2b) to standard Ed25519 (SHA-512)
  - Updated vmprog_crypto.hpp to use `crypto_ed25519_check` instead of `crypto_eddsa_check`
  - Implemented RFC 8032 compliant Ed25519 signature verification
  - Added RFC 8032 test vectors to validate implementation correctness
  - Maintains backward compatibility with Monocypher library

- **Integration Test Framework** - Complete mock package testing infrastructure
  - Mock package helpers for creating valid VMProg packages with config, signed descriptors, and signatures
  - End-to-end workflow tests validating entire package reading pipeline
  - Edge case testing for invalid sizes, corrupted data, overflow conditions, and boundary cases
  - Tests all 7 bitstream type variants (SD/HD analog/HDMI/dual, generic)

- **Test Documentation** - Comprehensive test suite documentation
  - tests/README.md: Complete test suite overview, organization, and running instructions
  - tests/COVERAGE.md: Detailed coverage report showing 100% header coverage
  - Test suite reorganization into cpp/, python/, and shell/ directories

### Changed

- **Test Organization** - Improved test structure and coverage
  - Reorganized tests into language-specific directories (cpp/, python/, shell/)
  - Systematic method-level coverage analysis ensuring all public APIs tested
  - Added validation tests for all VMProg format structures
  - Enhanced error condition testing for robust SDK behavior
  - Comprehensive testing of string manipulation, cryptographic, and I/O operations

- **Cryptographic API** - Updated to use RFC 8032-compliant Ed25519
  - Changed from `crypto_eddsa_check` to `crypto_ed25519_check` in vmprog_crypto.hpp
  - Signature verification now uses SHA-512 instead of Blake2b for RFC compliance
  - All existing code using the API remains compatible

### Fixed

- **Test Coverage Gaps** - Addressed untested methods across SDK headers
  - All cryptographic helper functions now thoroughly tested
  - All format validation functions tested with valid and invalid inputs
  - All stream reading functions tested with mock packages
  - Complete coverage of edge cases, overflow conditions, and error paths

## [0.2.0] - 2025-12-15

### Added

- **TOML Editor** - Browser-based visual editor for program configuration files
  - Live JSON Schema validation with detailed error reporting
  - Dual-view interface: visual form editor and raw TOML text editor
  - Real-time TOML syntax checking with ACE editor integration
  - Embedded dependencies (AJV, ACE Editor) for offline use
  - Light minimal theme optimized for usability
  - Comprehensive documentation in tools/toml-editor/README.md

- **Tool Documentation** - README files for all development tools
  - tools/toml-editor/README.md - Visual editor usage and features
  - tools/toml-converter/README.md - Binary conversion process
  - tools/toml-validator/README.md - Validation tool documentation
  - tools/vmprog-packer/README.md - Package creation and signing

- **toml-config-guide.md** - Comprehensive "how-to" guide for creating TOML configuration files
  - Complete documentation of all program metadata fields
  - Detailed explanation of numeric and label parameter modes
  - All 36 control modes with categorization (linear, stepped, polar, easing)
  - Working examples and validation instructions
  - Tips and best practices for program development

- **toml_schema_validator.py** - Standalone TOML schema validation tool
  - Validates TOML files against JSON Schema
  - Simplifies complex schema patterns for compatibility
  - Clear error reporting with locations and allowed values
  - Deduplicates validation errors for readability

### Changed

#### Documentation Organization

- **Renamed documentation files** for consistency (lowercase-with-hyphens naming)
  - signing-guide.md → package-signing-guide.md
  - toml-program-config-guide.md → toml-config-guide.md
  - vmprog-ed25519-signing.md → ed25519-signing.md
  - All cross-references updated across 13 files

- **Updated documentation content**
  - toml-config-guide.md: Added "Visual Editor (Recommended)" section
  - README.md: Fixed clean_sdk.sh → clean.sh script reference
  - keys/README.md: Corrected script paths (scripts/vmprog_pack → tools/vmprog-packer)

#### Repository Maintenance

- **.gitignore improvements** - Added Python cache patterns
  - `__pycache__/` directories
  - `*.py[cod]` compiled Python files
  - `*.so` shared objects
  - `.Python` metadata

- **Copyright headers** - Added GPL-3.0 license header to tools/toml-editor/toml-editor.html

#### TOML Configuration Format Improvements

- **String enums** - `parameter_id` and `control_mode` now use descriptive strings instead of numeric values
  - Example: `"rotary_potentiometer_1"` instead of `1`
  - Example: `"linear"` instead of `0`
  - More readable and self-documenting configurations

- **Version string formats** - Simplified version specification
  - `program_version` now uses SemVer format (e.g., `"1.2.3"`)
  - `abi_version` uses range notation (e.g., `">=1.0,<2.0"`)
  - Replaces individual numeric fields (`program_version_major`, etc.)
  - Legacy numeric format still supported for backward compatibility

- **Auto-calculated fields** - Reduced manual bookkeeping
  - `parameter_count` automatically calculated from number of `[[parameter]]` sections
  - `value_label_count` automatically calculated from `value_labels` array length
  - These fields should no longer be manually specified in TOML files

- **Signed integer display values** - Support for negative display ranges
  - `display_min_value` and `display_max_value` changed from `uint16_t` to `int16_t`
  - Range: -32768 to 32767 (previously 0 to 65535)
  - Enables display of negative values (e.g., -100 to +100 for brightness)

- **Optional fields with defaults** - Reduced TOML verbosity
  - Program fields: `author`, `license`, `category`, `description`, `url` now optional (default: empty string)
  - Parameter numeric fields: `min_value` (default: 0), `max_value` (default: 1023), `initial_value` (default: 512)
  - Parameter display fields: `display_min_value` (default: `min_value`), `display_max_value` (default: `max_value`), `display_float_digits` (default: 0)
  - Minimal valid configuration requires only `program_id`, `program_name`, version fields

#### Binary Format Changes

- **vmprog_program_config_v1_0** structure increased from 7240 to 7368 bytes
  - Added `url` field (128 bytes) for project/documentation links
  - Adjusted offsets: parameters now start at byte 502 (previously 374)
  - Updated `struct_size` constant to 7368

- **Display value storage** - Changed to signed integers
  - `display_min_value` and `display_max_value` use `int16_t` (signed)
  - Struct packing format changed from `'<H'` (unsigned) to `'<h'` (signed)

#### Validation and Constraints

- **Enhanced validation** in `toml_to_config_binary.py`
  - Unique `parameter_id` enforcement across all parameters
  - Mutual exclusivity: `value_labels` mode vs numeric fields
  - Mutual exclusivity: `value_labels` mode vs `control_mode`
  - Constraint: `min_value` < `max_value` (strictly less than)
  - Constraint: `min_value`, `max_value`, `initial_value` within 0-1023 range
  - Automatic default application for optional fields

- **JSON Schema updates** in `vmprog_program_config_schema_v1_0.json`
  - Enum validation for string-based `parameter_id` and `control_mode`
  - Pattern validation for SemVer and range notation version strings
  - Removed `hw_mask` from required fields (static value in converter)
  - Updated field descriptions to document optional fields and defaults
  - Added mutual exclusivity constraints using `if`/`then`/`not` patterns

#### Removed Fields

- **hw_mask** removed from TOML format
  - Static value `0x00000003` (rev A/B support) set automatically in converter
  - No longer user-configurable

### Fixed

- **TOML Editor bugs**
  - Fixed input focus loss on every keystroke in text fields
  - Fixed raw TOML view disappearing after view switching
  - Improved ACE editor initialization and state management

- **control_mode defaults** - Automatically set to `0` (linear) when omitted or when using `value_labels` mode
- **Schema validation compatibility** - Simplified `$data` references for broader JSON Schema library support

### Documentation

- Updated **vmprog-format.md** with new structure size, offsets, and signed integer types
- Updated **example_program_config.toml** demonstrating all new features
- Updated **passthru.toml** to use new string formats

## [0.1.0] - 2025-12-14

Initial public release of the Videomancer SDK. Complete FPGA development toolchain including format specification, C++ SDK, FPGA build chain, RTL libraries, Ed25519 package signing, and automated packaging workflow for cryptographically signed `.vmprog` packages.

### Added

#### Core SDK Components

- **vmprog_format.hpp** - Complete `.vmprog` v1.0 format specification with binary structures and validation functions
- **vmprog_crypto.hpp** - Ed25519 signature verification and BLAKE2b-256 hashing wrappers
- **vmprog_public_keys.hpp** - Ed25519 public key storage
- Header-only C++ library (C++17/20) with zero runtime dependencies

#### Binary Format Structures

- `vmprog_header_v1_0` - 64-byte file header (magic: 'VMPG', version, TOC metadata)
- `vmprog_toc_entry_v1_0` - 64-byte table of contents entries
- `vmprog_program_config_v1_0` - 7,240-byte program configuration
- `vmprog_signed_descriptor_v1_0` - 332-byte cryptographic descriptor
- `vmprog_parameter_config_v1_0` - 572-byte parameter definitions (12 parameters total)
- `vmprog_artifact_hash_v1_0` - 36-byte artifact hash entries

#### Features

- Maximum file size: 1 MB (1,048,576 bytes)
- 12 user-configurable parameters (6 rotary, 5 toggle, 1 linear)
- 36 parameter control modes (linear, stepped, polar, easing curves)
- Hardware compatibility flags (Videomancer Core rev A/B)
- ABI version range management
- 6 bitstream variants (SD/HD × analog/HDMI/dual output)
- Little-endian packed structures with UTF-8 strings

#### Cryptography

- Ed25519 digital signatures (64-byte signatures, 32-byte public keys)
- BLAKE2b-256 hashing (SHA-256 equivalent security)
- Constant-time operations and secure memory wiping
- Support for up to 8 signed artifacts per package
- Monocypher 4.0.2 cryptographic library (BSD-2-Clause OR CC0-1.0)

#### FPGA Build Chain

- **OSS CAD Suite Integration** - Yosys (with GHDL plugin), nextpnr-ice40, icepack
- **Makefile** - Automated FPGA synthesis workflow for Lattice ICE40HX4K
- Support for all 6 bitstream variants with configurable frequency
- Automatic inclusion of program VHDL, RTL libraries, and constraints
- ICE40HX4K target with TQ144 package

#### RTL VHDL Libraries

- **top.vhd** - Top-level entity (RP2040 SPI interface, video pipeline integration)
- **core.vhd** - Core video processing module (program integration point)
- **video_sync_generator.vhd** - Configurable video timing generation
- **video_timing_pkg.vhd** - Standard video timing constants (480i, 480p, 720p, 1080i)
- **video_field_detector.vhd** - Field detection for interlaced video
- **yuv422_to_yuv444.vhd** / **yuv444_to_yuv422.vhd** - YUV format converters
- **blanking_yuv444.vhd** - Blanking signal insertion
- **program_yuv444.vhd** - Program logic wrapper interface
- **spi_peripheral.vhd** - SPI peripheral for RP2040 communication
- **sync_slv.vhd** - Clock domain crossing synchronizer
- **core_pkg.vhd** - Core package with type definitions

#### Hardware Constraints

- Pin mapping for Videomancer Core rev A and rev B
- Timing constraints for SD (27 MHz) and HD (74.25 MHz) modes
- ICE40HX4K-TQ144 specific PCF files

#### Build Scripts

- **setup.sh** - One-time setup: downloads and installs OSS CAD Suite (20250523 release)
- **build_sdk.sh** - Builds SDK headers, configures CMake, generates version info
- **clean_sdk.sh** - Removes all build artifacts
- **build_programs.sh** - Complete workflow: synthesizes all 6 bitstream variants, generates config binary, packages `.vmprog` files

#### Python Tools

- **toml_to_config_binary.py** - TOML to binary converter with comprehensive validation (enum bounds, value ranges, ABI checks)
- **vmprog_pack.py** - Complete `.vmprog` packager with Ed25519 signing support (creates TOC, calculates BLAKE2b-256 hashes, validates output)
- **generate_ed25519_keys.py** - Generate Ed25519 key pairs for package signing (32-byte raw keys)
- **test_ed25519_signing.py** - Test suite for Ed25519 signing functionality
- **test_converter.py** / **test_conversion.sh** - Test suite for TOML converter
- **test_vmprog_pack.sh** - Test suite for packaging tool
- **setup_ed25519_signing.sh** - One-step signing setup script (Linux/macOS/WSL2)
- Example TOML configuration demonstrating 3 parameters
- Python 3.10+ compatibility (standard library only)
- Python `cryptography` library integration for Ed25519 operations

#### Example Programs

- **passthru** - Simple passthrough program with no parameters
  - passthru.vhd - Minimal FPGA implementation (data passthrough)
  - passthru.toml - Configuration with zero parameters
  - Demonstrates complete development workflow from VHDL to `.vmprog`

#### Build System

- CMake 3.13+ with interface library pattern
- Git-based version extraction and auto-generation
- Header-only library installation with CMake integration
- Automatic dependency management for Monocypher

#### Documentation

- **vmprog-format.md** - Complete binary format specification with diagrams and validation procedures
- **ed25519-signing.md** - Complete Ed25519 signing implementation documentation
- **vmprog_pack README.md** - Detailed documentation for packaging tool with Ed25519 signing examples
- **SIGNING_GUIDE.md** - Quick reference for daily Ed25519 usage
- **keys/README.md** - Key management and security guidelines
- README with quickstart guide, complete toolchain documentation, and Ed25519 signing examples
- CONTRIBUTING guidelines (LZX Industries maintained, external contributions case-by-case)
- THIRD_PARTY_LICENSES documentation (Monocypher, SiliconBlue ICE40 components)

### Security

- Private keys protected by `.gitignore` in `keys/` directory
- Automatic file permissions (600) set on private keys (Unix-like systems)
- Interactive confirmation required before overwriting existing keys
- Clear security warnings and documentation throughout
- Ed25519 signature generation over 332-byte signed descriptor structure
- `signed_pkg` header flag automatically set for signed packages
- Graceful fallback when `cryptography` library unavailable

### Project Information

- **License:** GPL-3.0-only
- **Copyright:** 2025 LZX Industries LLC
- **Platform:** Videomancer (RP2040 + Lattice ICE40HX4K FPGA)
- **Repository:** <https://github.com/lzxindustries/videomancer-sdk>

### Notes

**Scope of v0.1.0:**
- Complete FPGA development toolchain (setup → build → package)
- Format specification and SDK headers (complete)
- RTL VHDL libraries for video processing (complete)
- Python configuration and packaging tools with Ed25519 signing (complete)
- Automated build scripts for full workflow with signing integration (complete)
- Example program demonstrating complete development cycle (passthru)

**Stability:**
- Pre-release (0.x series) - API may evolve before 1.0
- Binary format is stable and maintains backward compatibility
- Breaking changes will increment minor version
- FPGA build chain tested with OSS CAD Suite 20250523

**Known Limitations:**
- 1 MB file size limit (sufficient for ICE40HX4K bitstreams + metadata)
- 12 parameter maximum (matches Videomancer hardware interface)
- Single Ed25519 public key for verification (additional keys require SDK update)
- Signature generation requires optional `cryptography` Python library

[Unreleased]: https://github.com/lzxindustries/videomancer-sdk/compare/sdk/0.4.0...HEAD
[0.4.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.4.0
[0.3.3]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.3.3
[0.3.2]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.3.2
[0.3.1]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.3.1
[0.3.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.3.0
[0.2.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.2.0
[0.1.0]: https://github.com/lzxindustries/videomancer-sdk/releases/tag/sdk/0.1.0

