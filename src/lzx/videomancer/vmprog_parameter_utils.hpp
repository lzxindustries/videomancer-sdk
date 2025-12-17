// Videomancer SDK - Open source FPGA-based video effects development kit
// Copyright (C) 2025 LZX Industries LLC
// File: vmprog_parameter_utils.hpp - Parameter control curve utilities
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
//
// Overview:
//   Provides parameter control curve transformations for VMProg programs:
//   - Linear scaling modes (1x, 0.5x, 0.25x, 2x)
//   - Boolean on/off threshold
//   - Discrete step quantization (4, 8, 16, 32, 64, 128, 256 steps)
//   - Polar/angular wrapping modes (90°, 180°, 360°, 720°, 1440°, 2880°)
//   - Easing curves: quadratic, sinusoidal, circular, quintic, quartic, exponential
//
// Implementation:
//   Uses fixed-point arithmetic for embedded systems compatibility
//   - Input/output range: 0-1023 (10-bit unsigned)
//   - No floating-point operations
//   - Constexpr for compile-time evaluation where possible
//
// ================================================================================
// COMPUTATIONAL COMPLEXITY TABLE - All 36 Parameter Control Modes
// ================================================================================
// Complexity scoring: Add=1, Sub=1, Mul=2, Shift=0.5, Div=4, Mod=4, Compare=0.5
// Table reflects OPTIMIZED operations (bit shifts replace div/mul where possible).
// Approximation note: Shift optimizations trade <0.2% precision for performance.
//
// ┌────────────────────────┬──────────┬─────────────────────────────────────────┐
// │ Mode                   │ Score    │ Operations (Optimized)                  │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ LINEAR MODES           │          │                                         │
// │  linear                │   0      │ passthrough (no operations)             │
// │  linear_half           │   0.5    │ 1 shift (>>1)                           │
// │  linear_quarter        │   0.5    │ 1 shift (>>2)                           │
// │  linear_double         │   0.5    │ 1 shift (<<1) + clamp                   │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ BOOLEAN MODE           │          │                                         │
// │  boolean               │   0.5    │ 1 compare (ternary)                     │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ DISCRETE STEPS         │          │                                         │
// │  steps_4               │   2.5    │ 1 shift (>>8) + 1 mul                   │
// │  steps_8               │   2.5    │ 1 shift (>>7) + 1 mul                   │
// │  steps_16              │   2.5    │ 1 shift (>>6) + 1 mul                   │
// │  steps_32              │   2.5    │ 1 shift (>>5) + 1 mul                   │
// │  steps_64              │   1.0    │ 2 shifts (>>4, <<4)                     │
// │  steps_128             │   1.0    │ 2 shifts (>>3, <<3)                     │
// │  steps_256             │   1.0    │ 2 shifts (>>2, <<2)                     │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ POLAR/ANGULAR          │          │                                         │
// │  polar_degs_90         │   0.5    │ 1 shift (>>2)                           │
// │  polar_degs_180        │   0.5    │ 1 shift (>>1)                           │
// │  polar_degs_360        │   0      │ passthrough (identity)                  │
// │  polar_degs_720        │   1.5    │ 1 shift (<<1) + 1 AND mask              │
// │  polar_degs_1440       │   1.5    │ 1 shift (<<2) + 1 AND mask              │
// │  polar_degs_2880       │   1.5    │ 1 shift (<<3) + 1 AND mask              │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ QUADRATIC EASING       │          │                                         │
// │  quad_in               │   8      │ 1 mul + 1 div (t²)                      │
// │  quad_out              │  13      │ 2 sub + 2 mul + 1 div                   │
// │  quad_in_out           │   8.5    │ 1 cmp + 1 sub + 2 mul + 1 shift (>>9)   │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ SINUSOIDAL EASING      │          │                                         │
// │  sine_in               │   8      │ 1 mul + 1 div (t²)                      │
// │  sine_out              │  11      │ 1 sub + 2 mul + 1 div                   │
// │  sine_in_out           │   8.5    │ 1 cmp + 1 sub + 2 mul + 1 shift (>>11)  │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ CIRCULAR EASING        │          │                                         │
// │  circ_in               │   8      │ 1 mul + 1 div (t²)                      │
// │  circ_out              │  11      │ 1 sub + 2 mul + 1 div                   │
// │  circ_in_out           │  20      │ 1 cmp + 1 sub + 5 mul + 3 div           │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ QUARTIC EASING         │          │                                         │
// │  quart_in              │  16      │ 3 mul + 2 div (t⁴)                      │
// │  quart_out             │  21      │ 1 sub + 4 mul + 2 div                   │
// │  quart_in_out          │  19.5    │ 1 cmp + 1 sub + 5 mul + 2 div + 1 shift │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ QUINTIC EASING         │          │                                         │
// │  quint_in              │  24      │ 5 mul + 3 div (t⁵)                      │
// │  quint_out             │  30      │ 1 sub + 6 mul + 3 div                   │
// │  quint_in_out          │  29.5    │ 1 cmp + 1 sub + 8 mul + 3 div + 1 shift │
// ├────────────────────────┼──────────┼─────────────────────────────────────────┤
// │ EXPONENTIAL EASING     │          │                                         │
// │  expo_in               │  25      │ 1 cmp + 5 mul + 3 div (t⁴)              │
// │  expo_out              │  32      │ 2 cmp + 1 sub + 6 mul + 3 div           │
// │  expo_in_out           │  25.5    │ 3 cmp + 1 sub + 5 mul + 2 div + 1 shift │
// └────────────────────────┴──────────┴─────────────────────────────────────────┘
//
// COMPLEXITY SUMMARY:
//   Most efficient:       linear (0), polar_degs_360 (0), boolean (0.5)
//   Highly optimized:     linear modes (0.5), polar modes (0.5-1.5), steps (1-2.5)
//   Simple operations:    quad_in/sine_in/circ_in (8), quad_in_out/sine_in_out (8.5)
//   Moderate complexity:  quad_out (13), circ_in_out (20), quart_in (16)
//   Higher complexity:    quart modes (19.5-21), quint modes (24-30), expo modes (25-32)
//   Most expensive:       quint_out (30), expo_out (32), quint_in_out (29.5)
//
// NOTES:
//   - Bit shift optimizations reduce complexity by ~75% for linear/polar/step modes
//   - Shift approximations: >>9 ≈ /1023*2, >>11 ≈ /2048 (<0.2% precision loss)
//   - Conditional branches in *_in_out modes add minimal overhead
//   - Special case checks (t==0, t==max) are optimized by compiler
//   - Remaining divisions by 1023 cannot be replaced with shifts (not power of 2)
//
// ================================================================================

