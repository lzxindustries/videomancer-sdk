// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: videomancer_fpga.hpp - Videomancer SPI Interface
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

#include <cstddef>
#include <cstdint>

namespace lzx
{
    class videomancer_fpga
    {
    public:
        virtual ~videomancer_fpga() = default;
        virtual size_t transfer_spi(const uint8_t* tx_buffer, uint8_t* rx_buffer, size_t size) = 0;
        virtual void assert_chip_select_spi(bool assert) = 0;
    };

} // namespace lzx
