# Videomancer SDK - VHDL Image Tester
# File: videomancer-sdk/tools/vhdl-image-tester/vhdl_image_tester/app/main_window.py - Main application window
# Copyright (C) 2026 LZX Industries LLC. All Rights Reserved.

"""
MainWindow: the top-level Qt window for the VHDL Image Tester.

Layout
------
┌─────────────────────────────────────────────────────────────────┐
│ Toolbar: [Generate ▶] [Reset]                   GHDL: v4.x      │
├─────────────┬───────────────────────────────────────────────────┤
│             │                                                     │
│  Program    │  Image Viewer (input │ output)                     │
│  Panel      │                                                     │
│  (left)     ├───────────────────────────────────────────────────┤
│             │  Register Panel (scrollable controls)              │
├─────────────┴───────────────────────────────────────────────────┤
│  Log Panel                                                       │
└─────────────────────────────────────────────────────────────────┘
"""

from __future__ import annotations

import json
import time
from datetime import datetime
from pathlib import Path

from PIL import Image
from PyQt6.QtCore import Qt, QTimer, pyqtSlot
from PyQt6.QtGui import QAction, QFont, QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QApplication,
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSizePolicy,
    QSplitter,
    QStatusBar,
    QTabWidget,
    QToolBar,
    QVBoxLayout,
    QWidget,
)

from ..core.pipeline import PipelineResult, SimulationWorker
from ..core.program_loader import (
    Program,
    add_preset_to_toml,
    delete_preset_from_toml,
    save_defaults_to_toml,
    save_preset_to_toml,
)
from ..core.sim_runner import check_ghdl_available
from .widgets.image_viewer import ImageViewer
from .widgets.log_panel import LogPanel
from .widgets.program_panel import ProgramPanel
from .widgets.register_panel import RegisterPanel


