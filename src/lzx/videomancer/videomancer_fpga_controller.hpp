// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: videomancer_fpga_controller.hpp - Videomancer FPGA Controller
// License: GNU General Public License v3.0
// https://github.com/lzxindustries/videomancer-sdk
//
// High-level C++ interface for Videomancer FPGA SPI control.
// For protocol specification, see: docs/abi-format.md
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

#include "videomancer_fpga.hpp"
#include "videomancer_abi.hpp"
#include <cstddef>
#include <cstdint>

namespace lzx
{
    /// @brief High-level controller for Videomancer FPGA control interface
    ///
    /// This class wraps the low-level videomancer_fpga interface and provides
    /// convenient methods for writing to all control registers defined in the
    /// Videomancer ABI 1.0 specification.
    ///
    /// The ABI uses 16-bit SPI frames with the following structure:
    /// - Bit 15: R/W flag (0 = Write, 1 = Read)
    /// - Bits 14-10: 5-bit register address
    /// - Bits 9-0: 10-bit data payload
    class videomancer_fpga_controller
    {
    public:
        /// @brief Construct controller with SPI interface
        /// @param spi Reference to SPI interface implementation
        explicit videomancer_fpga_controller(videomancer_fpga& spi)
            : m_fpga(spi)
            , m_shadow_rotary_pot_1(0)
            , m_shadow_rotary_pot_2(0)
            , m_shadow_rotary_pot_3(0)
            , m_shadow_rotary_pot_4(0)
            , m_shadow_rotary_pot_5(0)
            , m_shadow_rotary_pot_6(0)
            , m_shadow_linear_pot_12(0)
            , m_shadow_toggle_switches(0)
            , m_shadow_video_timing_id(0)
        {}

        // Potentiometer control methods (0-1023 range)

        /// @brief Set rotary potentiometer 1 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_1(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_1, value & 0x3FF);
        }

