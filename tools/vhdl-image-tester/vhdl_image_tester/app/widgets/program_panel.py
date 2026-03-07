# Videomancer SDK - VHDL Image Tester
# File: videomancer-sdk/tools/vhdl-image-tester/vhdl_image_tester/app/widgets/program_panel.py - Program & image source selection
# Copyright (C) 2026 LZX Industries LLC. All Rights Reserved.

"""
ProgramPanel: composite widget for selecting:
  - FPGA program (dropdown populated from programs/)
  - Test image source (dropdown + browse, populated from docs/test_images/)
  - Video mode (15 ABI standards)
  - Decimation (resolution divisor)
  - Warmup frames (0+, with +/− buttons)
"""

from __future__ import annotations

from pathlib import Path

from PyQt6.QtCore import Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSizePolicy,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)

from ...core.config import (
    DECIMATION_VALUES,
    PROGRAMS_ROOT,
    SIM_DEFAULT_DECIMATION,
    SIM_DEFAULT_VIDEO_MODE,
    TEST_IMAGES_ROOT,
    VIDEO_MODES,
    VIDEO_MODE_KEYS,
    resolve_video_settings,
)
from ...core.image_converter import collect_test_images
from ...core.program_loader import Program, list_programs, load_program
from .combo_fix import fix_combo_popup