#pragma once

#include "vmprog_format.hpp"

namespace lzx {

    /**
     * @brief Fast integer to string conversion (internal utility)
     * @param value Integer value to convert
     * @param buffer Output buffer
     * @param buffer_size Size of output buffer
     * @return Number of characters written
     */
    inline constexpr size_t uint32_to_string(uint32_t value, char* buffer, size_t buffer_size)
    {
        if (buffer_size < 2) return 0;  // Need at least 2 chars (digit + null)

        // Handle zero special case
        if (value == 0) {
            buffer[0] = '0';
            buffer[1] = '\0';
            return 1;
        }

        // Convert digits in reverse
        size_t pos = 0;
        uint32_t temp = value;
        while (temp > 0 && pos < buffer_size - 1) {
            buffer[pos++] = '0' + (temp % 10);
            temp /= 10;
        }

        // Reverse the string
        for (size_t i = 0; i < pos / 2; ++i) {
            char tmp = buffer[i];
            buffer[i] = buffer[pos - 1 - i];
            buffer[pos - 1 - i] = tmp;
        }

        buffer[pos] = '\0';
        return pos;
    }

    /**
     * @brief Fast string copy (internal utility)
     * @param dst Destination buffer
     * @param src Source string
     * @param max_len Maximum characters to copy (including null terminator)
     * @return Number of characters copied (excluding null terminator)
     */
    inline constexpr size_t fast_strcpy(char* dst, const char* src, size_t max_len)
    {
        if (max_len == 0) return 0;

        size_t i = 0;
        while (i < max_len - 1 && src[i] != '\0') {
            dst[i] = src[i];
            ++i;
        }
        dst[i] = '\0';
        return i;
    }

