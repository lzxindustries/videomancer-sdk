// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_public_keys.hpp - VMProg Package Public Keys
// License: GNU General Public License v3.0
// https://github.com/lzxindustries/videomancer-sdk
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

#include <stdint.h>

namespace lzx
{

    constexpr uint8_t vmprog_public_keys[][32] =
    {
        {
            0xd4, 0xda, 0x2b, 0x01, 0x98, 0x06, 0x77, 0x89,
            0x21, 0x75, 0x3d, 0xa9, 0x1d, 0xb8, 0xef, 0x9b,
            0xb7, 0x9a, 0xac, 0xf4, 0x13, 0x66, 0x70, 0xfd,
            0x7c, 0x8d, 0x48, 0x69, 0x1a, 0xd7, 0x4e, 0x4b
        }
    };

} // namespace lzx
