// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_stream.hpp - VMProg Package Streaming Interface
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
    class vmprog_stream
    {
    public:
        virtual ~vmprog_stream() = default;
        virtual size_t read(uint8_t* buffer, size_t size) = 0;
        virtual bool seek(size_t position) = 0;
    };

} // namespace lzx
