-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: yuv_amplifier.vhd - YUV Amplifier Program for Videomancer
-- License: GNU General Public License v3.0
-- https://github.com/lzxindustries/videomancer-sdk
--
-- This file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- Program Name:
--   YUV Amplifier
--
-- Author:
--   Lars Larsen
--
-- Overview:
--   This program provides per-channel contrast and brightness adjustment, color
--   inversion, and fade effects. The design uses a pipelined architecture with
--   a total latency of 14 clock cycles, ensuring proper timing alignment
--   between the video data and sync signals.
--
-- Architecture:
--   Input Stage:
--     - Channel inversion logic (optional inversion of Y, U, V channels)
--     - Fade color selection (black or white target)
--     - 1 clock latency
--
--   Processing Stage:
--     - Three proc_amp_u instances for Y, U, V contrast/brightness adjustment
--     - 9 clock latency per channel
--
--   Fade/Mix Stage:
--     - Three interpolator_u instances for fade effect
--     - Y channel: fade between selected color (black/white) and processed Y
--     - U/V channels: fade toward neutral (512) for desaturation
--     - 4 clock latency per channel
--
--   Bypass and Output:
--     - Optional bypass mode to pass through unprocessed video
--     - Delay line compensates for 14-clock processing pipeline
--
-- Submodules:
--   proc_amp_u: Unsigned process amplifier
--     - Applies contrast (multiplication) followed by brightness (addition)
--     - Operates on 10-bit unsigned video data
--     - 9 clock pipeline stages
--
--   interpolator_u: Unsigned linear interpolator
--     - Performs linear interpolation: result = a + (b - a) * t
--     - Used for fade effects where t is the fade amount
--     - 4 clock pipeline stages
--
-- Register Map:
--   Compatible with Videomancer ABI 1.x
--   Register 0: Y contrast (0-1023, 512 = unity gain)
--   Register 1: U contrast (0-1023, 512 = unity gain)
--   Register 2: V contrast (0-1023, 512 = unity gain)
--   Register 3: Y brightness (0-1023, 512 = no offset)
--   Register 4: U brightness (0-1023, 512 = no offset)
--   Register 5: V brightness (0-1023, 512 = no offset)
--   Register 6: Control flags
--     Bit 0: Invert Y channel
--     Bit 1: Invert U channel
--     Bit 2: Invert V channel
--     Bit 3: Fade color select (0=black, 1=white)
--     Bit 4: Bypass enable (1=bypass processing)
--   Register 7: Fade amount (0-1023, 0=full effect, 1023=neutral/original)
--
-- Timing:
--   Total pipeline latency: 14 clocks
--   - Inversion: 1 clock
--   - Process amp: 9 clocks
--   - Interpolator: 4 clocks
--   All sync signals are delayed to match video data path

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
use work.core_pkg.all;
use work.video_stream_pkg.all;
use work.video_timing_pkg.all;