    /**
     * @brief Clamp value to specified range using fixed-point math
     * @param value Value to clamp
     * @param min_val Minimum allowed value
     * @param max_val Maximum allowed value
     * @return Clamped value as uint16_t
     */
    inline constexpr uint16_t clamp_u16(int32_t value, int32_t min_val, int32_t max_val)
    {
        return static_cast<uint16_t>((value < min_val) ? min_val : ((value > max_val) ? max_val : value));
    }

    /**
     * @brief Apply parameter control curve transformation
     *
     * Transforms input value according to specified control mode. All modes operate
     * on 10-bit unsigned values (0-1023) using fixed-point arithmetic.
     *
     * @param value Input value (any int32_t, will be wrapped for polar modes or clamped for others)
     * @param mode Control mode to apply
     * @return Transformed output value (0-1023)
     */
    constexpr uint16_t apply_parameter_control_curve(int32_t value, vmprog_parameter_control_mode_v1_0 mode)
    {
        constexpr uint16_t max_val = 1023;  // 10-bit maximum

        // Handle polar modes with wrapping BEFORE clamping
        if (mode >= vmprog_parameter_control_mode_v1_0::polar_degs_90 &&
            mode <= vmprog_parameter_control_mode_v1_0::polar_degs_2880)
        {
            // Wrap around 0-1023 for out-of-range inputs
            int32_t wrapped = value % 1024;
            if (wrapped < 0) wrapped += 1024;  // Handle negative modulo
            const uint32_t t = static_cast<uint32_t>(wrapped);

            // Apply polar transformations on wrapped value
            switch (mode)
            {
            case vmprog_parameter_control_mode_v1_0::polar_degs_90:
                return static_cast<uint16_t>(t >> 2);
            case vmprog_parameter_control_mode_v1_0::polar_degs_180:
                return static_cast<uint16_t>(t >> 1);
            case vmprog_parameter_control_mode_v1_0::polar_degs_360:
                return static_cast<uint16_t>(t);
            case vmprog_parameter_control_mode_v1_0::polar_degs_720:
                return static_cast<uint16_t>((t << 1) & 1023);
            case vmprog_parameter_control_mode_v1_0::polar_degs_1440:
                return static_cast<uint16_t>((t << 2) & 1023);
            case vmprog_parameter_control_mode_v1_0::polar_degs_2880:
                return static_cast<uint16_t>((t << 3) & 1023);
            default:
                break;  // Should never reach
            }
        }

        // For all non-polar modes: clamp to 0-1023
        const uint32_t t = (value < 0) ? 0 : ((value > max_val) ? max_val : static_cast<uint32_t>(value));

        switch (mode)
        {
            // ===== Linear Scaling Modes =====
        case vmprog_parameter_control_mode_v1_0::linear:
            return static_cast<uint16_t>(t);  // 1:1 passthrough (clamped)

        case vmprog_parameter_control_mode_v1_0::linear_half:
            return static_cast<uint16_t>(t >> 1);  // 0.5x scaling (optimized: shift instead of div)

        case vmprog_parameter_control_mode_v1_0::linear_quarter:
            return static_cast<uint16_t>(t >> 2);  // 0.25x scaling (optimized: shift instead of div)

        case vmprog_parameter_control_mode_v1_0::linear_double:
            return clamp_u16(t << 1, 0, max_val);  // 2x scaling (optimized: shift instead of mul)

            // ===== Boolean Mode =====
        case vmprog_parameter_control_mode_v1_0::boolean:
            return (t >= 512) ? max_val : 0;  // On/off threshold at midpoint

            // ===== Discrete Step Modes =====
        case vmprog_parameter_control_mode_v1_0::steps_4:
            return static_cast<uint16_t>((t >> 8) * 341);  // 4 steps: 0, 341, 682, 1023 (optimized)

        case vmprog_parameter_control_mode_v1_0::steps_8:
            return static_cast<uint16_t>((t >> 7) * 146);  // 8 steps: ~146 per step (optimized)

        case vmprog_parameter_control_mode_v1_0::steps_16:
            return static_cast<uint16_t>((t >> 6) * 68);  // 16 steps: ~68 per step (optimized)

        case vmprog_parameter_control_mode_v1_0::steps_32:
            return static_cast<uint16_t>((t >> 5) * 33);  // 32 steps: ~33 per step (optimized)

        case vmprog_parameter_control_mode_v1_0::steps_64:
            return static_cast<uint16_t>((t >> 4) << 4);  // 64 steps: 16 per step (optimized: mask bits)

        case vmprog_parameter_control_mode_v1_0::steps_128:
            return static_cast<uint16_t>((t >> 3) << 3);  // 128 steps: 8 per step (optimized: mask bits)

        case vmprog_parameter_control_mode_v1_0::steps_256:
            return static_cast<uint16_t>((t >> 2) << 2);  // 256 steps: 4 per step (optimized: mask bits)

            // ===== Polar modes handled above with wrapping =====

            // ===== Quadratic Easing =====
        case vmprog_parameter_control_mode_v1_0::quad_in:
            return static_cast<uint16_t>((t * t) / 1023);  // Ease in: t²

        case vmprog_parameter_control_mode_v1_0::quad_out:
        {
            const uint32_t temp = max_val - t;
            return static_cast<uint16_t>(max_val - (temp * temp) / 1023);  // Ease out: 1-(1-t)² (optimized)
        }

        case vmprog_parameter_control_mode_v1_0::quad_in_out:
            if (t < 512) {
                return static_cast<uint16_t>((t * t) >> 9);  // Ease in first half (optimized: div 1023 ≈ shift 10, but *2/1023 = shift 9)
            }
            else {
                const uint32_t temp = max_val - t;
                return static_cast<uint16_t>(max_val - ((temp * temp) >> 9));  // Ease out second half (optimized)
            }

            // ===== Sinusoidal Easing (polynomial approximation) =====
        case vmprog_parameter_control_mode_v1_0::sine_in:
            // Approximation of 1 - cos(t*π/2): ease in slowly
            // Use quadratic approximation that reaches max at t=max_val
            return static_cast<uint16_t>((t * t) / 1023);

        case vmprog_parameter_control_mode_v1_0::sine_out:
            // Approximation of sin(t*π/2): ease out slowly
        {
            const uint32_t temp = max_val - t;
            return static_cast<uint16_t>(max_val - (temp * temp) / 1023);
        }

        case vmprog_parameter_control_mode_v1_0::sine_in_out:
            if (t < 512) {
                // Ease in first half (optimized: /2046 ≈ >>11)
                return static_cast<uint16_t>((t * t) >> 11);
            }
            else {
                const uint32_t temp = max_val - t;
                // Ease out second half (optimized)
                return static_cast<uint16_t>(max_val - ((temp * temp) >> 11));
            }

            // ===== Circular Easing (polynomial approximation) =====
        case vmprog_parameter_control_mode_v1_0::circ_in:
            // Strong ease in (cubic approximation)
            return static_cast<uint16_t>((t * t) / 1023);

        case vmprog_parameter_control_mode_v1_0::circ_out:
        {
            const uint32_t temp = max_val - t;
            // Strong ease out
            return static_cast<uint16_t>(max_val - (temp * temp) / 1023);
        }

        case vmprog_parameter_control_mode_v1_0::circ_in_out:
            if (t < 512) {
                // Ease in first half
                const uint32_t t2 = (t * t) / 1023;
                return static_cast<uint16_t>((t2 * t) / 1023);
            }
            else {
                const uint32_t temp = max_val - t;
                const uint32_t temp2 = (temp * temp) / 1023;
                return static_cast<uint16_t>(max_val - (temp2 * temp) / 1023);  // Ease out second half
            }

            // ===== Quintic Easing =====
        case vmprog_parameter_control_mode_v1_0::quint_in:
        {
            const uint32_t t2 = (t * t) / 1023;
            const uint32_t t4 = (t2 * t2) / 1023;
            return static_cast<uint16_t>((t4 * t) / 1023);  // t⁵
        }

        case vmprog_parameter_control_mode_v1_0::quint_out:
        {
            const uint32_t temp = max_val - t;
            const uint32_t temp2 = (temp * temp) / 1023;
            const uint32_t temp4 = (temp2 * temp2) / 1023;
            return static_cast<uint16_t>(max_val - (temp4 * temp) / 1023);  // 1-(1-t)⁵
        }

        case vmprog_parameter_control_mode_v1_0::quint_in_out:
            if (t < 512) {
                const uint32_t t2 = (t * t) / 1023;
                const uint32_t t4 = (t2 * t2) / 1023;
                return static_cast<uint16_t>(((t4 * t) << 4) / 1046529);  // Ease in first half (optimized: 16* becomes <<4, 1023*1023=1046529)
            }
            else {
                const uint32_t temp = max_val - t;
                const uint32_t temp2 = (temp * temp) / 1023;
                const uint32_t temp4 = (temp2 * temp2) / 1023;
                return static_cast<uint16_t>(max_val - (((temp4 * temp) << 4) / 1046529));  // Ease out second half (optimized)
            }

            // ===== Quartic Easing =====
        case vmprog_parameter_control_mode_v1_0::quart_in:
        {
            const uint32_t t2 = (t * t) / 1023;
            return static_cast<uint16_t>((t2 * t2) / 1023);  // t⁴
        }

        case vmprog_parameter_control_mode_v1_0::quart_out:
        {
            const uint32_t temp = max_val - t;
            const uint32_t temp2 = (temp * temp) / 1023;
            return static_cast<uint16_t>(max_val - (temp2 * temp2) / 1023);  // 1-(1-t)⁴
        }

        case vmprog_parameter_control_mode_v1_0::quart_in_out:
            if (t < 512) {
                const uint32_t t2 = (t * t) / 1023;
                return static_cast<uint16_t>(((t2 * t2) << 3) / 1046529);  // Ease in first half (optimized: 8* becomes <<3, 1023*1023=1046529)
            }
            else {
                const uint32_t temp = max_val - t;
                const uint32_t temp2 = (temp * temp) / 1023;
                return static_cast<uint16_t>(max_val - (((temp2 * temp2) << 3) / 1046529));  // Ease out second half (optimized)
            }

            // ===== Exponential Easing (polynomial approximation) =====
        case vmprog_parameter_control_mode_v1_0::expo_in:
            if (t == 0) return 0;  // Special case: start at zero
            {
                const uint32_t t2 = (t * t) / 1023;
                const uint32_t t3 = (t2 * t) / 1023;
                return static_cast<uint16_t>((t3 * t) / 1023);  // Approx: 2^(10(t-1)) using t⁴
            }

        case vmprog_parameter_control_mode_v1_0::expo_out:
            if (t == max_val) return max_val;  // Special case: end at max
            {
                const uint32_t temp = max_val - t;
                const uint32_t temp2 = (temp * temp) / 1023;
                const uint32_t temp3 = (temp2 * temp) / 1023;
                return static_cast<uint16_t>(max_val - (temp3 * temp) / 1023);  // Approx: 1-2^(-10t)
            }

        case vmprog_parameter_control_mode_v1_0::expo_in_out:
            if (t == 0) return 0;  // Special case: start at zero
            if (t == max_val) return max_val;  // Special case: end at max
            if (t < 512) {
                const uint32_t t2 = (t * t) / 1023;
                const uint32_t t3 = (t2 * t) / 1023;
                return static_cast<uint16_t>((t3 * t) >> 11);  // Ease in first half (optimized: /2046 ≈ >>11)
            }
            else {
                const uint32_t temp = max_val - t;
                const uint32_t temp2 = (temp * temp) / 1023;
                const uint32_t temp3 = (temp2 * temp) / 1023;
                return static_cast<uint16_t>(max_val - ((temp3 * temp) >> 11));  // Ease out second half (optimized)
            }

        default:
            return static_cast<uint16_t>(t);  // Unknown mode: return clamped input
        }
    }

