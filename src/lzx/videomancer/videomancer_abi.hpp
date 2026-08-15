// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: videomancer_abi.hpp - Videomancer ABI Constants and Enumerations
// License: GNU General Public License v3.0
// https://github.com/lzxindustries/videomancer-sdk
//
// For complete protocol specification, see: docs/abi-format.md
//
// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#pragma once

#include <cstddef>
#include <cstdint>

namespace lzx
{
namespace videomancer_abi_v1_0
{
    /// @brief Register addresses for Videomancer ABI 1.0
    namespace register_address
    {
        constexpr uint8_t rotary_pot_1     = 0x00;
        constexpr uint8_t rotary_pot_2     = 0x01;
        constexpr uint8_t rotary_pot_3     = 0x02;
        constexpr uint8_t rotary_pot_4     = 0x03;
        constexpr uint8_t rotary_pot_5     = 0x04;
        constexpr uint8_t rotary_pot_6     = 0x05;
        constexpr uint8_t toggle_switches  = 0x06;
        constexpr uint8_t linear_pot_12    = 0x07;
        constexpr uint8_t video_timing_id  = 0x08;
        constexpr uint8_t sync_phase_advance_clks = 0x09;
        constexpr uint8_t h_phase_sync_out        = 0x0A;
        constexpr uint8_t h_phase_analog_in       = 0x0B;
    }

    /// @brief Post-program sync delay added to reg 0x09 for yuv444 core
    ///        (blanking 2 + 444→422 sync 2). Aligns Sync Out with encoder HSYNC.
    constexpr uint16_t yuv444_core_sync_post_delay_clks = 4;
    /// @brief Same post-program path as yuv444 for gbr444 (blanking + 422 sync).
    constexpr uint16_t gbr444_core_sync_post_delay_clks = 4;
    /// @brief Native 422 cores have no blanking/converter after program_top.
    constexpr uint16_t gbr422_core_sync_post_delay_clks = 0;

    /// @brief Bit positions for toggle switches in register 0x06
    namespace toggle_switch_bit
    {
        constexpr uint8_t switch_7  = 0;
        constexpr uint8_t switch_8  = 1;
        constexpr uint8_t switch_9  = 2;
        constexpr uint8_t switch_10 = 3;
        constexpr uint8_t switch_11 = 4;
    }

    /// @brief Video timing mode IDs
    enum class video_timing_id : uint8_t
    {
        ntsc         = 0x0,  // 480i59.94 NTSC
        _1080i50     = 0x1,  // 1080i 50 Hz
        _1080i5994   = 0x2,  // 1080i 59.94 Hz
        _1080p24     = 0x3,  // 1080p 24 Hz
        _480p        = 0x4,  // 480p 59.94 Hz
        _720p50      = 0x5,  // 720p 50 Hz
        _720p5994    = 0x6,  // 720p 59.94 Hz
        _1080p30     = 0x7,  // 1080p 30 Hz
        pal          = 0x8,  // 576i50 PAL
        _1080p2398   = 0x9,  // 1080p 23.98 Hz
        _1080i60     = 0xA,  // 1080i 60 Hz
        _1080p25     = 0xB,  // 1080p 25 Hz
        _576p        = 0xC,  // 576p 50 Hz
        _1080p2997   = 0xD,  // 1080p 29.97 Hz
        _720p60      = 0xE,  // 720p 60 Hz
        reserved     = 0xF   // Reserved
    };

    /// @brief Total number of valid (non-reserved) timing IDs.
    constexpr uint8_t video_timing_id_count = 15;

    /// @brief Convert video_timing_id to its canonical string name.
    /// @details Names match the TOML `supported_timings` array values.
    inline const char* video_timing_id_to_string(video_timing_id id) {
        switch (id) {
            case video_timing_id::ntsc:        return "ntsc";
            case video_timing_id::_1080i50:    return "1080i50";
            case video_timing_id::_1080i5994:  return "1080i5994";
            case video_timing_id::_1080p24:    return "1080p24";
            case video_timing_id::_480p:       return "480p";
            case video_timing_id::_720p50:     return "720p50";
            case video_timing_id::_720p5994:   return "720p5994";
            case video_timing_id::_1080p30:    return "1080p30";
            case video_timing_id::pal:         return "pal";
            case video_timing_id::_1080p2398:  return "1080p2398";
            case video_timing_id::_1080i60:    return "1080i60";
            case video_timing_id::_1080p25:    return "1080p25";
            case video_timing_id::_576p:       return "576p";
            case video_timing_id::_1080p2997:  return "1080p2997";
            case video_timing_id::_720p60:     return "720p60";
            default:                           return "reserved";
        }
    }