architecture yuv_amplifier of program_top is
    --------------------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------------------
    -- Total pipeline latency: 1 (inversion) + 9 (proc_amp_u) + 4 (interpolator_u)
    constant C_PROCESSING_DELAY_CLKS : integer := 14;

    --------------------------------------------------------------------------------
    -- Control Signals (from registers)
    --------------------------------------------------------------------------------
    signal s_bypass_enable        : std_logic;
    signal s_invert_y             : std_logic;
    signal s_invert_u             : std_logic;
    signal s_invert_v             : std_logic;
    signal s_fade_color           : std_logic;  -- 0=black, 1=white
    signal s_fade_amount          : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    --------------------------------------------------------------------------------
    -- Stage 1: Inversion Stage Signals
    --------------------------------------------------------------------------------
    signal s_inverted_y           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_inverted_u           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_inverted_v           : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_inverted_valid       : std_logic;
    signal s_fade_color_value     : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);

    --------------------------------------------------------------------------------
    -- Stage 2: Process Amplifier (Contrast/Brightness) Signals
    --------------------------------------------------------------------------------
    -- Y channel
    signal s_proc_y_contrast      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_y_brightness    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_y_result        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_y_valid         : std_logic;
    -- U channel
    signal s_proc_u_contrast      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_u_brightness    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_u_result        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_u_valid         : std_logic;
    -- V channel
    signal s_proc_v_contrast      : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_v_brightness    : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_v_result        : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_proc_v_valid         : std_logic;
    -- Combined valid (for monitoring)
    signal s_proc_valid           : std_logic;

    --------------------------------------------------------------------------------
    -- Stage 3: Interpolator (Fade) Signals
    --------------------------------------------------------------------------------
    signal s_interpolator_y_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_interpolator_y_valid  : std_logic;
    signal s_interpolator_u_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_interpolator_u_valid  : std_logic;
    signal s_interpolator_v_result : unsigned(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_interpolator_v_valid  : std_logic;

    --------------------------------------------------------------------------------
    -- Bypass Path Delay Line (matches processing pipeline latency)
    --------------------------------------------------------------------------------
    signal s_hsync_n_delayed      : std_logic;
    signal s_vsync_n_delayed      : std_logic;
    signal s_field_n_delayed      : std_logic;
    signal s_y_delayed            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_u_delayed            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);
    signal s_v_delayed            : std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

