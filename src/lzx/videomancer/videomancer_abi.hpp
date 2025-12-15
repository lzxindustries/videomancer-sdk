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
    }

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

} // namespace videomancer_abi_v1_0
} // namespace lzx
