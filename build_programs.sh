
#!/bin/bash
# Videomancer SDK - FPGA Programs Build Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Videomancer FPGA Programs Builder${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Root paths - can be overridden by environment variables
VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT:-${SCRIPT_DIR}}"
VIDEOMANCER_PROGRAMS_DIR="${VIDEOMANCER_PROGRAMS_DIR:-${SCRIPT_DIR}/programs/}"
VIDEOMANCER_BUILD_DIR="${VIDEOMANCER_BUILD_DIR:-${SCRIPT_DIR}/build/programs/}"
VIDEOMANCER_OUT_DIR="${VIDEOMANCER_OUT_DIR:-${SCRIPT_DIR}/out/}"
VIDEOMANCER_KEYS_DIR="${VIDEOMANCER_KEYS_DIR:-${SCRIPT_DIR}/keys/}"

cd "${SCRIPT_DIR}"

# Function to parse TOML and extract a specific field value
# Args: $1 = toml file path, $2 = field name (supports dotted notation like "program.name")
parse_toml_field() {
    local toml_file="$1"
    local field="$2"

    if [ ! -f "$toml_file" ]; then
        echo ""
        return 1
    fi

    # Handle dotted field names (e.g., "program.hardware_compatibility")
    if [[ "$field" == *.* ]]; then
        local section="${field%%.*}"
        local key="${field#*.}"

        # Extract the value from the specified section
        awk -v section="$section" -v key="$key" '
        BEGIN { in_section=0; }
        /^\[/ { in_section=0; }
        /^\['"$section"'\]/ { in_section=1; next; }
        in_section && $0 ~ "^"key" *= *" {
            # Extract value after =
            sub(/^[^=]*= */, "");
            # Remove quotes and leading/trailing whitespace
            gsub(/^["'\''[:space:]]*|["'\''[:space:]]*$/, "");
            print;
            exit;
        }
        ' "$toml_file"
    else
        # Simple key lookup (first occurrence)
        awk -F'=' -v key="$field" '
        $1 ~ "^[[:space:]]*"key"[[:space:]]*$" {
            value = $2;
            gsub(/^[[:space:]]*["'\'']*|["'\'']*[[:space:]]*$/, "", value);
            print value;
            exit;
        }
        ' "$toml_file"
    fi
}

# Function to parse array values from TOML (e.g., hardware_compatibility = ["rev_a", "rev_b"])
# Args: $1 = toml file path, $2 = field name
parse_toml_array() {
    local toml_file="$1"
    local field="$2"

    if [ ! -f "$toml_file" ]; then
        echo ""
        return 1
    fi

    # Handle dotted field names
    if [[ "$field" == *.* ]]; then
        local section="${field%%.*}"
        local key="${field#*.}"

        # Extract array values from the specified section
        awk -v section="$section" -v key="$key" '
        BEGIN { in_section=0; }
        /^\[/ { in_section=0; }
        /^\['"$section"'\]/ { in_section=1; next; }
        in_section && $0 ~ "^"key" *= *\\[" {
            # Extract array content between [ and ]
            match($0, /\[.*\]/);
            arr = substr($0, RSTART+1, RLENGTH-2);
            # Remove quotes and split by comma
            gsub(/"/, "", arr);
            gsub(/'\''/, "", arr);
            gsub(/,/, " ", arr);
            gsub(/^[[:space:]]*|[[:space:]]*$/, "", arr);
            print arr;
            exit;
        }
        ' "$toml_file"
    fi
}

# Function to extract timing and resource information from nextpnr build log
# Args: $1 = log file path
parse_build_stats() {
    local log_file="$1"
    local max_freq=""
    local luts=""
    local luts_max=""
    local ios=""
    local ios_max=""
    local brams=""
    local brams_max=""
    local plbs=""
    local plbs_max=""

    if [ ! -f "$log_file" ]; then
        echo ""
        return 1
    fi

    # Extract max frequency from timing analysis (look for critical path max frequency)
    max_freq=$(grep -oP 'Max frequency for clock.*?:\s+\K[0-9.]+' "$log_file" | head -n1)
    if [ -z "$max_freq" ]; then
        # Alternative pattern for max frequency
        max_freq=$(grep -oP 'Max delay.*?=.*?\K[0-9.]+(?=\s+MHz)' "$log_file" | head -n1)
    fi

    # Extract resource utilization with both used and max values
    # Example lines from nextpnr-ice40:
    # Info: Device utilisation:
    # Info:            ICESTORM_LC:  1234/ 3520    35%
    # Info:           ICESTORM_RAM:     4/   20    20%
    # Info:                  SB_IO:    42/   96    43%
    # Info:                  SB_GB:     8/    8   100%
    # Info:           ICESTORM_PLL:     0/    1     0%
    # Info:            SB_WARMBOOT:     0/    1     0%

    # Extract used/max for each resource type
    local lc_line=$(grep 'ICESTORM_LC:' "$log_file" | head -n1)
    if [ -n "$lc_line" ]; then
        luts=$(echo "$lc_line" | grep -oP 'ICESTORM_LC:\s+\K[0-9]+')
        luts_max=$(echo "$lc_line" | grep -oP 'ICESTORM_LC:\s+[0-9]+/\s*\K[0-9]+')
    fi

    local io_line=$(grep 'SB_IO:' "$log_file" | head -n1)
    if [ -n "$io_line" ]; then
        ios=$(echo "$io_line" | grep -oP 'SB_IO:\s+\K[0-9]+')
        ios_max=$(echo "$io_line" | grep -oP 'SB_IO:\s+[0-9]+/\s*\K[0-9]+')
    fi

    local ram_line=$(grep 'ICESTORM_RAM:' "$log_file" | head -n1)
    if [ -n "$ram_line" ]; then
        brams=$(echo "$ram_line" | grep -oP 'ICESTORM_RAM:\s+\K[0-9]+')
        brams_max=$(echo "$ram_line" | grep -oP 'ICESTORM_RAM:\s+[0-9]+/\s*\K[0-9]+')
    fi

    local pll_line=$(grep 'ICESTORM_PLL:' "$log_file" | head -n1)
    if [ -n "$pll_line" ]; then
        plbs=$(echo "$pll_line" | grep -oP 'ICESTORM_PLL:\s+\K[0-9]+')
        plbs_max=$(echo "$pll_line" | grep -oP 'ICESTORM_PLL:\s+[0-9]+/\s*\K[0-9]+')
    fi

    # Build output string with available information
    local stats=""
    if [ -n "$max_freq" ]; then
        stats="${stats}Fmax: ${max_freq} MHz"
    fi
    if [ -n "$luts" ] && [ -n "$luts_max" ]; then
        [ -n "$stats" ] && stats="${stats}, "
        stats="${stats}LCs: ${luts}/${luts_max}"
    fi
    if [ -n "$ios" ] && [ -n "$ios_max" ]; then
        [ -n "$stats" ] && stats="${stats}, "
        stats="${stats}IOs: ${ios}/${ios_max}"
    fi
    if [ -n "$brams" ] && [ -n "$brams_max" ]; then
        [ -n "$stats" ] && stats="${stats}, "
        stats="${stats}RAMs: ${brams}/${brams_max}"
    fi
    if [ -n "$plbs" ] && [ -n "$plbs_max" ]; then
        [ -n "$stats" ] && stats="${stats}, "
        stats="${stats}PLLs: ${plbs}/${plbs_max}"
    fi

    echo "$stats"
}

# Determine which programs to build
PROGRAMS="${1:-$(find "${VIDEOMANCER_PROGRAMS_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)}"
PROGRAM_COUNT=$(echo "$PROGRAMS" | wc -w)

if [ -n "$1" ]; then
    echo -e "${CYAN}Building specific program: ${1}${NC}"
else
    echo -e "${CYAN}Building all programs (${PROGRAM_COUNT} found in ${VIDEOMANCER_PROGRAMS_DIR})${NC}"
fi
echo ""

# Check for OSS CAD Suite
if [ ! -d "build/oss-cad-suite" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite not found!${NC}"
    echo -e "${RED}Please run ./setup.sh first to install the FPGA toolchain.${NC}"
    exit 1
fi

# Validate OSS CAD Suite installation
if [ ! -f "build/oss-cad-suite/environment" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite installation is incomplete or corrupted!${NC}"
    echo -e "${RED}Missing environment setup script. Please run ./setup.sh again.${NC}"
    exit 1
fi

if [ ! -d "build/oss-cad-suite/bin" ]; then
    echo -e "${RED}ERROR: OSS CAD Suite binaries not found!${NC}"
    echo -e "${RED}Installation appears incomplete. Please run ./setup.sh again.${NC}"
    exit 1
fi

# Check for Ed25519 signing keys BEFORE loading OSS CAD Suite environment
# (OSS CAD Suite may use its own Python that doesn't see system packages)
SIGN_PACKAGES=false
if [ -f "${VIDEOMANCER_KEYS_DIR%/}/lzx_official_signed_descriptor_priv.bin" ] && [ -f "${VIDEOMANCER_KEYS_DIR%/}/lzx_official_signed_descriptor_pub.bin" ]; then
    # Check if cryptography library is available
    if python3 -c "import cryptography" 2>/dev/null; then
        SIGN_PACKAGES=true
        echo -e "${GREEN}✓ Ed25519 signing keys found - packages will be signed${NC}"
    else
        echo -e "${YELLOW}⚠ Ed25519 keys found but cryptography library not available${NC}"
        echo -e "${YELLOW}  Packages will be unsigned. Install with:${NC}"
        echo -e "${YELLOW}    sudo apt install python3-cryptography${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Ed25519 signing keys not found - packages will be unsigned${NC}"
    echo -e "${YELLOW}  To enable signing, run: ./scripts/setup_ed25519_signing.sh${NC}"
fi
echo ""

echo -e "${GREEN}Loading OSS CAD Suite environment...${NC}"
cd build/oss-cad-suite
source environment
cd ../..

# Create output directories

mkdir -p "${VIDEOMANCER_BUILD_DIR}"
mkdir -p "${VIDEOMANCER_OUT_DIR}"

# Track build statistics
TOTAL_PROGRAMS=0
SUCCESSFUL_PROGRAMS=0
FAILED_PROGRAMS=0

for PROGRAM in $PROGRAMS; do
    TOTAL_PROGRAMS=$((TOTAL_PROGRAMS + 1))
    PROJECT_ROOT="${VIDEOMANCER_PROGRAMS_DIR}/${PROGRAM}/"
    BUILD_ROOT="${VIDEOMANCER_BUILD_DIR}/${PROGRAM}/"
    mkdir -p "${BUILD_ROOT}"
    mkdir -p "${BUILD_ROOT}/bitstreams"
    echo ""
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}Program ${TOTAL_PROGRAMS}/${PROGRAM_COUNT}: ${PROGRAM}${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""

    # Check if program directory exists
    if [ ! -d "${PROJECT_ROOT}" ]; then
        echo -e "${RED}ERROR: Program directory '${PROJECT_ROOT}' not found${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi

    # Parse program TOML to get hardware compatibility
    PROGRAM_TOML="${PROJECT_ROOT}${PROGRAM}.toml"
    if [ ! -f "$PROGRAM_TOML" ]; then
        echo -e "${RED}ERROR: Program TOML file '${PROGRAM_TOML}' not found${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi

    # Get supported hardware variants
    HARDWARE_VARIANTS=$(parse_toml_array "$PROGRAM_TOML" "program.hardware_compatibility")
    if [ -z "$HARDWARE_VARIANTS" ]; then
        echo -e "${RED}ERROR: No hardware_compatibility specified in ${PROGRAM}.toml${NC}"
        FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
        continue
    fi

    # Get core architecture from program TOML
    CORE=$(parse_toml_field "$PROGRAM_TOML" "program.core")
    if [ -z "$CORE" ]; then
        echo -e "${YELLOW}WARNING: No core specified in ${PROGRAM}.toml, defaulting to yuv444_27b${NC}"
        CORE="yuv444_27b"
    fi

    echo -e "${CYAN}Supported hardware: ${HARDWARE_VARIANTS}${NC}"
    echo -e "${CYAN}Core architecture: ${CORE}${NC}"
    echo ""

    # Loop through each supported hardware variant
    for HARDWARE in $HARDWARE_VARIANTS; do
        echo -e "${YELLOW}Building for hardware: ${HARDWARE}${NC}"

        # Find and parse the hardware.toml file
        HARDWARE_TOML="${VIDEOMANCER_SDK_ROOT}/fpga/hardware/${HARDWARE}/config/hardware.toml"
        if [ ! -f "$HARDWARE_TOML" ]; then
            echo -e "${RED}ERROR: Hardware TOML file '${HARDWARE_TOML}' not found${NC}"
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi

        # Parse hardware configuration
        PLATFORM=$(parse_toml_field "$HARDWARE_TOML" "hardware.platform")
        DEVICE=$(parse_toml_field "$HARDWARE_TOML" "hardware.device")
        PACKAGE=$(parse_toml_field "$HARDWARE_TOML" "hardware.package")

        if [ -z "$PLATFORM" ] || [ -z "$DEVICE" ] || [ -z "$PACKAGE" ]; then
            echo -e "${RED}ERROR: Failed to parse hardware configuration from ${HARDWARE_TOML}${NC}"
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi

        echo -e "${CYAN}  Platform: ${PLATFORM}, Device: ${DEVICE}, Package: ${PACKAGE}${NC}"

        # Create hardware-specific build directory
        HW_BUILD_ROOT="${BUILD_ROOT}/${HARDWARE}/"
        mkdir -p "${HW_BUILD_ROOT}/bitstreams"

        # Create hardware-specific build directory
        HW_BUILD_ROOT="${BUILD_ROOT}/${HARDWARE}/"
        mkdir -p "${HW_BUILD_ROOT}/bitstreams"

        # Synthesize FPGA bitstreams (6 variants)
        echo -e "${GREEN}Synthesizing FPGA bitstreams for ${HARDWARE}...${NC}"
        cd fpga

        # Temporary file for capturing make errors
        MAKE_LOG=$(mktemp)

        # Track total bitstream generation time
        BITSTREAM_START=$(date +%s.%N)

        echo -e "${CYAN}  [1/6] HD Analog - Fmin: 74.25 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=74.25 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        echo -e "${CYAN}  [2/6] SD Analog - Fmin: 27 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_analog DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=27 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        echo -e "${CYAN}  [3/6] HD HDMI - Fmin: 74.25 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=74.25 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        echo -e "${CYAN}  [4/6] SD HDMI - Fmin: 27 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_hdmi DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=27 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        echo -e "${CYAN}  [5/6] HD Dual - Fmin: 74.25 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=hd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=74.25 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        echo -e "${CYAN}  [6/6] SD Dual - Fmin: 27 MHz...${NC}"
        START=$(date +%s.%N)
        if ! make VIDEOMANCER_SDK_ROOT="${VIDEOMANCER_SDK_ROOT}" PROJECT_ROOT="${PROJECT_ROOT}" BUILD_ROOT="${HW_BUILD_ROOT}" PROGRAM=$PROGRAM CONFIG=sd_dual DEVICE=$DEVICE PACKAGE=$PACKAGE FREQUENCY=27 HARDWARE=$HARDWARE CORE=$CORE PLATFORM=$PLATFORM > "$MAKE_LOG" 2>&1; then
            echo -e "${RED}Build failed. Error output:${NC}"
            cat "$MAKE_LOG"
            rm -f "$MAKE_LOG"
            cd ..
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        BUILD_STATS=$(parse_build_stats "$MAKE_LOG")
        if [ -n "$BUILD_STATS" ]; then
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s - ${BUILD_STATS}${NC}"
        else
            echo -e "${GREEN}    ✓ Completed in ${ELAPSED}s${NC}"
        fi

        BITSTREAM_END=$(date +%s.%N)
        TOTAL_BITSTREAM_TIME=$(echo "$BITSTREAM_END - $BITSTREAM_START" | bc)

        rm -f "$MAKE_LOG"
        cd ..
        echo -e "${GREEN}✓ All 6 bitstream variants generated in ${TOTAL_BITSTREAM_TIME}s${NC}"

        # Convert TOML configuration to binary (once per program, shared across hardware)
        if [ ! -f "${BUILD_ROOT}/program_config.bin" ]; then
            echo -e "${GREEN}Converting TOML configuration to binary...${NC}"
            cd tools/toml-converter
            python3 toml_to_config_binary.py "${PROJECT_ROOT}${PROGRAM}.toml" "${BUILD_ROOT}program_config.bin" --quiet
            cd ../..
            echo -e "${GREEN}✓ Configuration binary created (7,372 bytes)${NC}"
        fi

        # Copy program_config.bin to hardware-specific build directory
        cp "${BUILD_ROOT}/program_config.bin" "${HW_BUILD_ROOT}/program_config.bin"

        # Clean up intermediate files
        echo -e "${GREEN}Cleaning intermediate files...${NC}"
        cd "${HW_BUILD_ROOT}/bitstreams"
        rm -f *.asc *.json
        cd ../../../..

        # Create hardware-specific output directory
        mkdir -p "${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}"

        # Package into .vmprog format
        echo -e "${GREEN}Packaging ${PROGRAM}.vmprog for ${HARDWARE}...${NC}"
        cd ${VIDEOMANCER_SDK_ROOT}/tools/vmprog-packer

        PACK_LOG=$(mktemp)
        if [ "$SIGN_PACKAGES" = true ]; then
            echo -e "${CYAN}  Signing package with Ed25519...${NC}"
            if ! python3 vmprog_pack.py --keys-dir "${VIDEOMANCER_KEYS_DIR%/}" --hardware "${HARDWARE}" --toml-path "${PROGRAM_TOML}" "${HW_BUILD_ROOT%/}" "${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog" > "$PACK_LOG" 2>&1; then
                echo -e "${RED}Packaging failed. Error output:${NC}"
                cat "$PACK_LOG"
                rm -f "$PACK_LOG"
                cd ../..
                FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
                continue 2
            fi
        else
            if ! python3 vmprog_pack.py --no-sign --hardware "${HARDWARE}" --toml-path "${PROGRAM_TOML}" "${HW_BUILD_ROOT%/}" "${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog" > "$PACK_LOG" 2>&1; then
                echo -e "${RED}Packaging failed. Error output:${NC}"
                cat "$PACK_LOG"
                rm -f "$PACK_LOG"
                cd ../..
                FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
                continue 2
            fi
        fi
        rm -f "$PACK_LOG"

        cd ../..

        # Verify output file
        if [ -f "${VIDEOMANCER_OUT_DIR}/${HARDWARE}/${PROGRAM}.vmprog" ]; then
            FILESIZE=$(stat -f%z "${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog" 2>/dev/null || stat -c%s "${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog" 2>/dev/null)
            if [ "$SIGN_PACKAGES" = true ]; then
                echo -e "${GREEN}✓ Successfully created: ${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog (${FILESIZE} bytes, SIGNED)${NC}"
            else
                echo -e "${GREEN}✓ Successfully created: ${VIDEOMANCER_OUT_DIR%/}/${HARDWARE}/${PROGRAM}.vmprog (${FILESIZE} bytes, unsigned)${NC}"
            fi
        else
            echo -e "${RED}✗ Failed to create output file${NC}"
            FAILED_PROGRAMS=$((FAILED_PROGRAMS + 1))
            continue 2
        fi

        echo ""
    done  # End hardware variant loop

    # If we got here, the program built successfully for all hardware variants
    SUCCESSFUL_PROGRAMS=$((SUCCESSFUL_PROGRAMS + 1))
done

echo ""
echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Build Summary${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""
echo -e "${CYAN}Total programs processed:  ${TOTAL_PROGRAMS}${NC}"
echo -e "${GREEN}Successfully built:        ${SUCCESSFUL_PROGRAMS}${NC}"

if [ $FAILED_PROGRAMS -gt 0 ]; then
    echo -e "${RED}Failed:                    ${FAILED_PROGRAMS}${NC}"
fi

if [ "$SIGN_PACKAGES" = true ]; then
    echo -e "${GREEN}All packages cryptographically signed with Ed25519${NC}"
else
    echo -e "${YELLOW}Packages are unsigned (no Ed25519 keys found)${NC}"
fi

echo ""
echo -e "${GREEN}Output directory: ${SCRIPT_DIR}/out/${NC}"
echo ""

if [ $SUCCESSFUL_PROGRAMS -eq $TOTAL_PROGRAMS ]; then
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}All programs built successfully!${NC}"
    echo -e "${GREEN}====================================${NC}"
    exit 0
else
    echo -e "${YELLOW}====================================${NC}"
    echo -e "${YELLOW}Build completed with errors${NC}"
    echo -e "${YELLOW}====================================${NC}"
    exit 1
fi
