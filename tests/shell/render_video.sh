#!/usr/bin/env bash
#
# render_video.sh — Render a segment of video through a Videomancer GHDL simulation
#
# Reads program parameters and presets dynamically from the program's TOML config.
# Run with --help or no args to see usage + available programs/presets.
#
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROGRAMS_DIR="$SDK_DIR/programs"
PYTHON="/opt/homebrew/bin/python3"
VENV="/tmp/vit_venv"
GHDL="/opt/homebrew/bin/ghdl"
FPS=30
WORK_DIR="/tmp/videomancer_render"

# --- TOML helper: extract info via Python/tomllib ---
toml_read() {
    local toml_file="$1"
    local query="$2"
    "$PYTHON" -c "
import tomllib
with open('$toml_file', 'rb') as f:
    data = tomllib.load(f)
$query
"
}

# --- List available programs ---
list_programs() {
    echo "Available programs:"
    echo ""
    for dir in "$PROGRAMS_DIR"/*/; do
        local name
        name=$(basename "$dir")
        local toml="$dir/$name.toml"
        if [[ -f "$toml" ]]; then
            local info
            info=$(toml_read "$toml" "
p = data.get('program', {})
desc = p.get('description', 'No description')
print(f\"  {p.get('program_name', '$name'):16s} {desc}\")
")
            echo "$info"
        fi
    done
}

# --- Show presets for a program ---
list_presets() {
    local toml="$1"
    toml_read "$toml" "
presets = data.get('preset', [])
if not presets:
    print('  (no presets defined)')
else:
    for p in presets:
        print(f\"  {p['name']}\")
"
}

# --- Show parameters for a program ---
list_parameters() {
    local toml="$1"
    toml_read "$toml" "
params = data.get('parameter', [])
for p in params:
    pid = p.get('parameter_id', '')
    name = p.get('name_label', pid)
    suffix = p.get('suffix_label', '')
    if 'value_labels' in p:
        opts = ' | '.join(p['value_labels'])
        init = p.get('initial_value_label', '')
        print(f\"  {name:16s} [{opts}]  default: {init}\")
    else:
        lo = p.get('display_min_value', 0)
        hi = p.get('display_max_value', 1023)
        init = p.get('initial_value', 0)
        print(f\"  {name:16s} {lo}-{hi}{suffix}  default: {init}\")
"
}

# --- Usage / help ---
usage() {
    cat <<'EOF'
Usage:
  render_video.sh <program> <input_video> <start_time> <duration> [options]

Arguments:
  program       Program name (e.g. stickfigure, sabattier, kintsugi)
  input_video   Path to input video file
  start_time    Start position (e.g. 5:00, 1:23:45, or 300)
  duration      Duration in seconds (e.g. 10)

Options:
  --preset <name>       Use a named preset (default: first available)
  --decimation <n>      Resolution divisor: 4=480x270, 2=960x540, 1=1920x1080 (default: 4)
  --fps <n>             Frame rate (default: 30)
  --no-play             Don't play the result with mplayer
  --help                Show this help

Examples:
  render_video.sh stickfigure ~/video.mp4 5:00 10
  render_video.sh stickfigure ~/video.mp4 1:30 5 --preset "Bold Ink"
  render_video.sh sabattier ~/video.mp4 0:45 3 --decimation 2
  render_video.sh kintsugi ~/video.mp4 30 10 --no-play

EOF

    echo "--------------------------------------------"
    list_programs
    echo ""

    # If a program name was given, show its details
    if [[ -n "${1:-}" ]]; then
        local prog="$1"
        local toml="$PROGRAMS_DIR/$prog/$prog.toml"
        if [[ -f "$toml" ]]; then
            echo "--------------------------------------------"
            echo "Presets for '$prog':"
            list_presets "$toml"
            echo ""
            echo "Parameters for '$prog':"
            list_parameters "$toml"
            echo ""
        fi
    fi
}

# --- Parse arguments ---
PROGRAM=""
INPUT_VIDEO=""
START_TIME=""
DURATION=""
PRESET=""
DECIMATION=4
NO_PLAY=false

# Handle --help or no args
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage "${2:-}"
    exit 0
fi

# Positional args
PROGRAM="$1"; shift
INPUT_VIDEO="${1:?Missing input_video}"; shift
START_TIME="${1:?Missing start_time}"; shift
DURATION="${1:?Missing duration}"; shift

# Optional flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --preset)     PRESET="$2"; shift 2 ;;
        --decimation) DECIMATION="$2"; shift 2 ;;
        --fps)        FPS="$2"; shift 2 ;;
        --no-play)    NO_PLAY=true; shift ;;
        --help|-h)    usage "$PROGRAM"; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Validate program ---
TOML_FILE="$PROGRAMS_DIR/$PROGRAM/$PROGRAM.toml"
if [[ ! -f "$TOML_FILE" ]]; then
    echo "ERROR: Program '$PROGRAM' not found at $TOML_FILE" >&2
    echo ""
    list_programs
    exit 1
fi

# Read program info
PROG_INFO=$(toml_read "$TOML_FILE" "
p = data.get('program', {})
print(p.get('program_name', '$PROGRAM'))
print(p.get('description', ''))
presets = data.get('preset', [])
print(','.join(pr['name'] for pr in presets))
print(presets[0]['name'] if presets else '')
")
PROG_NAME=$(echo "$PROG_INFO" | sed -n '1p')
PROG_DESC=$(echo "$PROG_INFO" | sed -n '2p')
AVAILABLE_PRESETS=$(echo "$PROG_INFO" | sed -n '3p')
DEFAULT_PRESET=$(echo "$PROG_INFO" | sed -n '4p')

# Apply default preset if none specified
if [[ -z "$PRESET" ]]; then
    PRESET="$DEFAULT_PRESET"
fi

# Validate preset if specified
if [[ -n "$PRESET" && -n "$AVAILABLE_PRESETS" ]]; then
    if ! echo "$AVAILABLE_PRESETS" | tr ',' '\n' | grep -qx "$PRESET"; then
        echo "ERROR: Unknown preset '$PRESET' for $PROGRAM." >&2
        echo "Available presets: $(echo "$AVAILABLE_PRESETS" | tr ',' ', ')" >&2
        exit 1
    fi
fi

# --- Derived paths ---
BUILD_DIR="/tmp/vit_build/${PROGRAM}_batch"
FRAMES_IN="$WORK_DIR/frames_in"
FRAMES_OUT="$WORK_DIR/frames_out"
TOTAL_FRAMES=$((DURATION * FPS))

# Preset will be passed as separate args to avoid word-splitting

# --- Banner ---
echo "============================================"
echo " Videomancer Video Renderer"
echo "============================================"
echo " Program:    $PROG_NAME"
echo " Desc:       $PROG_DESC"
echo " Input:      $INPUT_VIDEO"
echo " Start:      $START_TIME"
echo " Duration:   ${DURATION}s (~${TOTAL_FRAMES} frames @ ${FPS}fps)"
if [[ -n "$PRESET" ]]; then
echo " Preset:     $PRESET"
fi
echo " Decimation: $DECIMATION"
echo "============================================"

# --- Step 1: Extract frames ---
echo ""
echo "[Step 1/3] Extracting frames from $START_TIME ..."
rm -rf "$FRAMES_IN" "$FRAMES_OUT"
mkdir -p "$FRAMES_IN" "$FRAMES_OUT"

ffmpeg -hide_banner -loglevel warning \
    -ss "$START_TIME" -t "$DURATION" \
    -i "$INPUT_VIDEO" \
    -vf "fps=$FPS" \
    "$FRAMES_IN/frame_%04d.png"

ACTUAL_FRAMES=$(ls "$FRAMES_IN"/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
echo "Extracted $ACTUAL_FRAMES frames."

if [[ "$ACTUAL_FRAMES" -eq 0 ]]; then
    echo "ERROR: No frames extracted. Check input video and start time." >&2
    exit 1
fi

# Estimate time
echo "Estimated processing time: ~$((ACTUAL_FRAMES * 23))s (~$((ACTUAL_FRAMES * 23 / 60))min)"

# --- Step 2: Process through GHDL simulation ---
echo ""
echo "[Step 2/3] Processing $ACTUAL_FRAMES frames through $PROG_NAME simulation..."
echo ""

COUNTER=0
SECONDS=0
for frame in "$FRAMES_IN"/frame_*.png; do
    COUNTER=$((COUNTER + 1))
    BASENAME=$(basename "$frame")
    OUT_FILE="$FRAMES_OUT/$BASENAME"

    printf "[%d/%d] %s ... " "$COUNTER" "$ACTUAL_FRAMES" "$BASENAME"
    FRAME_START=$SECONDS

    PRESET_ARGS=()
    if [[ -n "$PRESET" ]]; then
        PRESET_ARGS=(--preset "$PRESET")
    fi

    # After the first frame, reuse the compiled GHDL build artefacts
    REUSE_ARGS=()
    if [[ "$COUNTER" -gt 1 ]]; then
        REUSE_ARGS=(--reuse-build)
    fi

    env -i HOME="$HOME" \
        PATH="$VENV/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        LZX_VIT_GHDL="$GHDL" \
        "$VENV/bin/python" -m vhdl_image_tester simulate "$PROGRAM" \
            --image "$frame" \
            --decimation "$DECIMATION" \
            --output "$OUT_FILE" \
            --build-dir "$BUILD_DIR" \
            "${PRESET_ARGS[@]}" \
            "${REUSE_ARGS[@]}" \
            --programs-dir "$PROGRAMS_DIR" \
        2>/dev/null

    ELAPSED=$((SECONDS - FRAME_START))
    echo "${ELAPSED}s"
done

echo ""
echo "All $ACTUAL_FRAMES frames processed."

# --- Step 3: Reassemble video ---
echo ""
echo "[Step 3/3] Assembling output video..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_VIDEO="$WORK_DIR/${PROGRAM}_${TIMESTAMP}.mp4"
ffmpeg -y -hide_banner -loglevel warning \
    -framerate "$FPS" \
    -i "$FRAMES_OUT/frame_%04d.png" \
    -c:v libx264 -pix_fmt yuv420p \
    "$OUTPUT_VIDEO"

FILE_SIZE=$(du -h "$OUTPUT_VIDEO" | cut -f1)
echo "Output: $OUTPUT_VIDEO ($FILE_SIZE)"

echo ""
echo "============================================"
echo " Done!"
echo "============================================"

if [[ "$NO_PLAY" == false ]]; then
    echo "Playing with mplayer (loop). Press 'q' to quit."
    mplayer -loop 0 "$OUTPUT_VIDEO"
fi