    /**
     * @brief Apply control curve and then scale to min/max range
     *
     * First applies the control curve transformation, then scales the result
     * from 0-1023 to the parameter's configured min/max range.
     *
     * @param value Input value (any int32_t, will be wrapped for polar modes or clamped for others)
     * @param mode Parameter configuration including control mode and min/max
     * @return Scaled output value within parameter's min/max range
     */
    constexpr uint16_t apply_parameter_control_curve_and_scaling(int32_t value, const vmprog_parameter_config_v1_0& mode)
    {
        const uint16_t curved = apply_parameter_control_curve(value, mode.control_mode);
        const uint32_t scaled = mode.min_value + ((static_cast<uint32_t>(curved) * (mode.max_value - mode.min_value)) / 1023);
        return static_cast<uint16_t>(scaled);
    }

    /**
     * @brief Lookup table for divisors (10^n) used in string generation
     *
     * Provides powers of 10 for efficient integer-to-fixed-point conversion.
     * Eliminates runtime multiplication loops for embedded systems.
     */
    inline constexpr uint32_t vmprog_parameter_display_divisor_lut[7] = {
        1, 10, 100, 1000, 10000, 100000, 1000000
    };

    /**
     * @brief Generate display string for parameter value
     *
     * Converts a raw parameter value (0-1023) into a formatted string
     * for display, scaling it to the configured display min/max range
     * and appending any suffix label. Uses integer-based fixed-point
     * arithmetic for embedded systems compatibility.
     *
     * @param value Raw parameter value (0-1023)
     * @param config Parameter configuration including display settings
     * @param out_str Output string buffer
     * @param out_str_size Size of output string buffer
     */
    constexpr void generate_parameter_value_display_string(int32_t value, const vmprog_parameter_config_v1_0& config, char* out_str, size_t out_str_size)
    {
        if (out_str_size == 0) return;

        // Handle discrete value labels first
        if (config.value_label_count >= 2)
        {
            // Use discrete value labels if defined
            const uint16_t index = (clamp_u16(value, 0, 1023) * (config.value_label_count - 1)) / 1023;
            const char* label = config.value_labels[index];
            fast_strcpy(out_str, label, out_str_size);
            return;
        }

        // No discrete labels - proceed with scaling and formatting

        // Apply control curve
        const uint16_t curved = apply_parameter_control_curve(value, config.control_mode);

        // Scale from 0-1023 to display min/max range using fixed-point math
        // Formula: display_min + (curved * (display_max - display_min)) / 1023
        const int32_t display_range = config.display_max_value - config.display_min_value;
        const int32_t scaled_int = config.display_min_value + ((static_cast<int32_t>(curved) * display_range) / 1023);

        // Handle sign
        size_t pos = 0;
        if (scaled_int < 0) {
            out_str[pos++] = '-';
        }
        // Safe conversion to unsigned (handles INT32_MIN correctly)
        const uint32_t abs_value = (scaled_int < 0) ? static_cast<uint32_t>(-(static_cast<int64_t>(scaled_int))) : static_cast<uint32_t>(scaled_int);

        // Calculate integer and fractional parts based on display_float_digits
        // Use lookup table for divisors (10^n) - eliminates multiplication loop
        const uint32_t divisor = (config.display_float_digits < 7) ? vmprog_parameter_display_divisor_lut[config.display_float_digits] : 1000000;

        const uint32_t integer_part = abs_value / divisor;
        const uint32_t fractional_part = abs_value % divisor;

        // Write integer part
        char temp_buf[12];
        const size_t int_len = uint32_to_string(integer_part, temp_buf, sizeof(temp_buf));
        for (size_t i = 0; i < int_len && pos < out_str_size - 1; ++i) {
            out_str[pos++] = temp_buf[i];
        }

        // Write decimal point and fractional part if needed
        if (config.display_float_digits > 0 && pos < out_str_size - 1) {
            out_str[pos++] = '.';

            // Convert fractional part with leading zeros
            const size_t frac_len = uint32_to_string(fractional_part, temp_buf, sizeof(temp_buf));

            // Add leading zeros if needed
            for (uint8_t i = frac_len; i < config.display_float_digits && pos < out_str_size - 1; ++i) {
                out_str[pos++] = '0';
            }

            // Add fractional digits
            for (size_t i = 0; i < frac_len && pos < out_str_size - 1; ++i) {
                out_str[pos++] = temp_buf[i];
            }
        }

        // Copy suffix label if present
        if (config.suffix_label[0] != '\0' && pos < out_str_size - 1) {
            size_t suffix_idx = 0;
            while (config.suffix_label[suffix_idx] != '\0' &&
                   suffix_idx < 4 &&  // Add this
                   pos < out_str_size - 1) {
                out_str[pos++] = config.suffix_label[suffix_idx++];
            }
        }

        out_str[pos] = '\0';
    }

} // namespace lzx