        /// @brief Set rotary potentiometer 2 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_2(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_2, value & 0x3FF);
        }

        /// @brief Set rotary potentiometer 3 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_3(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_3, value & 0x3FF);
        }

        /// @brief Set rotary potentiometer 4 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_4(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_4, value & 0x3FF);
        }

        /// @brief Set rotary potentiometer 5 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_5(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_5, value & 0x3FF);
        }

        /// @brief Set rotary potentiometer 6 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_rotary_pot_6(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::rotary_pot_6, value & 0x3FF);
        }

        /// @brief Set linear potentiometer 12 value
        /// @param value 10-bit value (0-1023)
        /// @return true on success
        bool set_linear_pot_12(uint16_t value)
        {
            return write_register(videomancer_abi_v1_0::register_address::linear_pot_12, value & 0x3FF);
        }

        // Toggle switch control methods

        /// @brief Set all toggle switches at once
        /// @param switches Bit field where bits [4:0] represent switches 7-11
        /// @return true on success
        bool set_toggle_switches(uint16_t switches)
        {
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        /// @brief Set toggle switch 7 state
        /// @param state Switch state (true = ON, false = OFF)
        /// @return true on success
        bool set_toggle_switch_7(bool state)
        {
            uint16_t switches = m_shadow_toggle_switches;
            if (state)
                switches |= (1 << 0);
            else
                switches &= ~(1 << 0);
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        /// @brief Set toggle switch 8 state
        /// @param state Switch state (true = ON, false = OFF)
        /// @return true on success
        bool set_toggle_switch_8(bool state)
        {
            uint16_t switches = m_shadow_toggle_switches;
            if (state)
                switches |= (1 << 1);
            else
                switches &= ~(1 << 1);
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        /// @brief Set toggle switch 9 state
        /// @param state Switch state (true = ON, false = OFF)
        /// @return true on success
        bool set_toggle_switch_9(bool state)
        {
            uint16_t switches = m_shadow_toggle_switches;
            if (state)
                switches |= (1 << 2);
            else
                switches &= ~(1 << 2);
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        /// @brief Set toggle switch 10 state
        /// @param state Switch state (true = ON, false = OFF)
        /// @return true on success
        bool set_toggle_switch_10(bool state)
        {
            uint16_t switches = m_shadow_toggle_switches;
            if (state)
                switches |= (1 << 3);
            else
                switches &= ~(1 << 3);
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        /// @brief Set toggle switch 11 state
        /// @param state Switch state (true = ON, false = OFF)
        /// @return true on success
        bool set_toggle_switch_11(bool state)
        {
            uint16_t switches = m_shadow_toggle_switches;
            if (state)
                switches |= (1 << 4);
            else
                switches &= ~(1 << 4);
            return write_register(videomancer_abi_v1_0::register_address::toggle_switches, switches & 0x1F);
        }

        // Video timing control methods

        /// @brief Set video timing mode
        /// @param mode Video timing mode enumeration
        /// @return true on success
        bool set_video_timing(videomancer_abi_v1_0::video_timing_id mode)
        {
            return write_register(videomancer_abi_v1_0::register_address::video_timing_id,
                                static_cast<uint16_t>(mode) & 0xF);
        }

        /// @brief Set video timing mode by raw ID
        /// @param timing_id 4-bit timing ID (0-15)
        /// @return true on success
        bool set_video_timing_id(uint8_t timing_id)
        {
            return write_register(videomancer_abi_v1_0::register_address::video_timing_id, timing_id & 0xF);
        }

        // Bulk update methods

        /// @brief Update all rotary potentiometers at once
        /// @param values Array of 6 potentiometer values (0-1023 each)
        /// @return true if all writes succeeded
        bool set_all_rotary_pots(const uint16_t values[6])
        {
            bool success = true;
            success &= set_rotary_pot_1(values[0]);
            success &= set_rotary_pot_2(values[1]);
            success &= set_rotary_pot_3(values[2]);
            success &= set_rotary_pot_4(values[3]);
            success &= set_rotary_pot_5(values[4]);
            success &= set_rotary_pot_6(values[5]);
            return success;
        }

        /// @brief Update all controls at once
        /// @param rotary_pots Array of 6 rotary pot values (0-1023)
        /// @param linear_pot Linear pot value (0-1023)
        /// @param switches Toggle switches bit field [4:0]
        /// @param timing_id Video timing mode ID (0-15)
        /// @return true if all writes succeeded
        bool set_all_controls(const uint16_t rotary_pots[6],
                            uint16_t linear_pot,
                            uint8_t switches,
                            uint8_t timing_id)
        {
            bool success = true;
            success &= set_all_rotary_pots(rotary_pots);
            success &= set_linear_pot_12(linear_pot);
            success &= set_toggle_switches(switches);
            success &= set_video_timing_id(timing_id);
            return success;
        }

        // Read methods (from shadow registers)

        /// @brief Get rotary potentiometer 1 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_1() const
        {
            return m_shadow_rotary_pot_1;
        }

        /// @brief Get rotary potentiometer 2 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_2() const
        {
            return m_shadow_rotary_pot_2;
        }

        /// @brief Get rotary potentiometer 3 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_3() const
        {
            return m_shadow_rotary_pot_3;
        }

        /// @brief Get rotary potentiometer 4 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_4() const
        {
            return m_shadow_rotary_pot_4;
        }

        /// @brief Get rotary potentiometer 5 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_5() const
        {
            return m_shadow_rotary_pot_5;
        }

        /// @brief Get rotary potentiometer 6 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_rotary_pot_6() const
        {
            return m_shadow_rotary_pot_6;
        }

        /// @brief Get linear potentiometer 12 value from shadow register
        /// @return 10-bit value (0-1023)
        uint16_t get_linear_pot_12() const
        {
            return m_shadow_linear_pot_12;
        }

        /// @brief Get all toggle switches from shadow register
        /// @return Bit field where bits [4:0] represent switches 7-11
        uint16_t get_toggle_switches() const
        {
            return m_shadow_toggle_switches;
        }

        /// @brief Get individual toggle switch state from shadow register
        /// @param switch_num Switch number (7-11)
        /// @return Switch state (true = ON, false = OFF)
        bool get_toggle_switch(uint8_t switch_num) const
        {
            if (switch_num < 7 || switch_num > 11)
                return false;

            uint8_t bit_pos = switch_num - 7;
            return (m_shadow_toggle_switches & (1 << bit_pos)) != 0;
        }

        /// @brief Get video timing mode ID from shadow register
        /// @return 4-bit timing ID (0-15)
        uint8_t get_video_timing_id() const
        {
            return m_shadow_video_timing_id;
        }

        /// @brief Reset all shadow registers to zero
        /// @note This does not write to hardware; call set methods after reset to sync
        void reset_shadow_registers()
        {
            m_shadow_rotary_pot_1 = 0;
            m_shadow_rotary_pot_2 = 0;
            m_shadow_rotary_pot_3 = 0;
            m_shadow_rotary_pot_4 = 0;
            m_shadow_rotary_pot_5 = 0;
            m_shadow_rotary_pot_6 = 0;
            m_shadow_linear_pot_12 = 0;
            m_shadow_toggle_switches = 0;
            m_shadow_video_timing_id = 0;
        }

    private:
        videomancer_fpga& m_fpga;

        // Shadow registers (initialized to zero in constructor)
        uint16_t m_shadow_rotary_pot_1;
        uint16_t m_shadow_rotary_pot_2;
        uint16_t m_shadow_rotary_pot_3;
        uint16_t m_shadow_rotary_pot_4;
        uint16_t m_shadow_rotary_pot_5;
        uint16_t m_shadow_rotary_pot_6;
        uint16_t m_shadow_linear_pot_12;
        uint16_t m_shadow_toggle_switches;
        uint8_t m_shadow_video_timing_id;

        /// @brief Write to a register using the ABI protocol
        /// @param address 5-bit register address
        /// @param data 10-bit data value
        /// @return true on success
        bool write_register(uint8_t address, uint16_t data)
        {
            // Get reference to appropriate shadow register
            uint16_t* shadow_reg = get_shadow_register(address);

            // Only write if value has changed
            if (shadow_reg != nullptr && *shadow_reg == data)
            {
                return true; // No change needed
            }

            // Build 16-bit frame: [R/W(1)][Addr(5)][Data(10)]
            // R/W = 0 for write, Addr << 10, Data in lower 10 bits
            uint16_t frame = (0 << 15) |                    // Write bit
                           ((address & 0x1F) << 10) |      // 5-bit address
                           (data & 0x3FF);                  // 10-bit data

            uint8_t tx_buffer[2];
            tx_buffer[0] = static_cast<uint8_t>(frame >> 8);    // MSB first
            tx_buffer[1] = static_cast<uint8_t>(frame & 0xFF);

            m_fpga.assert_chip_select_spi(true);  // Assert CS low
            size_t transferred = m_fpga.transfer_spi(tx_buffer, nullptr, 2);
            m_fpga.assert_chip_select_spi(false); // De-assert CS high

            bool success = (transferred == 2);

            // Update shadow register on successful write
            if (success && shadow_reg != nullptr)
            {
                *shadow_reg = data;
            }

            return success;
        }

        /// @brief Get pointer to shadow register for given address
        /// @param address Register address
        /// @return Pointer to shadow register or nullptr if invalid
        uint16_t* get_shadow_register(uint8_t address)
        {
            switch (address)
            {
                case videomancer_abi_v1_0::register_address::rotary_pot_1:     return &m_shadow_rotary_pot_1;
                case videomancer_abi_v1_0::register_address::rotary_pot_2:     return &m_shadow_rotary_pot_2;
                case videomancer_abi_v1_0::register_address::rotary_pot_3:     return &m_shadow_rotary_pot_3;
                case videomancer_abi_v1_0::register_address::rotary_pot_4:     return &m_shadow_rotary_pot_4;
                case videomancer_abi_v1_0::register_address::rotary_pot_5:     return &m_shadow_rotary_pot_5;
                case videomancer_abi_v1_0::register_address::rotary_pot_6:     return &m_shadow_rotary_pot_6;
                case videomancer_abi_v1_0::register_address::linear_pot_12:    return &m_shadow_linear_pot_12;
                case videomancer_abi_v1_0::register_address::toggle_switches:  return &m_shadow_toggle_switches;
                case videomancer_abi_v1_0::register_address::video_timing_id:
                    // Return pointer to uint8_t as uint16_t* (safe since we only use lower byte)
                    return reinterpret_cast<uint16_t*>(&m_shadow_video_timing_id);
                default: return nullptr;
            }
        }
    };

} // namespace lzx