class ProgramPanel(QWidget):
    """Left side-panel: program + image selection."""

    # Emitted when the user selects a new program (fully loaded)
    program_changed: pyqtSignal = pyqtSignal(object)  # Program
    # Emitted when the selected image path changes
    image_changed: pyqtSignal = pyqtSignal(object)    # Path
    # Emitted when the programs folder is changed by the user
    programs_root_changed: pyqtSignal = pyqtSignal(object)  # Path

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._programs: list[str] = []
        self._images:   list[Path] = []
        self._current_program: Program | None = None
        self._custom_image_path: Path | None = None
        self._programs_root: Path = PROGRAMS_ROOT
        self._build_ui()
        self._populate_programs()
        self._populate_images()

    # ── Public API ──────────────────────────────────────────────────────────

    @property
    def selected_program(self) -> Program | None:
        return self._current_program

    @property
    def programs_root(self) -> Path:
        """Currently selected programs source folder."""
        return self._programs_root

    @programs_root.setter
    def programs_root(self, path: Path) -> None:
        """Change the programs source folder and repopulate the dropdown."""
        self._programs_root = path
        self._update_folder_label()
        self._populate_programs()
        self.programs_root_changed.emit(path)

    @property
    def selected_image_path(self) -> Path | None:
        idx = self._img_combo.currentIndex()
        data = self._img_combo.itemData(idx)
        if isinstance(data, Path):
            return data
        return self._custom_image_path

    @property
    def video_mode(self) -> str:
        return self._video_mode_combo.currentData()

    @property
    def decimation(self) -> int:
        return self._decimation_combo.currentData()

    @property
    def warmup_frames(self) -> int:
        return self._warmup_spin.value()

    @property
    def write_waveform(self) -> bool:
        return self._waveform_write.isChecked()

    # ── UI Construction ─────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(6, 6, 6, 6)
        root.setSpacing(8)

        # ── Program selection ────────────────────────────────────────────────
        prog_group = QGroupBox("FPGA Program")
        prog_layout = QVBoxLayout(prog_group)

        # Programs folder selector row
        folder_row = QHBoxLayout()
        folder_row.setSpacing(4)
        folder_lbl = QLabel("Folder:")
        folder_lbl.setStyleSheet("color:#888; font-size:10px;")
        folder_lbl.setFixedWidth(40)
        folder_row.addWidget(folder_lbl)

        self._folder_path_lbl = QLabel()
        self._folder_path_lbl.setStyleSheet(
            "color:#99b; font-size:10px; background:#222; "
            "border:1px solid #383838; border-radius:2px; padding:1px 4px;"
        )
        self._folder_path_lbl.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self._folder_path_lbl.setToolTip(str(self._programs_root))
        self._update_folder_label()
        folder_row.addWidget(self._folder_path_lbl)

        self._folder_browse_btn = QPushButton("…")
        self._folder_browse_btn.setFixedWidth(26)
        self._folder_browse_btn.setFixedHeight(20)
        self._folder_browse_btn.setToolTip("Browse for a programs folder")
        self._folder_browse_btn.clicked.connect(self._on_browse_programs_folder)
        folder_row.addWidget(self._folder_browse_btn)

        prog_layout.addLayout(folder_row)

        self._prog_combo = QComboBox()
        self._prog_combo.setMinimumWidth(200)
        self._prog_combo.currentIndexChanged.connect(self._on_program_changed)
        fix_combo_popup(self._prog_combo)
        prog_layout.addWidget(self._prog_combo)

        self._prog_desc = QLabel()
        self._prog_desc.setWordWrap(True)
        self._prog_desc.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)
        self._prog_desc.setStyleSheet("color: #aaa; font-size: 11px;")
        self._prog_desc.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum)
        prog_layout.addWidget(self._prog_desc)

        root.addWidget(prog_group)

        # ── Image source ─────────────────────────────────────────────────────
        img_group = QGroupBox("Test Image")
        img_layout = QVBoxLayout(img_group)

        self._img_combo = QComboBox()
        self._img_combo.currentIndexChanged.connect(self._on_image_changed)
        fix_combo_popup(self._img_combo)
        img_layout.addWidget(self._img_combo)

        browse_row = QHBoxLayout()
        self._browse_btn = QPushButton("Browse…")
        self._browse_btn.clicked.connect(self._on_browse)
        browse_row.addWidget(self._browse_btn)
        browse_row.addStretch()
        img_layout.addLayout(browse_row)

        self._img_preview = QLabel()
        self._img_preview.setFixedHeight(120)
        self._img_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._img_preview.setStyleSheet("background:#1a1a1a; border:1px solid #444;")
        img_layout.addWidget(self._img_preview)

        root.addWidget(img_group)

        # ── Simulation settings ───────────────────────────────────────────────
        sim_group = QGroupBox("Simulation Settings")
        sim_form = QFormLayout(sim_group)
        sim_form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._video_mode_combo = QComboBox()
        default_idx = 0
        for i, key in enumerate(VIDEO_MODE_KEYS):
            mode = VIDEO_MODES[key]
            self._video_mode_combo.addItem(mode.display_name, key)
            if key == SIM_DEFAULT_VIDEO_MODE:
                default_idx = i
        self._video_mode_combo.setCurrentIndex(default_idx)
        self._video_mode_combo.currentIndexChanged.connect(self._on_video_settings_changed)
        fix_combo_popup(self._video_mode_combo)
        sim_form.addRow("Video mode:", self._video_mode_combo)

        self._decimation_combo = QComboBox()
        default_dec_idx = 0
        for i, d in enumerate(DECIMATION_VALUES):
            self._decimation_combo.addItem(f"÷{d}", d)
            if d == SIM_DEFAULT_DECIMATION:
                default_dec_idx = i
        self._decimation_combo.setCurrentIndex(default_dec_idx)
        self._decimation_combo.currentIndexChanged.connect(self._on_video_settings_changed)
        fix_combo_popup(self._decimation_combo)
        sim_form.addRow("Decimation:", self._decimation_combo)

        self._resolution_lbl = QLabel()
        self._resolution_lbl.setStyleSheet("color: #8ab; font-size: 11px;")
        sim_form.addRow("Resolution:", self._resolution_lbl)
        self._update_resolution_label()

        warmup_row = QHBoxLayout()
        warmup_row.setContentsMargins(0, 0, 0, 0)
        warmup_row.setSpacing(2)

        self._warmup_minus = QPushButton("−")
        self._warmup_minus.setFixedSize(24, 24)
        self._warmup_minus.clicked.connect(lambda: self._warmup_spin.setValue(
            max(0, self._warmup_spin.value() - 1)))

        self._warmup_spin = QSpinBox()
        self._warmup_spin.setRange(0, 99)
        self._warmup_spin.setValue(2)
        self._warmup_spin.setToolTip(
            "Number of frames driven before output capture begins.\n"
            "0 = capture immediately (first frame).\n"
            "Increase for programs with deep pipeline delays."
        )

        self._warmup_plus = QPushButton("+")
        self._warmup_plus.setFixedSize(24, 24)
        self._warmup_plus.clicked.connect(lambda: self._warmup_spin.setValue(
            min(99, self._warmup_spin.value() + 1)))

        warmup_row.addWidget(self._warmup_minus)
        warmup_row.addWidget(self._warmup_spin)
        warmup_row.addWidget(self._warmup_plus)
        warmup_row.addStretch()

        warmup_container = QWidget()
        warmup_container.setLayout(warmup_row)
        sim_form.addRow("Warmup frames:", warmup_container)

        waveform_row = QHBoxLayout()
        waveform_row.setContentsMargins(0, 0, 0, 0)
        waveform_row.setSpacing(2)

        self._waveform_write = QCheckBox()
        self._waveform_write.setFixedSize(24, 24)

        waveform_row.addWidget(self._waveform_write)

        waveform_container = QWidget()
        waveform_container.setLayout(waveform_row)
        sim_form.addRow("Write waveform:", waveform_container)

        root.addWidget(sim_group)
        root.addStretch()

    # ── Population helpers ───────────────────────────────────────────────────

    def _populate_programs(self) -> None:
        self._programs = list_programs(self._programs_root)
        self._prog_combo.blockSignals(True)
        self._prog_combo.clear()
        for name in self._programs:
            self._prog_combo.addItem(name)
        self._prog_combo.blockSignals(False)
        if self._programs:
            self._on_program_changed(0)
        else:
            self._current_program = None
            self._prog_desc.setText(
                f"<span style='color:#c77'>No programs found in:<br>{self._programs_root}</span>"
            )
            self.program_changed.emit(None)

    def _populate_images(self, select_path: Path | None = None) -> None:
        self._images = collect_test_images()
        self._img_combo.blockSignals(True)
        self._img_combo.clear()

        if not self._images:
            self._img_combo.addItem("(no test images found)")
        else:
            for img_path in self._images:
                rel = img_path.relative_to(TEST_IMAGES_ROOT) if img_path.is_relative_to(TEST_IMAGES_ROOT) else img_path
                self._img_combo.addItem(str(rel), img_path)

            if select_path is not None:
                for i in range(self._img_combo.count()):
                    if self._img_combo.itemData(i) == select_path:
                        self._img_combo.setCurrentIndex(i)
                        break
        self._img_combo.blockSignals(False)
        self._on_image_changed(self._img_combo.currentIndex())

    # ── Slots ────────────────────────────────────────────────────────────────

    def _on_program_changed(self, index: int) -> None:
        if index < 0 or index >= len(self._programs):
            return
        name = self._programs[index]
        try:
            program = load_program(name, self._programs_root)
            self._current_program = program
            self._prog_desc.setText(
                f"<b>{program.display_name}</b>  v{program.version}<br>"
                f"<i>{program.category}</i><br>"
                f"{program.description[:120]}{'…' if len(program.description) > 120 else ''}"
            )
            # Defer signal emission so downstream layout rebuilds happen
            # after the combo popup has fully closed.
            QTimer.singleShot(0, lambda p=program: self.program_changed.emit(p))
        except Exception as exc:  # noqa: BLE001
            self._prog_desc.setText(f"<span style='color:red'>Error: {exc}</span>")

    def _on_image_changed(self, index: int) -> None:
        path: Path | None = self._img_combo.itemData(index)
        if isinstance(path, Path) and path.exists():
            self._update_preview(path)
            self.image_changed.emit(path)

    def _on_browse(self) -> None:
        path_str, _ = QFileDialog.getOpenFileName(
            self,
            "Select Test Image",
            str(TEST_IMAGES_ROOT),
            "Images (*.png *.jpg *.jpeg *.tif *.tiff *.bmp);;All Files (*)",
        )
        if path_str:
            p = Path(path_str)
            self._custom_image_path = p
            # Add to combo at top
            self._img_combo.blockSignals(True)
            self._img_combo.insertItem(0, p.name, p)
            self._img_combo.setCurrentIndex(0)
            self._img_combo.blockSignals(False)
            self._update_preview(p)
            self.image_changed.emit(p)

    def _update_preview(self, path: Path) -> None:
        pix = QPixmap(str(path))
        if not pix.isNull():
            pix = pix.scaled(
                self._img_preview.width(),
                self._img_preview.height(),
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )
            self._img_preview.setPixmap(pix)
        else:
            self._img_preview.setText("(preview unavailable)")

    def refresh_programs(self) -> None:
        """Re-scan programs directory and repopulate."""
        self._populate_programs()

    def initialize(self) -> None:
        """Emit signals for the current selections.

        ``ProgramPanel.__init__`` populates the program and image dropdowns
        before the parent window has had a chance to connect its slots, so the
        initial emissions are lost.  Call this once after connecting all
        signals to replay the current state into the parent.
        """
        if self._current_program is not None:
            self.program_changed.emit(self._current_program)
        path = self.selected_image_path
        if path is not None:
            self.image_changed.emit(path)

    def _on_video_settings_changed(self, _index: int = 0) -> None:
        """Update the resolution label when video mode or decimation changes."""
        self._update_resolution_label()

    def _update_resolution_label(self) -> None:
        """Compute and display the effective simulation resolution."""
        mode_key = self._video_mode_combo.currentData()
        dec = self._decimation_combo.currentData()
        if mode_key is None or dec is None:
            return
        try:
            vs = resolve_video_settings(mode_key, dec)
            mode = VIDEO_MODES[mode_key]
            interlaced_tag = " interlaced" if vs.is_interlaced else ""
            self._resolution_lbl.setText(
                f"{vs.sim_width}×{vs.sim_height}{interlaced_tag}  "
                f"({vs.fpga_config})"
            )
            self._resolution_lbl.setToolTip(
                f"Native: {mode.width}×{mode.height}\n"
                f"Decimated ÷{dec}: {vs.sim_width}×{vs.sim_height}\n"
                f"FPGA config: {vs.fpga_config}\n"
                f"Timing ID: {vs.timing_id}"
            )
        except ValueError:
            self._resolution_lbl.setText("—")

    def _update_folder_label(self) -> None:
        """Update the truncated folder path label and tooltip."""
        p = self._programs_root
        # Show up to the last two path components for brevity
        parts = p.parts
        if len(parts) > 3:
            display = "…/" + "/".join(parts[-2:])
        else:
            display = str(p)
        self._folder_path_lbl.setText(display)
        self._folder_path_lbl.setToolTip(str(p))

    def _on_browse_programs_folder(self) -> None:
        """Open a folder picker and switch the programs source directory."""
        chosen = QFileDialog.getExistingDirectory(
            self,
            "Select Programs Folder",
            str(self._programs_root),
            QFileDialog.Option.ShowDirsOnly,
        )
        if chosen:
            self.programs_root = Path(chosen)