    // =========================================================================
    //  Video Timing Configuration Constants
    // =========================================================================
    //
    //  These constants mirror the VHDL C_VIDEO_SYNC_CONFIG_ARRAY defined in
    //  fpga/common/rtl/video_sync/video_sync_pkg.vhd. They provide the key
    //  frame parameters for each video timing mode so that firmware and tools
    //  can reason about video dimensions without parsing VHDL.
    //
    //  Programs running on the FPGA can read the current timing ID from
    //  registers_in(8)(3 downto 0) and use the video_timing_pkg.vhd constants
    //  directly in VHDL. These C++ constants serve the same purpose for the
    //  firmware and SDK tool side.
    //
    //  VHDL cross-references:
    //    - fpga/common/rtl/video_timing/video_timing_pkg.vhd  (timing ID constants)
    //    - fpga/common/rtl/video_sync/video_sync_pkg.vhd      (C_VIDEO_SYNC_CONFIG_ARRAY)
    //    - fpga/core/yuv444_30b/rtl/core_top.vhd              (register 8 extraction)
    // =========================================================================

    /// @brief Key frame parameters for a single video timing mode.
    /// @details Subset of the VHDL t_video_sync_config record, containing
    ///          only the fields relevant to program development and firmware
    ///          parameter scaling.
    struct video_timing_config
    {
        uint16_t frame_width;      ///< Active pixels per line
        uint16_t frame_height;     ///< Active lines per frame (both fields if interlaced)
        uint16_t clocks_per_line;  ///< Total pixel clocks per line (including blanking)
        uint16_t lines_per_frame;  ///< Total lines per frame (including blanking)
        bool     is_interlaced;    ///< True if interlaced (two fields per frame)
        bool     is_sd;            ///< True if standard-definition (13.5 MHz pixel clock)
    };

    /// @brief SPI register index that carries the video timing ID.
    /// @details Programs read this via registers_in(8)(3 downto 0) in VHDL.
    ///          The firmware writes it via SPI register address 0x08.
    constexpr uint8_t timing_id_register_index = 8;

    /// @brief Bit mask to extract the 4-bit timing ID from a 10-bit register value.
    constexpr uint16_t timing_id_mask = 0x000F;

    /// @brief Total number of entries in the timing configuration table (including reserved).
    constexpr uint8_t video_timing_config_count = 16;

    /// @brief Compile-time lookup table of video timing configurations.
    /// @details Indexed by the raw 4-bit timing ID value (0-15).
    ///          Entry 15 is reserved (all zeros).
    ///          Matches C_VIDEO_SYNC_CONFIG_ARRAY in video_sync_pkg.vhd.
    constexpr video_timing_config video_timing_configs[16] = {
        // Index 0: C_NTSC — 480i 59.94 Hz
        { 720, 486, 858, 525, true, true },
        // Index 1: C_1080I50 — 1080i 50 Hz
        { 1920, 1080, 2640, 1125, true, false },
        // Index 2: C_1080I5994 — 1080i 59.94 Hz
        { 1920, 1080, 2200, 1125, true, false },
        // Index 3: C_1080P24 — 1080p 24 Hz
        { 1920, 1080, 2750, 1125, false, false },
        // Index 4: C_480P — 480p 59.94 Hz
        { 720, 480, 858, 525, false, true },
        // Index 5: C_720P50 — 720p 50 Hz
        { 1280, 720, 1980, 750, false, false },
        // Index 6: C_720P5994 — 720p 59.94 Hz
        { 1280, 720, 1650, 750, false, false },
        // Index 7: C_1080P30 — 1080p 30 Hz
        { 1920, 1080, 2200, 1125, false, false },
        // Index 8: C_PAL — 576i 50 Hz
        { 720, 576, 864, 625, true, true },
        // Index 9: C_1080P2398 — 1080p 23.98 Hz
        { 1920, 1080, 2750, 1125, false, false },
        // Index 10: C_1080I60 — 1080i 60 Hz
        { 1920, 1080, 2200, 1125, true, false },
        // Index 11: C_1080P25 — 1080p 25 Hz
        { 1920, 1080, 2640, 1125, false, false },
        // Index 12: C_576P — 576p 50 Hz
        { 720, 576, 864, 625, false, true },
        // Index 13: C_1080P2997 — 1080p 29.97 Hz
        { 1920, 1080, 2200, 1125, false, false },
        // Index 14: C_720P60 — 720p 60 Hz
        { 1280, 720, 1650, 750, false, false },
        // Index 15: Reserved
        { 0, 0, 0, 0, false, false },
    };

    /// @brief Look up the video timing configuration for a timing ID.
    /// @param id A video_timing_id enum value.
    /// @return Reference to the corresponding video_timing_config entry.
    inline constexpr const video_timing_config& get_timing_config(video_timing_id id) {
        return video_timing_configs[static_cast<uint8_t>(id) & 0x0F];
    }

} // namespace videomancer_abi_v1_0
} // namespace lzx
