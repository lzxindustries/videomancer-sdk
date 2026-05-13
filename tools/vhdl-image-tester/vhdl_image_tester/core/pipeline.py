# Videomancer SDK - VHDL Image Tester
# File: videomancer-sdk/tools/vhdl-image-tester/vhdl_image_tester/core/pipeline.py - Full simulation pipeline orchestrator
# Copyright (C) 2026 LZX Industries LLC. All Rights Reserved.

"""
Simulation pipeline — runs the complete VHDL image processing flow:

  1. Prepare source image (resize to simulation dimensions)
  2. Convert RGB → YUV-10bit & write stimulus.txt
  3. Generate tb_vit.vhd testbench with register values
  4. Run GHDL (analyse → elaborate → simulate)
  5. Read output.txt → convert YUV-10bit → RGB image

Two execution modes are provided:

* ``run_pipeline()``     — pure Python, no Qt dependency; suitable for CLI use.
* ``SimulationWorker``   — thin QThread wrapper around ``run_pipeline()`` for
                           the GUI, forwarding log lines via Qt signals.
"""

from __future__ import annotations

import shutil
import time
import traceback
from pathlib import Path
from typing import Callable

from PIL import Image

from .config import (
    BUILD_DIR,
    SIM_WARMUP_FRAMES,
    SIM_CAPTURE_FRAMES,
    SIM_CLK_PERIOD_NS,
    SIM_DEFAULT_VIDEO_MODE,
    SIM_DEFAULT_DECIMATION,
    SIM_DRAIN_LINES,
    ABI_REG_VIDEO_TIMING,
    resolve_video_settings,
)
from .image_converter import (
    prepare_image,
    rgb_to_yuv10,
    build_stimulus,
    write_stimulus_file,
    read_output_file,
)
from .program_loader import Program
from .testbench_gen import generate_testbench
from .sim_runner import run_simulation


# ---------------------------------------------------------------------------
# Pipeline result type
# ---------------------------------------------------------------------------


class PipelineResult:
    """Holds the outcome of a completed simulation pipeline run."""

    def __init__(
        self,
        success: bool,
        input_image: Image.Image | None = None,
        output_image: Image.Image | None = None,
        elapsed_s: float = 0.0,
        error: str = "",
        run_dir: Path | None = None,
    ) -> None:
        self.success = success
        self.input_image = input_image
        self.output_image = output_image
        self.elapsed_s = elapsed_s
        self.error = error
        self.run_dir = run_dir


# ---------------------------------------------------------------------------
# Pure-Python pipeline function (no Qt dependency)
# ---------------------------------------------------------------------------


def run_pipeline(
    program: Program,
    source_image: Image.Image,
    register_values: dict[str, int],
    video_mode: str = SIM_DEFAULT_VIDEO_MODE,
    decimation: int = SIM_DEFAULT_DECIMATION,
    warmup_frames: int = SIM_WARMUP_FRAMES,
    capture_frames: int = SIM_CAPTURE_FRAMES,
    log_callback: Callable[[str], None] = print,
    progress_callback: Callable[[int, int], None] | None = None,
    build_dir: Path | None = None,
    reuse_build: bool = False,
) -> PipelineResult:
    """Run the full VHDL simulation pipeline synchronously.

    This function has **no Qt dependency** and can be called from the CLI,
    test scripts, or any non-GUI context.

    Args:
        program:         Loaded :class:`Program` metadata.
        source_image:    PIL RGB image to process.
        register_values: Mapping of ``parameter_id`` → raw 10-bit value (0–1023).
        video_mode:      Video standard key (e.g. ``"1080p2997"``).
        decimation:      Resolution divisor (1, 2, 4, 8, 16, 32, 64).
        warmup_frames:   Frames driven before output capture begins.
        capture_frames:  Number of frames captured for output.
        log_callback:    Callable receiving log-line strings (default: ``print``).
        build_dir:       Override the GHDL build directory (default: ``BUILD_DIR/<name>``).
        reuse_build:     If True, keep existing build artefacts and only
                         re-analyse the testbench.  Dramatically faster for
                         batch processing where only the stimulus changes.

    Returns:
        A :class:`PipelineResult` with ``success``, ``input_image``,
        ``output_image``, ``elapsed_s``, ``error``, and ``run_dir``.
    """
    t0 = time.perf_counter()

    def emit(msg: str) -> None:
        log_callback(msg)

    try:
        # ── Resolve video settings ───────────────────────────────────────────
        vs = resolve_video_settings(video_mode, decimation)

        # ── Build directory ──────────────────────────────────────────────────
        # Clean stale GHDL artefacts (work library cache, object files) to
        # prevent GHDL internal errors caused by mismatched .cf entries.
        # When reuse_build is True, keep existing artefacts to avoid
        # re-analysing unchanged SDK sources on every frame.
        run_dir = build_dir or (BUILD_DIR / program.name)
        if not reuse_build and run_dir.exists():
            shutil.rmtree(run_dir)
        run_dir.mkdir(parents=True, exist_ok=True)

        stim_path = run_dir / "stimulus.txt"
        out_path = run_dir / "output.txt"
        tb_path = run_dir / "tb_vit.vhd"

        # ── 1. Prepare image ─────────────────────────────────────────────────
        emit(
            f"[1/5] Preparing image ({vs.sim_width}×{vs.sim_height} "
            f"from {vs.native_width}×{vs.native_height} ÷{decimation}"
            f"{' interlaced' if vs.is_interlaced else ''})..."
        )
        input_img = prepare_image(source_image, vs.sim_width, vs.sim_height)
        w, h = input_img.size
        emit(f"      → {w}×{h} px  config={vs.fpga_config}  timing_id={vs.timing_id}")

        # ── 2. Convert to YUV & write stimulus ──────────────────────────────
        emit(
            f"[2/5] Building stimulus "
            f"({warmup_frames + capture_frames} frames + {SIM_DRAIN_LINES} drain lines)..."
        )
        yuv10 = rgb_to_yuv10(input_img)
        stimulus = build_stimulus(
            yuv10,
            warmup_frames=warmup_frames,
            capture_frames=capture_frames,
            drain_lines=SIM_DRAIN_LINES,
            is_interlaced=vs.is_interlaced,
        )
        write_stimulus_file(stimulus, stim_path)
        emit(f"      → {len(stimulus):,} clock cycles → {stim_path.name}")

        # ── 3. Compute register array & generate testbench ───────────────────
        emit("[3/5] Generating VHDL testbench...")
        reg_array = program.build_register_array(register_values)
        # Set ABI register 8 to the video timing ID
        reg_array[ABI_REG_VIDEO_TIMING] = vs.timing_id
        generate_testbench(
            output_path=tb_path,
            stimulus_path=stim_path,
            output_img_path=out_path,
            register_values=reg_array,
            img_width=w,
            img_height=h,
            clk_period_ns=SIM_CLK_PERIOD_NS,
            warmup_frames=warmup_frames,
            is_interlaced=vs.is_interlaced,
        )
        mode_str = "interlaced" if vs.is_interlaced else "progressive"
        emit(f"      → {tb_path.name} ({mode_str} capture, {w}×{h})")
        parts = [f"reg[{i}]={v}" for i, v in enumerate(reg_array[:12])]
        emit("      Registers: " + "  ".join(parts))

        # ── 4. Run GHDL ──────────────────────────────────────────────────────
        emit("[4/5] Running GHDL simulation...")
        run_simulation(
            program_dir=program.program_dir,
            testbench_path=tb_path,
            build_dir=run_dir,
            config=vs.fpga_config,
            core=program.core,
            log_callback=emit,
            progress_callback=progress_callback,
            reuse_build=reuse_build,
        )

        # ── 5. Read output ───────────────────────────────────────────────────
        emit("[5/5] Reading simulation output...")
        if not out_path.exists() or out_path.stat().st_size == 0:
            raise RuntimeError(
                f"Output file is empty or missing: {out_path}\n"
                "The simulation may have produced no active-video output."
            )
        output_img = read_output_file(
            out_path,
            w,
            h,
            is_interlaced=vs.is_interlaced,
        )
        emit(f"      → captured {out_path.stat().st_size // 8} pixels")

        result = PipelineResult(
            success=True,
            input_image=input_img,
            output_image=output_img,
            run_dir=run_dir,
        )

    except Exception:  # noqa: BLE001
        tb_str = traceback.format_exc()
        emit(f"\n[ERROR]\n{tb_str}")
        result = PipelineResult(success=False, error=tb_str)

    result.elapsed_s = time.perf_counter() - t0
    return result