begin
    --------------------------------------------------------------------------------
    -- Register Mapping (Concurrent Assignments)
    --------------------------------------------------------------------------------
    -- Contrast controls: 0-1023, where 512 = unity gain (1.0x)
    s_proc_y_contrast   <= unsigned(registers_in(0));  -- Register 0: Y contrast
    s_proc_u_contrast   <= unsigned(registers_in(1));  -- Register 1: U contrast
    s_proc_v_contrast   <= unsigned(registers_in(2));  -- Register 2: V contrast

    -- Brightness controls: 0-1023, where 512 = no offset
    s_proc_y_brightness <= unsigned(registers_in(3));  -- Register 3: Y brightness
    s_proc_u_brightness <= unsigned(registers_in(4));  -- Register 4: U brightness
    s_proc_v_brightness <= unsigned(registers_in(5));  -- Register 5: V brightness

    -- Control flags: Register 6
    s_invert_y          <= registers_in(6)(0);         -- Bit 0: Invert Y channel
    s_invert_u          <= registers_in(6)(1);         -- Bit 1: Invert U channel
    s_invert_v          <= registers_in(6)(2);         -- Bit 2: Invert V channel
    s_fade_color        <= registers_in(6)(3);         -- Bit 3: Fade color (0=black, 1=white)
    s_bypass_enable     <= registers_in(6)(4);         -- Bit 4: Bypass processing

    -- Fade amount: 0-1023, where 0 = full fade, 1023 = no fade
    s_fade_amount       <= unsigned(registers_in(7));  -- Register 7: Fade amount

    --------------------------------------------------------------------------------
    -- Stage 1: Input Processing (Inversion and Fade Target Selection)
    -- Latency: 1 clock cycle
    --------------------------------------------------------------------------------
    p_input_stage : process (clk)
    begin
        if rising_edge(clk) then
            -- Y channel inversion: Conditionally invert during active video
            -- Inversion is performed by bitwise NOT operation
            if data_in.avid = '1' and s_invert_y = '1' then
                s_inverted_y <= unsigned(not std_logic_vector(unsigned(data_in.y)));
            else
                s_inverted_y <= unsigned(data_in.y);
            end if;

            -- U channel inversion
            if data_in.avid = '1' and s_invert_u = '1' then
                s_inverted_u <= unsigned(not std_logic_vector(unsigned(data_in.u)));
            else
                s_inverted_u <= unsigned(data_in.u);
            end if;

            -- V channel inversion
            if data_in.avid = '1' and s_invert_v = '1' then
                s_inverted_v <= unsigned(not std_logic_vector(unsigned(data_in.v)));
            else
                s_inverted_v <= unsigned(data_in.v);
            end if;

            s_inverted_valid <= data_in.avid;

            if s_fade_color = '1' then
                s_fade_color_value <= to_unsigned(1023, C_VIDEO_DATA_WIDTH); -- White
            else
                s_fade_color_value <= to_unsigned(0, C_VIDEO_DATA_WIDTH); -- Black
            end if;
        end if;
    end process p_input_stage;

    --------------------------------------------------------------------------------
    -- Stage 2: Process Amplifiers (Contrast and Brightness Adjustment)
    -- Latency: 9 clock cycles per channel
    -- Operation: result = (input * contrast) + brightness
    --------------------------------------------------------------------------------

    -- Y channel process amplifier
    -- Applies contrast multiplication followed by brightness addition
    proc_amp_y : entity work.proc_amp_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH
        )
        port map(
            clk        => clk,
            enable     => s_inverted_valid,
            a          => s_inverted_y,
            contrast   => s_proc_y_contrast,
            brightness => s_proc_y_brightness,
            result     => s_proc_y_result,
            valid      => s_proc_y_valid
        );

    -- U channel process amplifier
    proc_amp_u : entity work.proc_amp_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH
        )
        port map(
            clk        => clk,
            enable     => s_inverted_valid,
            a          => s_inverted_u,
            contrast   => s_proc_u_contrast,
            brightness => s_proc_u_brightness,
            result     => s_proc_u_result,
            valid      => s_proc_u_valid
        );

    -- V channel process amplifier
    proc_amp_v : entity work.proc_amp_u
        generic map(
            G_WIDTH => C_VIDEO_DATA_WIDTH
        )
        port map(
            clk        => clk,
            enable     => s_inverted_valid,
            a          => s_inverted_v,
            contrast   => s_proc_v_contrast,
            brightness => s_proc_v_brightness,
            result     => s_proc_v_result,
            valid      => s_proc_v_valid
        );

    -- Combined valid signal (all channels must be valid)
    s_proc_valid <= s_proc_y_valid and s_proc_u_valid and s_proc_v_valid;

    --------------------------------------------------------------------------------
    -- Stage 3: Interpolators (Fade Effects)
    -- Latency: 4 clock cycles per channel
    -- Operation: result = a + (b - a) * t
    -- Y channel: Fades between target color (black/white) and processed Y
    -- U/V channels: Fade toward neutral (512) for desaturation effect
    --------------------------------------------------------------------------------

    -- Y channel interpolator: Fade to black or white
    -- When t=0: full fade (result = fade_color_value)
    -- When t=1023: no fade (result = proc_y_result)
    interpolator_y : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_y_valid,
            a      => s_fade_color_value,    -- Fade target (black or white)
            b      => s_proc_y_result,        -- Processed Y value
            t      => s_fade_amount,          -- Interpolation factor
            result => s_interpolator_y_result,
            valid  => s_interpolator_y_valid
        );

    -- U channel interpolator: Fade toward neutral (desaturation)
    -- When t=0: full desaturation (result = 512, neutral chroma)
    -- When t=1023: full saturation (result = proc_u_result)
    interpolator_u : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_u_valid,
            a      => to_unsigned(512, C_VIDEO_DATA_WIDTH),  -- Neutral U (gray)
            b      => s_proc_u_result,                        -- Processed U value
            t      => s_fade_amount,                          -- Interpolation factor
            result => s_interpolator_u_result,
            valid  => s_interpolator_u_valid
        );

    -- V channel interpolator: Fade toward neutral (desaturation)
    interpolator_v : entity work.interpolator_u
        generic map(
            G_WIDTH      => C_VIDEO_DATA_WIDTH,
            G_FRAC_BITS  => C_VIDEO_DATA_WIDTH,
            G_OUTPUT_MIN => 0,
            G_OUTPUT_MAX => 1023
        )
        port map(
            clk    => clk,
            enable => s_proc_v_valid,
            a      => to_unsigned(512, C_VIDEO_DATA_WIDTH),  -- Neutral V (gray)
            b      => s_proc_v_result,                        -- Processed V value
            t      => s_fade_amount,                          -- Interpolation factor
            result => s_interpolator_v_result,
            valid  => s_interpolator_v_valid
        );

    --------------------------------------------------------------------------------
    -- Bypass Path Delay Line
    -- Delays input signals by C_PROCESSING_DELAY_CLKS to match processing latency
    -- This allows seamless switching between processed and bypass modes
    --------------------------------------------------------------------------------
    p_bypass_delay : process (clk)
        -- Delay line types: arrays indexed 0 (newest) to DELAY_CLKS-1 (oldest)
        type t_sync_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1) of std_logic;
        type t_data_delay is array (0 to C_PROCESSING_DELAY_CLKS - 1) of std_logic_vector(C_VIDEO_DATA_WIDTH - 1 downto 0);

        -- Shift register variables (initialized to safe defaults)
        variable v_hsync_delay : t_sync_delay := (others => '1');  -- Sync inactive high
        variable v_vsync_delay : t_sync_delay := (others => '1');  -- Sync inactive high
        variable v_field_delay : t_sync_delay := (others => '1');  -- Field inactive high
        variable v_y_delay     : t_data_delay := (others => (others => '0'));
        variable v_u_delay     : t_data_delay := (others => (others => '0'));
        variable v_v_delay     : t_data_delay := (others => (others => '0'));
    begin
        if rising_edge(clk) then
            -- Shift all delay lines: prepend new data, drop oldest
            -- This implements a FIFO structure where index 0 is newest
            v_hsync_delay := data_in.hsync_n & v_hsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_vsync_delay := data_in.vsync_n & v_vsync_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_field_delay := data_in.field_n & v_field_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_y_delay     := data_in.y       & v_y_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_u_delay     := data_in.u       & v_u_delay(0 to C_PROCESSING_DELAY_CLKS - 2);
            v_v_delay     := data_in.v       & v_v_delay(0 to C_PROCESSING_DELAY_CLKS - 2);

            -- Output the oldest values (index DELAY_CLKS-1)
            -- These are aligned with the processed video output
            s_hsync_n_delayed <= v_hsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_vsync_n_delayed <= v_vsync_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_field_n_delayed <= v_field_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_y_delayed       <= v_y_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_u_delayed       <= v_u_delay(C_PROCESSING_DELAY_CLKS - 1);
            s_v_delayed       <= v_v_delay(C_PROCESSING_DELAY_CLKS - 1);
        end if;
    end process p_bypass_delay;

    --------------------------------------------------------------------------------
    -- Output Multiplexing and Assignment
    -- Selects between processed video (normal mode) and delayed input (bypass mode)
    --------------------------------------------------------------------------------

    -- Video data outputs: Choose processed or bypassed data
    -- When bypass_enable = '0': Output fully processed video (with all effects)
    -- When bypass_enable = '1': Output delayed input (unprocessed, latency-matched)
    data_out.y <= std_logic_vector(s_interpolator_y_result) when s_bypass_enable = '0' else
                  s_y_delayed;

    data_out.u <= std_logic_vector(s_interpolator_u_result) when s_bypass_enable = '0' else
                  s_u_delayed;

    data_out.v <= std_logic_vector(s_interpolator_v_result) when s_bypass_enable = '0' else
                  s_v_delayed;

    -- Valid signal: Active when all interpolators have valid output
    -- This indicates when processed data is available and stable
    data_out.avid <= s_interpolator_y_valid and
                     s_interpolator_u_valid and
                     s_interpolator_v_valid;

    -- Sync signals: Always use delayed versions (matched to processing latency)
    -- These ensure proper timing alignment regardless of bypass state
    data_out.hsync_n <= s_hsync_n_delayed;
    data_out.vsync_n <= s_vsync_n_delayed;
    data_out.field_n <= s_field_n_delayed;

end yuv_amplifier;