class MainWindow(QMainWindow):
    """Top-level application window."""

    WINDOW_TITLE = "Videomancer VHDL Image Tester"
    MIN_WIDTH    = 1100
    MIN_HEIGHT   = 700

    def __init__(self) -> None:
        super().__init__()
        self._worker:         SimulationWorker | None = None
        self._current_program: Program | None         = None
        self._source_image:    Image.Image | None     = None
        self._output_image:    Image.Image | None     = None
        self._register_values: dict[str, int]         = {}
        self._last_run_dir:    Path | None            = None

        self._build_ui()
        self._apply_stylesheet()
        self._check_ghdl()

    # ── UI Construction ─────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        self.setWindowTitle(self.WINDOW_TITLE)
        self.setMinimumSize(self.MIN_WIDTH, self.MIN_HEIGHT)

        # ── Central widget & root splitter ────────────────────────────────
        central = QWidget()
        self.setCentralWidget(central)
        root_v  = QVBoxLayout(central)
        root_v.setContentsMargins(4, 4, 4, 4)
        root_v.setSpacing(4)

        # ── Toolbar ───────────────────────────────────────────────────────
        toolbar = self._build_toolbar()
        root_v.addWidget(toolbar)

        # ── Horizontal splitter: left panel | right content ───────────────
        h_split = QSplitter(Qt.Orientation.Horizontal)
        h_split.setChildrenCollapsible(False)

        # Left: program panel
        self._program_panel = ProgramPanel()
        self._program_panel.setFixedWidth(270)
        self._program_panel.program_changed.connect(self._on_program_changed)
        self._program_panel.image_changed.connect(self._on_image_changed)
        self._program_panel.programs_root_changed.connect(self._on_programs_root_changed)
        h_split.addWidget(self._program_panel)

        # Right: vertical splitter (image viewer + register panel)
        right_v_split = QSplitter(Qt.Orientation.Vertical)
        right_v_split.setChildrenCollapsible(False)

        # Image viewer (top right)
        self._image_viewer = ImageViewer()
        right_v_split.addWidget(self._image_viewer)

        # Register panel tab (bottom right)
        reg_tab = QTabWidget()
        reg_tab.setTabPosition(QTabWidget.TabPosition.North)

        reg_widget = QWidget()
        reg_inner  = QVBoxLayout(reg_widget)
        reg_inner.setContentsMargins(4, 4, 4, 4)
        reg_inner.setSpacing(4)

        reg_header = QHBoxLayout()
        reg_header.addWidget(QLabel("<b>Control Registers</b>"))
        reg_header.addStretch()
        reg_inner.addLayout(reg_header)

        self._register_panel = RegisterPanel()
        self._register_panel.registers_changed.connect(self._on_registers_changed)
        self._register_panel.preset_loaded.connect(self._on_preset_loaded)
        self._register_panel.save_preset_requested.connect(self._on_save_preset)
        self._register_panel.new_preset_requested.connect(self._on_new_preset)
        self._register_panel.delete_preset_requested.connect(self._on_delete_preset)
        self._register_panel.save_defaults_requested.connect(self._on_save_defaults)
        reg_inner.addWidget(self._register_panel)

        reg_tab.addTab(reg_widget, "Registers")
        right_v_split.addWidget(reg_tab)
        right_v_split.setSizes([450, 220])

        h_split.addWidget(right_v_split)
        h_split.setSizes([270, 900])

        root_v.addWidget(h_split, stretch=3)

        # ── Log panel ─────────────────────────────────────────────────────
        self._log_panel = LogPanel()
        self._log_panel.setMinimumHeight(120)
        self._log_panel.setMaximumHeight(260)
        root_v.addWidget(self._log_panel, stretch=1)

        # ── Status bar ────────────────────────────────────────────────────
        self._status_bar = self.statusBar()
        self._progress   = QProgressBar()
        self._progress.setRange(0, 0)
        self._progress.setFixedWidth(220)
        self._progress.setTextVisible(True)
        self._progress.setVisible(False)
        self._progress.setStyleSheet(
            "QProgressBar { background: #2a2a2a; border: 1px solid #444; "
            "border-radius: 3px; text-align: center; color: #e0e0e0; font-size: 11px; }"
            "QProgressBar::chunk { background: #4a90d9; border-radius: 2px; }"
        )
        self._status_bar.addPermanentWidget(self._progress)

        # Progress bar chunk colours
        self._PROGRESS_STYLE_WARMUP = (
            "QProgressBar { background: #2a2a2a; border: 1px solid #444; "
            "border-radius: 3px; text-align: center; color: #e0e0e0; font-size: 11px; }"
            "QProgressBar::chunk { background: #c8a828; border-radius: 2px; }"
        )
        self._PROGRESS_STYLE_CAPTURE = (
            "QProgressBar { background: #2a2a2a; border: 1px solid #444; "
            "border-radius: 3px; text-align: center; color: #e0e0e0; font-size: 11px; }"
            "QProgressBar::chunk { background: #4a90d9; border-radius: 2px; }"
        )

        # Smooth progress interpolation state
        self._frame_times: list[float] = []   # monotonic timestamps per frame completion
        self._sim_start_time: float = 0.0
        self._last_frame: int = 0
        self._total_frames: int = 0
        self._warmup_frames: int = 0
        self._in_warmup: bool = True
        self._est_frame_secs: float = 0.0     # estimated seconds per frame
        self._interp_timer = QTimer(self)
        self._interp_timer.setInterval(100)
        self._interp_timer.timeout.connect(self._on_interp_tick)
        self._status_lbl = QLabel("Ready")
        self._status_bar.addWidget(self._status_lbl)

        # Replay initial selections — signals fired during ProgramPanel.__init__
        # were emitted before any slots were connected.
        self._program_panel.initialize()

    def _build_toolbar(self) -> QWidget:
        bar = QWidget()
        bar.setObjectName("toolbar")
        bar.setFixedHeight(44)

        layout = QHBoxLayout(bar)
        layout.setContentsMargins(6, 4, 6, 4)
        layout.setSpacing(8)

        # Generate button
        self._generate_btn = QPushButton("▶  Generate")
        self._generate_btn.setFixedWidth(120)
        self._generate_btn.setFixedHeight(34)
        self._generate_btn.setDefault(True)
        self._generate_btn.setToolTip("Run VHDL simulation (F5)")
        self._generate_btn.clicked.connect(self._on_generate)
        layout.addWidget(self._generate_btn)

        # Abort button
        self._abort_btn = QPushButton("■  Abort")
        self._abort_btn.setFixedWidth(90)
        self._abort_btn.setFixedHeight(34)
        self._abort_btn.setEnabled(False)
        self._abort_btn.clicked.connect(self._on_abort)
        layout.addWidget(self._abort_btn)

        layout.addSpacing(8)

        # Save output image
        self._save_result_btn = QPushButton("Save Result")
        self._save_result_btn.setFixedHeight(34)
        self._save_result_btn.setEnabled(False)
        self._save_result_btn.setToolTip("Save the latest output image (Ctrl+S)")
        self._save_result_btn.clicked.connect(self._on_save_result)
        layout.addWidget(self._save_result_btn)

        # Export registers to JSON
        self._export_regs_btn = QPushButton("Export Regs")
        self._export_regs_btn.setFixedHeight(34)
        self._export_regs_btn.setToolTip("Export current register values to a JSON file")
        self._export_regs_btn.clicked.connect(self._on_export_registers)
        layout.addWidget(self._export_regs_btn)

        # Import registers from JSON
        self._import_regs_btn = QPushButton("Import Regs")
        self._import_regs_btn.setFixedHeight(34)
        self._import_regs_btn.setToolTip("Load register values from a JSON file")
        self._import_regs_btn.clicked.connect(self._on_import_registers)
        layout.addWidget(self._import_regs_btn)

        layout.addStretch()

        # GHDL version indicator
        self._ghdl_lbl = QLabel("Checking GHDL…")
        self._ghdl_lbl.setStyleSheet("color: #888; font-size: 11px;")
        layout.addWidget(self._ghdl_lbl)

        # F5 shortcut
        sc = QShortcut(QKeySequence("F5"), self)
        sc.activated.connect(self._on_generate)

        # Ctrl+S shortcut for save
        save_sc = QShortcut(QKeySequence("Ctrl+S"), self)
        save_sc.activated.connect(self._on_save_result)

        return bar

    # ── Stylesheet ───────────────────────────────────────────────────────────

    def _apply_stylesheet(self) -> None:
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background: #1d1d1d;
                color: #e0e0e0;
            }
            QGroupBox {
                border: 1px solid #3a3a3a;
                border-radius: 4px;
                margin-top: 8px;
                padding-top: 4px;
                font-weight: bold;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 8px;
                padding: 0 4px;
            }
            QComboBox, QSpinBox {
                background: #2a2a2a;
                border: 1px solid #444;
                border-radius: 3px;
                padding: 2px 5px;
                color: #e0e0e0;
            }
            QComboBox::drop-down { border: none; }
            QComboBox QAbstractItemView {
                background: #2a2a2a;
                selection-background-color: #3b5a7e;
            }
            QPushButton {
                background: #2e4a66;
                border: 1px solid #4a7aaa;
                border-radius: 4px;
                padding: 4px 10px;
                color: #e8f0ff;
            }
            QPushButton:hover  { background: #3b5a7e; }
            QPushButton:pressed { background: #1d3550; }
            QPushButton:disabled { background: #2a2a2a; color: #555; border-color: #333; }
            QPushButton#generate_btn {
                background: #1e6b3c;
                border-color: #3aaa77;
                font-weight: bold;
                font-size: 14px;
            }
            QPushButton#generate_btn:hover { background: #2a8a50; }
            QSlider::groove:horizontal {
                height: 4px;
                background: #333;
                border-radius: 2px;
            }
            QSlider::handle:horizontal {
                width: 12px; height: 12px;
                margin: -4px 0;
                border-radius: 6px;
                background: #4a90d9;
            }
            QSlider::sub-page:horizontal { background: #4a90d9; border-radius: 2px; }
            QScrollBar:vertical {
                width: 8px; background: #1a1a1a;
            }
            QScrollBar::handle:vertical { background: #444; border-radius: 4px; min-height: 20px; }
            QTabWidget::pane { border: 1px solid #333; }
            QTabBar::tab {
                background: #252525; color: #aaa;
                padding: 4px 12px; border: 1px solid #333;
            }
            QTabBar::tab:selected { background: #1d1d1d; color: #e0e0e0; }
            QSplitter::handle { background: #2d2d2d; }
            QCheckBox::indicator {
                width: 16px; height: 16px;
                border: 1px solid #555; border-radius: 3px;
                background: #2a2a2a;
            }
            QCheckBox::indicator:checked { background: #4a90d9; }
            QLabel#toolbar { background: #252525; border-bottom: 1px solid #333; }
            QStatusBar { background: #222; color: #888; font-size: 11px; }
        """)

        # Style the generate button specifically
        self._generate_btn.setObjectName("generate_btn")

    # ── GHDL availability check ──────────────────────────────────────────────

    def _check_ghdl(self) -> None:
        QTimer.singleShot(100, self._do_check_ghdl)

    def _do_check_ghdl(self) -> None:
        ok, version, backend = check_ghdl_available()
        if ok:
            badge = f"✓ {version} [{backend}]"
            self._ghdl_lbl.setText(badge)
            if backend in ("llvm", "gcc"):
                self._ghdl_lbl.setStyleSheet("color: #5c5; font-size: 11px;")
            else:
                # mcode works but is slower — amber hint
                self._ghdl_lbl.setStyleSheet("color: #cc5; font-size: 11px;")
                self._log_panel.append(
                    "[INFO] GHDL is using the mcode (interpreter) backend.\n"
                    "For 5–20× faster simulation install the LLVM backend:\n"
                    "  Ubuntu/Debian:  sudo apt install ghdl-llvm\n"
                    "  macOS:          brew install ghdl\n"
                )
        else:
            self._ghdl_lbl.setText("✗ GHDL not found")
            self._ghdl_lbl.setStyleSheet("color: #c55; font-size: 11px;")
            self._log_panel.append(
                "[WARNING] GHDL not found on PATH.\n"
                "For best performance install the LLVM backend:\n"
                "  Ubuntu/Debian:  sudo apt install ghdl-llvm\n"
                "  macOS:          brew install ghdl\n"
                "  Any platform:   download OSS CAD Suite from\n"
                "                  https://github.com/YosysHQ/oss-cad-suite-build/releases\n"
                "Simulation will fail without GHDL."
            )

    # ── Slots ────────────────────────────────────────────────────────────────

    @pyqtSlot(object)
    def _on_program_changed(self, program: Program) -> None:
        if program is None:
            self._current_program = None
            self._register_panel.load_program(None)
            self._image_viewer.clear_output()
            self.setWindowTitle(self.WINDOW_TITLE)
            return
        self._current_program = program
        self._register_panel.load_program(program)
        self._register_values = self._register_panel.current_values
        self._image_viewer.clear_output()
        self.setWindowTitle(f"{self.WINDOW_TITLE} — {program.display_name}")
        self._log_panel.append(
            f"\n\u2500\u2500 Program loaded: {program.display_name} ({program.program_id}) \u2500\u2500\n"
            f"   Category: {program.category}   Core: {program.core}\n"
            f"   {len(program.parameters)} parameters   {len(program.vhd_files)} VHDL files"
            f"   {len(program.presets)} preset(s)"
        )

    @pyqtSlot(object)
    def _on_programs_root_changed(self, path: Path) -> None:
        self._log_panel.append(
            f"\n\u2500\u2500 Programs folder changed \u2500\u2500\n"
            f"   {path}\n"
            f"   {len(self._program_panel._programs)} program(s) found"
        )
        self._status_lbl.setText(f"Programs: {path.name}")

    @pyqtSlot(object)
    def _on_image_changed(self, path: Path) -> None:
        try:
            img = Image.open(path)
            self._source_image = img
            self._image_viewer.set_input(img)
            self._log_panel.append(
                f"── Image selected: {path.name} ({img.width}×{img.height} px) ──"
            )
        except Exception as exc:  # noqa: BLE001
            self._log_panel.append(f"[ERROR] Could not open image {path}: {exc}")

    @pyqtSlot(dict)
    def _on_registers_changed(self, values: dict[str, int]) -> None:
        self._register_values = values

    @pyqtSlot(str)
    def _on_preset_loaded(self, name: str) -> None:
        self._register_values = self._register_panel.current_values
        self._log_panel.append(f"── Preset loaded: {name} ──")

    @pyqtSlot(int, dict, str)
    def _on_save_preset(self, preset_index: int, values: dict, name: str) -> None:
        if self._current_program is None:
            return
        try:
            save_preset_to_toml(self._current_program, preset_index, values, name)
            self._log_panel.append(
                f'── Preset saved: "{name}" → {self._current_program.toml_path.name} ──'
            )
            self._status_lbl.setText(f'Preset "{name}" saved')
        except Exception as exc:  # noqa: BLE001
            self._log_panel.append(f"[ERROR] Failed to save preset: {exc}")
            QMessageBox.warning(self, "Save Failed", f"Could not save preset:\n{exc}")

    @pyqtSlot(dict)
    def _on_save_defaults(self, values: dict) -> None:
        if self._current_program is None:
            return
        try:
            save_defaults_to_toml(self._current_program, values)
            self._log_panel.append(
                f"── Default settings saved → "
                f"{self._current_program.toml_path.name} ──"
            )
            self._status_lbl.setText("Default settings saved")
        except Exception as exc:  # noqa: BLE001
            self._log_panel.append(f"[ERROR] Failed to save defaults: {exc}")
            QMessageBox.warning(
                self, "Save Failed", f"Could not save default settings:\n{exc}"
            )

    @pyqtSlot(str, dict)
    def _on_new_preset(self, name: str, values: dict) -> None:
        if self._current_program is None:
            return
        try:
            idx = add_preset_to_toml(self._current_program, name, values)
            self._register_panel.reload_presets_after_add(idx)
            self._log_panel.append(
                f'── New preset "{name}" added to '
                f'{self._current_program.toml_path.name} ──'
            )
            self._status_lbl.setText(f'Preset "{name}" created')
        except Exception as exc:  # noqa: BLE001
            self._log_panel.append(f"[ERROR] Failed to add preset: {exc}")
            QMessageBox.warning(self, "New Preset Failed", f"Could not add preset:\n{exc}")

    @pyqtSlot(int)
    def _on_delete_preset(self, preset_index: int) -> None:
        if self._current_program is None:
            return
        if preset_index < 0 or preset_index >= len(self._current_program.presets):
            return
        name = self._current_program.presets[preset_index].name
        reply = QMessageBox.question(
            self,
            "Delete Preset",
            f'Delete preset "{name}"?\n\nThis will modify the TOML file on disk.',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        try:
            delete_preset_from_toml(self._current_program, preset_index)
            self._register_panel.reload_presets_after_delete()
            self._log_panel.append(
                f'── Preset "{name}" deleted from '
                f'{self._current_program.toml_path.name} ──'
            )
            self._status_lbl.setText(f'Preset "{name}" deleted')
        except Exception as exc:  # noqa: BLE001
            self._log_panel.append(f"[ERROR] Failed to delete preset: {exc}")
            QMessageBox.warning(
                self, "Delete Failed", f"Could not delete preset:\n{exc}"
            )

    @pyqtSlot()
    def _on_generate(self) -> None:
        if self._worker is not None and self._worker.isRunning():
            return  # Already running

        if self._current_program is None:
            QMessageBox.warning(self, "No Program", "Please select an FPGA program first.")
            return

        if self._source_image is None:
            QMessageBox.warning(self, "No Image", "Please select a test image first.")
            return

        self._image_viewer.clear_output()
        self._log_panel.clear()
        self._log_panel.append(
            f"{'='*60}\n"
            f"  Generating: {self._current_program.display_name}\n"
            f"  Video mode: {self._program_panel.video_mode}   "
            f"Decimation: ÷{self._program_panel.decimation}\n"
            f"{'='*60}"
        )
        self._set_running(True, warmup_frames=self._program_panel.warmup_frames)

        self._worker = SimulationWorker(
            program         = self._current_program,
            source_image    = self._source_image,
            register_values = dict(self._register_values),
            video_mode      = self._program_panel.video_mode,
            decimation      = self._program_panel.decimation,
            warmup_frames   = self._program_panel.warmup_frames,
            write_waveform  = self._program_panel.write_waveform,
        )
        self._worker.log_line.connect(self._on_log_line)
        self._worker.progress.connect(self._on_progress)
        self._worker.finished.connect(self._on_simulation_finished)
        self._worker.start()

    @pyqtSlot()
    def _on_abort(self) -> None:
        if self._worker and self._worker.isRunning():
            self._worker.terminate()
            self._worker.wait(2000)
            self._set_running(False)
            self._log_panel.append("\n[ABORTED] Simulation was aborted by user.")
            self._log_panel.set_status("Aborted", "#c55")
            self._status_lbl.setText("Aborted")

    @pyqtSlot(str)
    def _on_log_line(self, line: str) -> None:
        self._log_panel.append(line)

    @pyqtSlot(int, int)
    def _on_progress(self, current_frame: int, total_frames: int) -> None:
        """Update progress with per-frame timing estimation and smooth interpolation.

        ``VIT_FRAME: N/T`` fires at the **start** of frame N (vsync falling
        edge), so ``current_frame`` means "frame N just began rendering".
        Completed frames = ``current_frame - 1``.

        The frame-1 callback includes GHDL compilation/elaboration overhead
        and is not representative of actual rendering speed.  The true
        per-frame estimate is derived from subsequent frame deltas.
        """
        if total_frames <= 0:
            return

        now = time.monotonic()
        self._total_frames = total_frames
        # completed = frames fully rendered so far
        completed = current_frame - 1
        self._last_frame = completed
        self._frame_times.append(now)

        # Switch bar colour when we leave warmup
        if self._in_warmup and current_frame > self._warmup_frames:
            self._in_warmup = False
            self._progress.setStyleSheet(self._PROGRESS_STYLE_CAPTURE)

        n = len(self._frame_times)
        if n >= 3:
            # Use only post-frame-1 timings (skip startup overhead)
            render_elapsed = self._frame_times[-1] - self._frame_times[1]
            render_frames = n - 2
            if render_frames > 0:
                self._est_frame_secs = render_elapsed / render_frames
        elif n == 2:
            # Frame-1→frame-2 delta — first real per-frame measurement
            self._est_frame_secs = self._frame_times[1] - self._frame_times[0]

        if self._est_frame_secs > 0 and not self._interp_timer.isActive():
            self._interp_timer.start()

        # Use 1000 ticks for smooth sub-frame progress
        self._progress.setRange(0, total_frames * 1000)
        self._progress.setValue(completed * 1000)
        self._update_progress_text(completed, 0.0)

    def _on_interp_tick(self) -> None:
        """Interpolate progress between frame callbacks for smooth bar movement."""
        if self._est_frame_secs <= 0 or self._total_frames <= 0:
            return

        now = time.monotonic()
        time_since_last = now - self._frame_times[-1]
        frac = min(time_since_last / self._est_frame_secs, 0.95)
        effective_frame = self._last_frame + frac

        bar_val = int(effective_frame * 1000)
        bar_max = self._total_frames * 1000
        self._progress.setValue(min(bar_val, bar_max))
        self._update_progress_text(self._last_frame, frac)

    def _update_progress_text(self, frame: int, frac: float) -> None:
        """Set the progress bar format string and status label with ETA."""
        total = self._total_frames
        effective = frame + frac
        pct = min(int(100 * effective / total), 99) if total > 0 else 0

        # ETA — only show once we have a reliable estimate (after frame 2)
        eta_str = ""
        if self._est_frame_secs > 0 and len(self._frame_times) >= 2:
            remaining = (total - effective) * self._est_frame_secs
            if remaining >= 60:
                mins = int(remaining) // 60
                secs = int(remaining) % 60
                eta_str = f"  ~{mins}m {secs:02d}s left"
            elif remaining >= 1:
                eta_str = f"  ~{int(remaining + 0.5)}s left"
            else:
                eta_str = "  <1s left"

        phase = "  warmup" if self._in_warmup else ""
        self._progress.setFormat(f"{pct}%{eta_str}{phase}")
        self._status_lbl.setText(
            f"Simulating… frame {frame}/{total}{eta_str}{phase}"
        )

    @pyqtSlot(object)
    def _on_simulation_finished(self, result: PipelineResult) -> None:
        self._set_running(False)
        self._worker = None

        if result.success:
            assert result.input_image  is not None
            assert result.output_image is not None
            self._image_viewer.set_input(result.input_image)
            self._image_viewer.set_output(result.output_image)
            self._output_image = result.output_image
            self._last_run_dir = result.run_dir
            self._save_result_btn.setEnabled(True)
            elapsed = f"{result.elapsed_s:.1f}s"
            msg = f"✓ Done in {elapsed}"
            self._log_panel.set_status(msg, "#5c5")
            self._status_lbl.setText(msg)
            self._log_panel.append(f"\n── Simulation complete in {elapsed} ──")

            # Auto-save output to run directory
            if result.run_dir is not None and result.output_image is not None:
                auto_path = result.run_dir / "result.png"
                result.output_image.save(str(auto_path))
                self._log_panel.append(f"   Auto-saved: {auto_path}")
        else:
            msg = "✗ Simulation failed — see log"
            self._log_panel.set_status(msg, "#c55")
            self._status_lbl.setText(msg)

    @pyqtSlot()
    def _on_save_result(self) -> None:
        if self._output_image is None:
            return
        name = self._current_program.name if self._current_program else "output"
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        default_name = f"{name}_{ts}.png"
        path_str, _ = QFileDialog.getSaveFileName(
            self, "Save Output Image", default_name,
            "PNG (*.png);;JPEG (*.jpg);;TIFF (*.tif)"
        )
        if path_str:
            self._output_image.save(path_str)
            self._log_panel.append(f"── Saved output image: {path_str} ──")

    @pyqtSlot()
    def _on_export_registers(self) -> None:
        if not self._current_program:
            QMessageBox.warning(self, "No Program", "Load a program first.")
            return
        values = self._register_panel.current_values
        name = self._current_program.name
        default_name = f"{name}_registers.json"
        path_str, _ = QFileDialog.getSaveFileName(
            self, "Export Registers", default_name, "JSON (*.json)"
        )
        if path_str:
            export_data = {
                "program": name,
                "program_name": self._current_program.display_name,
                "video_mode": self._program_panel.video_mode,
                "decimation": self._program_panel.decimation,
                "registers": values,
                "register_array": self._current_program.build_register_array(values),
            }
            Path(path_str).write_text(
                json.dumps(export_data, indent=2), encoding="utf-8"
            )
            self._log_panel.append(f"── Exported registers: {path_str} ──")

    @pyqtSlot()
    def _on_import_registers(self) -> None:
        path_str, _ = QFileDialog.getOpenFileName(
            self, "Import Registers", "", "JSON (*.json)"
        )
        if not path_str:
            return
        try:
            data = json.loads(Path(path_str).read_text(encoding="utf-8"))
            regs = data.get("registers", {})
            if not isinstance(regs, dict):
                raise ValueError("Invalid register data")
            self._register_panel.set_values(regs)
            self._log_panel.append(f"── Imported registers from {path_str} ──")
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "Import Error", f"Could not import: {exc}")

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _set_running(self, running: bool, warmup_frames: int = 0) -> None:
        self._generate_btn.setEnabled(not running)
        self._abort_btn.setEnabled(running)
        self._progress.setVisible(running)
        if running:
            total_frames = warmup_frames + 1
            # Reset timing state
            self._frame_times.clear()
            self._sim_start_time = time.monotonic()
            self._last_frame = 0
            self._total_frames = total_frames
            self._warmup_frames = warmup_frames
            self._in_warmup = True
            self._est_frame_secs = 0.0
            # Start at 0% with warmup (yellow) colour
            self._progress.setStyleSheet(self._PROGRESS_STYLE_WARMUP)
            if total_frames > 0:
                self._progress.setRange(0, total_frames * 1000)
                self._progress.setValue(0)
                self._progress.setFormat("0%  warmup")
            else:
                self._progress.setRange(0, 0)
                self._progress.setFormat("")
            self._log_panel.set_status("Running simulation…", "#fa0")
            self._status_lbl.setText("Running…")
        else:
            self._interp_timer.stop()