# ---------------------------------------------------------------------------
# QThread wrapper (GUI use only — imports PyQt6)
# ---------------------------------------------------------------------------


class SimulationWorker:  # type: ignore[no-redef]
    """Lazy-imported QThread wrapper so that importing this module never forces
    a PyQt6 import in CLI contexts."""


def _make_simulation_worker_class() -> type:
    """Build and return the real SimulationWorker QThread class."""
    from PyQt6.QtCore import QThread, pyqtSignal  # noqa: PLC0415

    class _SimulationWorker(QThread):
        """
        Background thread that executes ``run_pipeline()`` without blocking
        the GUI.

        Signals
        -------
        log_line(str)            : Emitted for each pipeline log line.
        progress(int, int)       : Emitted with (current_frame, total_frames).
        finished(PipelineResult) : Emitted when the pipeline completes.
        """

        log_line: pyqtSignal = pyqtSignal(str)
        progress: pyqtSignal = pyqtSignal(int, int)  # (current_frame, total_frames)
        finished: pyqtSignal = pyqtSignal(object)  # PipelineResult

        def __init__(
            self,
            program: Program,
            source_image: Image.Image,
            register_values: dict[str, int],
            video_mode: str = SIM_DEFAULT_VIDEO_MODE,
            decimation: int = SIM_DEFAULT_DECIMATION,
            warmup_frames: int = SIM_WARMUP_FRAMES,
            capture_frames: int = SIM_CAPTURE_FRAMES,
        ) -> None:
            super().__init__()
            self._program = program
            self._source_image = source_image
            self._register_values = register_values
            self._video_mode = video_mode
            self._decimation = decimation
            self._warmup_frames = warmup_frames
            self._capture_frames = capture_frames

        def run(self) -> None:
            result = run_pipeline(
                program=self._program,
                source_image=self._source_image,
                register_values=self._register_values,
                video_mode=self._video_mode,
                decimation=self._decimation,
                warmup_frames=self._warmup_frames,
                capture_frames=self._capture_frames,
                log_callback=self.log_line.emit,
                progress_callback=self.progress.emit,
            )
            self.finished.emit(result)

    return _SimulationWorker


# Replace the placeholder with the real class only when Qt is available.
# GUI code imports SimulationWorker by name; it will trigger this lazily.
class _SimulationWorkerProxy:
    """Proxy that builds the real QThread class on first instantiation."""

    _cls: type | None = None

    def __new__(cls, *args: object, **kwargs: object) -> object:
        if cls._cls is None:
            cls._cls = _make_simulation_worker_class()
        return cls._cls(*args, **kwargs)  # type: ignore[call-arg]

    # Allow isinstance / type checks to work transparently
    def __class_getitem__(cls, item: object) -> object:
        return cls


SimulationWorker = _SimulationWorkerProxy  # type: ignore[assignment,misc]
