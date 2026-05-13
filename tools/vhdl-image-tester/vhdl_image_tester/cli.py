# Videomancer SDK - VHDL Image Tester
# File: videomancer-sdk/tools/vhdl-image-tester/vhdl_image_tester/cli.py - Headless CLI for all pipeline features
# Copyright (C) 2026 LZX Industries LLC. All Rights Reserved.

"""
Command-line interface for the VHDL Image Tester.

All GUI features are available headlessly:

  lzx-vhdl-cli list           [--programs-dir DIR]
  lzx-vhdl-cli info  NAME     [--programs-dir DIR]
  lzx-vhdl-cli simulate NAME  [--programs-dir DIR] [--image PATH | omit for black]
                              [--video-mode MODE] [--decimation N]
                              [--warmup-frames N] [--capture-frames N]
                              [--set KEY=VALUE ...] [--import-regs PATH]
                              [--output PATH] [--build-dir DIR]
  lzx-vhdl-cli export-regs NAME [--programs-dir DIR] [--output PATH]

All sub-commands can also be reached via the main entrypoint with a
``--no-gui`` flag or by detecting a known sub-command name as argv[1]:

  python -m vhdl_image_tester simulate cascade ...
  lzx-vhdl-tester simulate cascade ...
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

from .core.config import (
    PROGRAMS_ROOT,
    SIM_DEFAULT_VIDEO_MODE,
    SIM_DEFAULT_DECIMATION,
    SIM_WARMUP_FRAMES,
    SIM_CAPTURE_FRAMES,
    VIDEO_MODE_KEYS,
    DECIMATION_VALUES,
)

__all__ = ["main"]

_log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _resolve_programs_root(raw: str | None) -> Path | None:
    return Path(raw) if raw else None


def _load_registers(
    program,
    set_args: list[str] | None,
    import_path: str | None,
    preset_name: str | None = None,
) -> dict[str, int]:
    """Build a register dict from *program* defaults, then apply overrides.

    Precedence (lowest to highest):
      1. Program initial values (defaults)
      2. Named preset (``--preset``)
      3. Imported JSON (``--import-regs``)
      4. Individual overrides (``--set``)
    """
    regs: dict[str, int] = {}
    for param in program.parameters:
        if param.is_toggle:
            regs[param.parameter_id] = 1 if param.initial_toggle_state else 0
        else:
            regs[param.parameter_id] = param.initial_value

    if preset_name:
        preset = program.get_preset_by_name(preset_name)
        if preset is None:
            available = ", ".join(program.get_preset_names()) or "(none)"
            print(
                f"[cli] ERROR: no preset named {preset_name!r} for program {program.name!r}.\n"
                f"       Available presets: {available}",
                file=sys.stderr,
            )
            sys.exit(1)
        regs = program.resolve_preset_values(preset)
        print(f"[cli] Loaded preset: {preset.name}")

    if import_path:
        data = json.loads(Path(import_path).read_text())
        # Support both flat format {param_id: value} and GUI format
        # {program, registers: {param_id: value}, ...}
        reg_data = data.get("registers", data) if isinstance(data, dict) else data
        for k, v in reg_data.items():
            if isinstance(v, (int, float)):
                regs[k] = int(v)
        print(f"[cli] Imported registers from {import_path}")

    for kv in set_args or []:
        if "=" not in kv:
            print(f"[cli] WARNING: ignoring malformed --set argument: {kv!r} (expected KEY=VALUE)")
            continue
        k, _, v = kv.partition("=")
        regs[k.strip()] = int(v.strip())

    return regs


# ---------------------------------------------------------------------------
# Sub-command: list
# ---------------------------------------------------------------------------


def _cmd_list(args: argparse.Namespace) -> int:
    from .core.program_loader import list_programs

    pr = _resolve_programs_root(args.programs_dir)
    programs = list_programs(pr)
    if not programs:
        print("(no programs found)")
        return 0
    for name in programs:
        print(name)
    print(f"\n{len(programs)} program(s) found.")
    return 0


# ---------------------------------------------------------------------------
# Sub-command: info
# ---------------------------------------------------------------------------


def _cmd_info(args: argparse.Namespace) -> int:
    from .core.program_loader import load_program

    pr = _resolve_programs_root(args.programs_dir)
    try:
        prog = load_program(args.name, pr)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[cli] ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Name:        {prog.name}")
    print(f"Program ID:  {prog.program_id}")
    print(f"Display:     {prog.program_name}")
    print(f"Category:    {', '.join(prog.categories)}")
    print(f"Core:        {prog.core}")
    print(f"Description: {prog.description}")
    print(f"Author:      {prog.author}")
    print(f"License:     {prog.license}")
    print(f"Directory:   {prog.program_dir}")
    if prog.parameters:
        print(f"\nParameters ({len(prog.parameters)}):")
        for p in prog.parameters:
            print(
                f"  {p.parameter_id:<35}  "
                f"default={p.initial_value:>4}  "
                f"[{p.display_min_value}–{p.display_max_value}{' ' + p.suffix_label if p.suffix_label else ''}]"
                f'  "{p.name_label}"'
            )
    else:
        print("\n(no parameters)")
    if prog.presets:
        print(f"\nPresets ({len(prog.presets)}):")
        for preset in prog.presets:
            overrides = ", ".join(f"{k}={v}" for k, v in preset.values.items())
            print(f'  "{preset.name}"  [{overrides}]')
    return 0


# ---------------------------------------------------------------------------
# Sub-command: export-regs
# ---------------------------------------------------------------------------


def _cmd_export_regs(args: argparse.Namespace) -> int:
    from .core.program_loader import load_program

    pr = _resolve_programs_root(args.programs_dir)
    try:
        prog = load_program(args.name, pr)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[cli] ERROR: {exc}", file=sys.stderr)
        return 1

    regs: dict[str, int] = {}
    for p in prog.parameters:
        if p.is_toggle:
            regs[p.parameter_id] = 1 if p.initial_toggle_state else 0
        else:
            regs[p.parameter_id] = p.initial_value

    output = args.output or f"{args.name}_registers.json"
    Path(output).write_text(json.dumps(regs, indent=2))
    print(f"Exported {len(regs)} register(s) → {output}")
    return 0


# ---------------------------------------------------------------------------
# Sub-command: simulate
# ---------------------------------------------------------------------------


def _cmd_simulate(args: argparse.Namespace) -> int:
    from PIL import Image

    from .core.program_loader import load_program
    from .core.pipeline import run_pipeline

    pr = _resolve_programs_root(args.programs_dir)

    # Load program
    try:
        prog = load_program(args.name, pr)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[cli] ERROR: {exc}", file=sys.stderr)
        return 1

    # Load source image (or generate a black frame for synthesis programs)
    image_path = Path(args.image) if args.image else None
    if image_path is not None:
        if not image_path.exists():
            print(f"[cli] ERROR: image not found: {image_path}", file=sys.stderr)
            return 1
        try:
            source = Image.open(image_path).convert("RGB")
        except Exception as exc:  # noqa: BLE001
            print(f"[cli] ERROR: cannot open image: {exc}", file=sys.stderr)
            return 1
    else:
        # No source image — use a black frame (typical for synthesis programs)
        source = Image.new("RGB", (1920, 1080), (0, 0, 0))
        print("[cli] No --image provided; using black frame (synthesis mode).")

    # Assemble register values
    regs = _load_registers(
        prog,
        args.set,
        getattr(args, "import_regs", None),
        getattr(args, "preset", None),
    )

    # Determine build dir override
    build_dir = Path(args.build_dir) if getattr(args, "build_dir", None) else None
    reuse_build = getattr(args, "reuse_build", False)

    # Run pipeline
    result = run_pipeline(
        program=prog,
        source_image=source,
        register_values=regs,
        video_mode=args.video_mode,
        decimation=args.decimation,
        warmup_frames=args.warmup_frames,
        capture_frames=args.capture_frames,
        log_callback=print,
        build_dir=build_dir,
        reuse_build=reuse_build,
    )

    print(f"\nElapsed: {result.elapsed_s:.1f}s")

    if not result.success:
        print("[cli] SIMULATION FAILED.", file=sys.stderr)
        return 1

    # Save output
    output_path = Path(args.output) if args.output else Path(f"{args.name}_output.png")
    result.output_image.save(output_path)
    print(f"Output saved → {output_path}")

    # Optionally save the (resized) input alongside
    if getattr(args, "save_input", False):
        input_path = output_path.with_name(output_path.stem + "_input" + output_path.suffix)
        result.input_image.save(input_path)
        print(f"Input saved  → {input_path}")

    return 0


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lzx-vhdl-cli",
        description="Headless CLI for the LZX VHDL Image Tester.",
    )
    sub = parser.add_subparsers(dest="subcommand", metavar="SUBCOMMAND")
    sub.required = True

    # ── list ─────────────────────────────────────────────────────────────────
    p_list = sub.add_parser("list", help="List available programs.")
    p_list.add_argument(
        "--programs-dir",
        metavar="DIR",
        default=None,
        help=f"Override programs directory (default: {PROGRAMS_ROOT})",
    )

    # ── info ─────────────────────────────────────────────────────────────────
    p_info = sub.add_parser("info", help="Show program metadata and parameters.")
    p_info.add_argument("name", help="Program name (e.g. cascade)")
    p_info.add_argument("--programs-dir", metavar="DIR", default=None)

    # ── export-regs ───────────────────────────────────────────────────────────
    p_export = sub.add_parser("export-regs", help="Export default register values to JSON.")
    p_export.add_argument("name", help="Program name")
    p_export.add_argument("--programs-dir", metavar="DIR", default=None)
    p_export.add_argument(
        "--output",
        "-o",
        metavar="PATH",
        default=None,
        help="Output JSON file (default: <name>_registers.json)",
    )

    # ── simulate ──────────────────────────────────────────────────────────────
    p_sim = sub.add_parser("simulate", help="Run the full VHDL simulation pipeline.")
    p_sim.add_argument("name", help="Program name (e.g. cascade)")
    p_sim.add_argument(
        "--image",
        "-i",
        metavar="PATH",
        default=None,
        help="Source image file (PNG, JPEG, BMP, …). "
        "Omit for synthesis programs (a black frame is used).",
    )
    p_sim.add_argument(
        "--programs-dir",
        metavar="DIR",
        default=None,
        help=f"Override programs directory (default: {PROGRAMS_ROOT})",
    )
    p_sim.add_argument(
        "--video-mode",
        metavar="MODE",
        default=SIM_DEFAULT_VIDEO_MODE,
        choices=VIDEO_MODE_KEYS,
        help=f"Video standard (default: {SIM_DEFAULT_VIDEO_MODE}). "
        f"Choices: {', '.join(VIDEO_MODE_KEYS)}",
    )
    p_sim.add_argument(
        "--decimation",
        metavar="N",
        type=int,
        default=SIM_DEFAULT_DECIMATION,
        choices=DECIMATION_VALUES,
        help=f"Resolution decimation factor (default: {SIM_DEFAULT_DECIMATION}). "
        f"Choices: {', '.join(str(d) for d in DECIMATION_VALUES)}",
    )
    p_sim.add_argument(
        "--warmup-frames",
        metavar="N",
        type=int,
        default=SIM_WARMUP_FRAMES,
        help=f"Warmup frames (default: {SIM_WARMUP_FRAMES})",
    )
    p_sim.add_argument(
        "--capture-frames",
        metavar="N",
        type=int,
        default=SIM_CAPTURE_FRAMES,
        help=f"Capture frames (default: {SIM_CAPTURE_FRAMES})",
    )
    p_sim.add_argument(
        "--preset",
        metavar="NAME",
        help="Load an embedded factory preset by name before applying other overrides.",
    )
    p_sim.add_argument(
        "--set",
        metavar="KEY=VALUE",
        action="append",
        dest="set",
        help="Override a register value, e.g. --set rotary_potentiometer_1=512. Repeatable.",
    )
    p_sim.add_argument(
        "--import-regs",
        metavar="PATH",
        help="Import register values from a JSON file (see export-regs).",
    )
    p_sim.add_argument(
        "--output",
        "-o",
        metavar="PATH",
        help="Output image path (default: <name>_output.png)",
    )
    p_sim.add_argument(
        "--save-input",
        action="store_true",
        help="Also save the (resized) input image alongside the output.",
    )
    p_sim.add_argument(
        "--build-dir",
        metavar="DIR",
        default=None,
        help="Override the GHDL build directory for this run.",
    )
    p_sim.add_argument(
        "--reuse-build",
        action="store_true",
        dest="reuse_build",
        help="Reuse existing build artefacts — only re-analyse the testbench. "
        "Much faster for batch processing where only the stimulus changes.",
    )

    return parser


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> None:
    """CLI entry point.  Call with ``argv=None`` to use ``sys.argv``."""
    logging.basicConfig(level=logging.WARNING, format="%(levelname)s: %(message)s")

    parser = _build_parser()
    args = parser.parse_args(argv)

    handlers: dict[str, object] = {
        "list": _cmd_list,
        "info": _cmd_info,
        "export-regs": _cmd_export_regs,
        "simulate": _cmd_simulate,
    }

    handler = handlers.get(args.subcommand)
    if handler is None:
        parser.print_help()
        sys.exit(1)

    rc = handler(args)  # type: ignore[operator]
    sys.exit(rc or 0)
