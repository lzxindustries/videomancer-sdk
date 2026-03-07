# Videomancer SDK - VHDL Image Tester
# File: videomancer-sdk/tools/vhdl-image-tester/vhdl_image_tester/core/sim_runner.py - GHDL simulation runner
# Copyright (C) 2026 LZX Industries LLC. All Rights Reserved.

"""
Run the GHDL VHDL-2008 simulator to process a still image through a
Videomancer FPGA program.

Pipeline:
  1. ghdl -a   (analyse every VHDL source file in dependency order)
  2. ghdl -e   (elaborate the tb_vit testbench)
  3. ghdl -r   (run the simulation; it stops itself via std.env.stop)
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from .config import (
    SDK_FPGA,
    SDK_VHDL_SOURCES,
    SDK_CORE_CONFIG_DIR,
    SDK_CORE_YUV444_DIR,
    FPGA_CORES,
)

# ---------------------------------------------------------------------------
# GHDL constants
# ---------------------------------------------------------------------------

_GHDL_STD   = "--std=08"
_TOP_ENTITY = "tb_vit"

LogCallback = Callable[[str], None]
ProgressCallback = Callable[[int, int], None]  # (current_frame, total_frames)


# ---------------------------------------------------------------------------
# GHDL backend detection
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class GhdlInfo:
    """Describes the resolved GHDL installation."""
    path: str               # absolute path to the ghdl binary
    version: str            # first line of --version output
    backend: str            # "llvm", "gcc", or "mcode"
    is_compiled: bool       # True for llvm/gcc (native-code) backends


def _detect_backend(version_output: str) -> str:
    """Parse the GHDL backend from its ``--version`` output.

    Examples of the code-generator line:
        ``llvm 18.1.8 code generator``
        ``mcode JIT code generator``
        ``GCC 13.3.0 code generator``
    """
    for line in version_output.splitlines():
        low = line.strip().lower()
        if "llvm" in low and "code generator" in low:
            return "llvm"
        if "gcc" in low and "code generator" in low:
            return "gcc"
        if "mcode" in low and "code generator" in low:
            return "mcode"
    return "mcode"  # conservative fallback


def _probe_ghdl(path: str) -> GhdlInfo | None:
    """Run ``<path> --version`` and return a `GhdlInfo`, or *None* on failure."""
    try:
        result = subprocess.run(
            [path, "--version"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        version = result.stdout.splitlines()[0] if result.stdout else "unknown"
        backend = _detect_backend(result.stdout)
        return GhdlInfo(
            path=path,
            version=version,
            backend=backend,
            is_compiled=(backend in ("llvm", "gcc")),
        )
    except Exception:  # noqa: BLE001
        return None


def _resolve_ghdl() -> GhdlInfo:
    """Find the best available GHDL binary.

    Selection order (first match wins):
      1. ``LZX_VIT_GHDL`` environment variable (explicit override).
      2. ``ghdl-llvm`` on ``PATH``  — compiled backend, fastest.
      3. ``ghdl-gcc``  on ``PATH``  — compiled backend.
      4. ``ghdl``      on ``PATH``  — whatever backend it was built with.

    Returns
    -------
    GhdlInfo
        Metadata about the resolved GHDL installation.

    Raises
    ------
    RuntimeError
        If no usable GHDL binary can be found.
    """
    # 1. Explicit override
    env_ghdl = os.environ.get("LZX_VIT_GHDL")
    if env_ghdl:
        info = _probe_ghdl(env_ghdl)
        if info is not None:
            return info
        raise RuntimeError(
            f"LZX_VIT_GHDL is set to {env_ghdl!r} but it is not a usable GHDL binary."
        )

    # 2–4. Probe candidates in preference order
    for candidate in ("ghdl-llvm", "ghdl-gcc", "ghdl"):
        binary = shutil.which(candidate)
        if binary is not None:
            info = _probe_ghdl(binary)
            if info is not None:
                return info

    raise RuntimeError(
        "GHDL not found on PATH.\n"
        "For best performance install the LLVM backend:\n"
        "  Ubuntu/Debian:  sudo apt install ghdl-llvm\n"
        "  macOS:          brew install ghdl    (includes LLVM on Apple Silicon)\n"
        "  Any platform:   download OSS CAD Suite from\n"
        "                  https://github.com/YosysHQ/oss-cad-suite-build/releases"
    )


# Module-level cache so we probe only once per process.
_cached_ghdl_info: GhdlInfo | None = None


def _get_ghdl_info() -> GhdlInfo:
    """Return (and cache) the resolved GHDL installation info."""
    global _cached_ghdl_info  # noqa: PLW0603
    if _cached_ghdl_info is None:
        _cached_ghdl_info = _resolve_ghdl()
    return _cached_ghdl_info


# ---------------------------------------------------------------------------
# Source-file ordering
# ---------------------------------------------------------------------------

def _ordered_sdk_sources(config: str, core: str) -> list[Path]:
    """
    Return SDK VHDL files in correct analysis order for GHDL.

    Dependency graph (→ means "depends on"):
      video_stream_pkg  (pure package, no deps)
      video_timing_pkg  → video_stream_pkg
      video_sync_pkg    → video_timing_pkg
      core_config_pkg   (pure package, no deps)
      core_pkg          → video_timing_pkg, video_sync_pkg
      converters/blanking (entities) → video_stream_pkg, video_timing_pkg, core_pkg
      video_sync entities → video_timing_pkg, video_sync_pkg
      dsp, utils, serial (standalone entities)
      program_top entity → core_pkg, video_stream_pkg, video_timing_pkg
    """
    if core not in FPGA_CORES:
        raise ValueError(f"Unsupported core: {core!r}. Supported: {FPGA_CORES}")

    sources: list[Path] = []

    # 1. Packages first — strict dependency order
    #    video_stream_pkg → video_timing_pkg → video_sync_pkg
    vs_dir = SDK_FPGA / "common/rtl/video_stream"
    vt_dir = SDK_FPGA / "common/rtl/video_timing"
    vsync_dir = SDK_FPGA / "common/rtl/video_sync"

    # Package files (must come before any entities that use them)
    _append_if_exists(sources, vs_dir / "video_stream_pkg.vhd")
    _append_if_exists(sources, vt_dir / "video_timing_pkg.vhd")
    _append_if_exists(sources, vsync_dir / "video_sync_pkg.vhd")

    # 2. Core config package (e.g. sd_analog_pkg.vhd)
    config_pkg = SDK_CORE_CONFIG_DIR / f"{config}_pkg.vhd"
    if not config_pkg.exists():
        raise FileNotFoundError(f"Config package not found: {config_pkg}")
    sources.append(config_pkg)

    # 3. Core package (depends on video_timing_pkg + video_sync_pkg)
    core_dir = SDK_FPGA / "core" / core / "rtl"
    _append_if_exists(sources, core_dir / "core_pkg.vhd")

    # 4. Video stream entities (converters, blanking — depend on core_pkg)
    for f in sorted(vs_dir.glob("*.vhd")):
        if f.name != "video_stream_pkg.vhd" and f not in sources:
            sources.append(f)

    # 5. Video timing entities
    for f in sorted(vt_dir.glob("*.vhd")):
        if f.name != "video_timing_pkg.vhd" and f not in sources:
            sources.append(f)

    # 6. Video sync entities (depend on video_sync_pkg + video_timing_pkg)
    for f in sorted(vsync_dir.glob("*.vhd")):
        if f.name != "video_sync_pkg.vhd" and f not in sources:
            sources.append(f)

    # 7. Shared IP: DSP (multiplier before interpolator), utils, serial
    dsp_files = SDK_VHDL_SOURCES["dsp"]
    multiplier = [f for f in dsp_files if "multiplier" in f.name]
    other_dsp  = [f for f in dsp_files if "multiplier" not in f.name]
    sources.extend(multiplier + other_dsp)
    sources.extend(SDK_VHDL_SOURCES["utils"])
    sources.extend(SDK_VHDL_SOURCES["serial"])

    # 8. program_top.vhd entity declaration (depends on core_pkg)
    _append_if_exists(sources, core_dir / "program_top.vhd")
    # core_top.vhd is not needed for simulation (synthesis only)

    return sources


def _append_if_exists(lst: list[Path], path: Path) -> None:
    """Append *path* to *lst* only if it exists on disk."""
    if path.exists():
        lst.append(path)


def _ordered_program_sources(program_dir: Path) -> list[Path]:
    """
    Return the program's VHDL files in dependency order, with the
    program_top architecture last.

    Supporting entity files are topologically sorted so that any file
    defining ``entity <name>`` is analysed before files that instantiate
    ``entity work.<name>``.  Files with no cross-dependencies fall back
    to alphabetical order.
    """
    all_vhd   = sorted(program_dir.glob("*.vhd"))
    main_arch = [f for f in all_vhd if _is_program_top_arch(f)]
    supporting = [f for f in all_vhd if f not in main_arch]
    return _toposort_vhdl(supporting) + main_arch


def _toposort_vhdl(files: list[Path]) -> list[Path]:
    """
    Topologically sort VHDL source files by direct entity instantiation
    dependencies (``entity work.<name>``).

    Falls back to alphabetical order for files with no inter-dependencies.
    """
    if len(files) <= 1:
        return list(files)

    _re_entity_decl = re.compile(
        r"^\s*entity\s+(\w+)\s+is\b", re.IGNORECASE | re.MULTILINE
    )
    _re_entity_inst = re.compile(
        r"\bentity\s+work\.(\w+)\b", re.IGNORECASE
    )

    # Map: entity name → file that declares it
    entity_to_file: dict[str, Path] = {}
    # Map: file → set of entity names it instantiates from work
    file_deps: dict[Path, set[str]] = {}

    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            file_deps[f] = set()
            continue

        for m in _re_entity_decl.finditer(text):
            entity_to_file[m.group(1).lower()] = f

        refs = {m.group(1).lower() for m in _re_entity_inst.finditer(text)}
        file_deps[f] = refs

    # Build adjacency: file → set of files it depends on (within this list)
    adj: dict[Path, set[Path]] = {}
    for f in files:
        deps = set()
        for entity_name in file_deps.get(f, set()):
            dep_file = entity_to_file.get(entity_name)
            if dep_file is not None and dep_file != f:
                deps.add(dep_file)
        adj[f] = deps

    # Kahn's algorithm (stable — uses original alphabetical order as tiebreaker)
    in_degree: dict[Path, int] = {f: 0 for f in files}
    for f in files:
        for dep in adj[f]:
            # dep must come before f, so f has an incoming edge from dep
            in_degree[f] = in_degree.get(f, 0) + 1

    queue = [f for f in files if in_degree[f] == 0]  # preserves alpha order
    result: list[Path] = []
    while queue:
        node = queue.pop(0)
        result.append(node)
        for f in files:
            if node in adj[f]:
                in_degree[f] -= 1
                if in_degree[f] == 0:
                    queue.append(f)

    # Append any remaining files (cycle fallback — shouldn't happen)
    for f in files:
        if f not in result:
            result.append(f)

    return result


def _is_program_top_arch(path: Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8", errors="replace").lower()
        return bool(re.search(r"architecture\s+\w+\s+of\s+program_top", text))
    except OSError:
        return False


# ---------------------------------------------------------------------------
# Main simulation runner
# ---------------------------------------------------------------------------

def run_simulation(
    program_dir:      Path,
    testbench_path:   Path,
    build_dir:        Path,
    config:           str = "sd_analog",
    core:             str = "yuv444_30b",
    write_waveform:   bool = False,
    log_callback:     LogCallback | None = None,
    progress_callback: ProgressCallback | None = None,
) -> None:
    """
    Analyse, elaborate and run the GHDL simulation.

    Parameters
    ----------
    program_dir     : Directory containing the program's .vhd files.
    testbench_path  : Path to the generated tb_vit.vhd.
    build_dir       : Working directory for GHDL objects (.cf files, etc.).
    config          : FPGA configuration name (e.g. 'sd_analog').
    core            : FPGA video core (e.g. 'yuv444_30b').
    log_callback    : Called with each line of output (stdout+stderr).
    progress_callback : Called with (current_frame, total_frames) on each
                        simulated frame boundary.

    Raises
    ------
    RuntimeError    : If GHDL is not found or if any step fails.
    """
    ghdl_info = _get_ghdl_info()
    ghdl = ghdl_info.path
    build_dir.mkdir(parents=True, exist_ok=True)

    workdir_flag = f"--workdir={build_dir}"

    # Collect all sources in analysis order
    sdk_sources     = _ordered_sdk_sources(config, core)
    program_sources = _ordered_program_sources(program_dir)
    all_sources     = sdk_sources + program_sources + [testbench_path]

    backend_label = f"{ghdl_info.backend} backend"
    if ghdl_info.is_compiled:
        backend_label += " (compiled — fast)"
    _log(log_callback, f"=== GHDL simulation — {len(all_sources)} source files ===")
    _log(log_callback, f"    GHDL: {ghdl_info.version}")
    _log(log_callback, f"    Backend: {backend_label}")

    # ── Step 1: Analyse ──────────────────────────────────────────────────────
    _log(log_callback, "\n[1/3] Analysing VHDL sources...")
    for src in all_sources:
        cmd = [ghdl, "-a", _GHDL_STD, workdir_flag, str(src)]
        _log(log_callback, f"  + {src.name}")
        _run(cmd, build_dir, log_callback, description=f"analyse {src.name}")

    # ── Step 2: Elaborate ────────────────────────────────────────────────────
    _log(log_callback, "\n[2/3] Elaborating testbench...")
    elab_cmd = [ghdl, "-e", _GHDL_STD, workdir_flag]
    # LLVM and GCC backends support optimisation flags — compile the
    # elaborated design at -O2 for significantly faster simulation.
    if ghdl_info.is_compiled:
        elab_cmd.append("-O2")
    elab_cmd.append(_TOP_ENTITY)
    _run(elab_cmd, build_dir, log_callback, description="elaborate tb_vit")

    # ── Step 3: Run ──────────────────────────────────────────────────────────
    _log(log_callback, "\n[3/3] Running simulation...")
    run_cmd = [ghdl, "-r", _GHDL_STD, workdir_flag, _TOP_ENTITY]

    if write_waveform:
        wave_file = program_dir / "wave.ghw"
        _log(log_callback, f"\nwave file: {wave_file}")
        wave_flag = f"--wave={wave_file}"
        run_cmd.append(wave_flag)

    _run(run_cmd, build_dir, log_callback, description="run simulation",
         check_output_marker="VIT_DONE",
         progress_callback=progress_callback)

    _log(log_callback, "\n=== Simulation complete ===")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _log(cb: LogCallback | None, msg: str) -> None:
    if cb is not None:
        cb(msg)


_RE_VIT_FRAME = re.compile(r"VIT_FRAME:\s*(\d+)/(\d+)")


def _run(
    cmd: list[str],
    cwd: Path,
    log_callback: LogCallback | None,
    description:  str = "",
    check_output_marker: str | None = None,
    progress_callback: ProgressCallback | None = None,
) -> str:
    """Execute *cmd*, stream output to *log_callback*, raise on non-zero exit."""
    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    output_lines: list[str] = []
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.rstrip("\n")
        # Suppress GHDL numeric_std metavalue warnings (expected during pipeline warmup)
        if "metavalue detected" in line:
            continue
        # Parse per-frame progress reports from the testbench
        frame_match = _RE_VIT_FRAME.search(line)
        if frame_match:
            current = int(frame_match.group(1))
            total   = int(frame_match.group(2))
            if progress_callback is not None:
                progress_callback(current, total)
        # Highlight capture reports from the testbench
        if "VIT_CAPTURE" in line or "VIT_CAPTURED" in line:
            _log(log_callback, f"  ✦ {line}")
            output_lines.append(line)
            continue
        output_lines.append(line)
        _log(log_callback, line)

    proc.wait()
    full_output = "\n".join(output_lines)

    if proc.returncode != 0:
        raise RuntimeError(
            f"GHDL failed ({description}) — exit code {proc.returncode}\n{full_output}"
        )

    # If we're looking for a specific marker in the output, verify it's there
    if check_output_marker and check_output_marker not in full_output:
        raise RuntimeError(
            f"Simulation ended without expected marker '{check_output_marker}'.\n"
            "The testbench may have crashed or timed out."
        )

    return full_output


def check_ghdl_available() -> tuple[bool, str, str]:
    """Return (available, version_string, backend) for the installed GHDL.

    The resolver automatically prefers ``ghdl-llvm`` > ``ghdl-gcc`` > ``ghdl``
    so the returned info reflects the fastest backend found.
    """
    try:
        info = _resolve_ghdl()
        return True, info.version, info.backend
    except RuntimeError:
        return False, "not found", "none"
