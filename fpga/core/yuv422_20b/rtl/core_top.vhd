-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: core.vhd - Common top level architecture for all YUV Core programs
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

--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_timing_pkg.all;
use work.video_stream_pkg.all;
use work.core_config_pkg.all;
use work.core_pkg.all;
use work.all;

entity core_top is
  port(
    -- host communication
    i_spi_sck               : in    std_logic;
    i_spi_sdo               : inout std_logic;
    i_spi_sdi               : in    std_logic;
    i_spi_cs_n              : in    std_logic;
    -- Pin 128 (RP2040_GPOUT_CLK) is driven by the FPGA in all bitstream
    -- variants as a debug AVID heartbeat to the MCU. The legacy
    -- `i_mcu_ref_clk` input port is retained for backward port-map
    -- compatibility but is no longer used: standalone bitstreams now
    -- derive their pixel clock reference from the ADV7181C LLC clock
    -- (i_vid_dec_clk), which the decoder is configured to generate even
    -- when its analog video frontend is otherwise disabled.
    o_mcu_gpout_clk         : out   std_logic;
    i_mcu_ref_clk           : in    std_logic;

    -- sd/hd sync output
    o_vid_sync_out_p        : out   std_logic;
    o_vid_sync_out_n        : out   std_logic;

    -- analog video input
    i_vid_dec_clk           : in    std_logic;
    i_vid_dec_d             : in    std_logic_vector(19 downto 0);
    i_vid_dec_hsync         : in    std_logic;
    i_vid_dec_vsync         : in    std_logic;
    i_vid_dec_field_de      : in    std_logic;
    o_vid_dec_hsync_in      : out   std_logic;
    o_vid_dec_vsync_in      : out   std_logic;

    -- hdmi video input
    i_hdmi_rx_clk           : in    std_logic;
    i_hdmi_rx_d             : in    std_logic_vector(23 downto 0);
    i_hdmi_rx_hsync         : in    std_logic;
    i_hdmi_rx_vsync         : in    std_logic;
    i_hdmi_rx_de            : in    std_logic;

    -- analog/hdmi video output
    o_hdmi_tx_clk   : out   std_logic;
    o_hdmi_tx_d     : out   std_logic_vector(23 downto 0);
    o_hdmi_tx_hsync : out   std_logic;
    o_hdmi_tx_vsync : out   std_logic;
    o_vid_enc_clk   : out   std_logic;
    o_vid_enc_d     : out   std_logic_vector(15 downto 0);
    o_vid_enc_hsync : out   std_logic;
    o_vid_enc_vsync : out   std_logic

  );
end entity core_top;

architecture rtl of core_top is

  signal vid_clk : std_logic := '0';
  signal s_spi_din : std_logic_vector(C_SPI_TRANSFER_DATA_BITS - 1 downto 0) := (others => '0');
  signal s_spi_dout : std_logic_vector(C_SPI_TRANSFER_DATA_BITS - 1 downto 0) := (others => '0');
  signal s_spi_wr_en : std_logic := '0';
  signal s_spi_rd_en : std_logic := '0';
  signal s_spi_addr : unsigned(C_SPI_TRANSFER_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal s_spi_ram : t_spi_ram := (others => (others => '0'));
  signal s_spi_ram_d : t_spi_ram := (others => (others => '0'));
  signal s_vsync_n_d : std_logic := '1';
  signal s_vsync_n_event : std_logic := '0';
  signal s_video_timing_id : t_video_timing_id := (others => '0');
  signal s_video_in : t_video_stream_yuv422_20b;
  signal s_program_in : t_video_stream_yuv422_20b;
  signal s_program_out : t_video_stream_yuv422_20b;
--  signal s_blanking_out : t_video_stream_yuv444;
  signal s_video_out : t_video_stream_yuv422_20b;
  signal s_o_trisync_out_p : std_logic := '0';
  signal s_o_trisync_out_n : std_logic := '0';
  signal s_o_hsync : std_logic := '0';
  signal s_o_vsync : std_logic := '0';
  signal s_o_field_n : std_logic := '0';
  signal s_o_avid : std_logic := '0';

  -- Sync reference signals for the video sync generator. Driven by the
  -- external source's HSYNC/VSYNC pins (set in each GEN_*_IN block).
  signal s_sync_ref_hsync_n : std_logic := '1';
  signal s_sync_ref_vsync_n : std_logic := '1';
  signal s_hdmi_rx_hsync_meta : std_logic := '1';
  signal s_hdmi_rx_vsync_meta : std_logic := '1';

  -- HD clock decimation signals
  signal prog_clk : std_logic := '0';
  signal s_prog_data_in : t_video_stream_yuv422_20b;
  signal s_prog_data_out : t_video_stream_yuv422_20b;
  signal s_prog_registers : t_spi_ram := (others => (others => '0'));

begin

  GEN_SD_HDMI_IN : if C_ENABLE_SD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    s_video_in.y(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0);
    s_video_in.y(1 downto 0) <= i_hdmi_rx_d(23 downto 22);
    s_video_in.c(1 downto 0) <= i_hdmi_rx_d(19 downto 18);
    -- Sync and active-video gating come from the internal free-running
    -- video sync generator (slaved to the external HDMI vsync below).
    -- The HDMI receiver's DE pin is intentionally not used.
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= i_hdmi_rx_hsync;
    s_sync_ref_vsync_n <= i_hdmi_rx_vsync;
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_HD_HDMI_IN : if C_ENABLE_HD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    s_video_in.y(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0);
    s_video_in.y(1 downto 0) <= i_hdmi_rx_d(23 downto 22);
    s_video_in.c(1 downto 0) <= i_hdmi_rx_d(19 downto 18);
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= i_hdmi_rx_hsync;
    s_sync_ref_vsync_n <= i_hdmi_rx_vsync;
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_SD_ANALOG_IN : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    -- Sync and active-video gating come from the internal free-running
    -- video sync generator (slaved to the external analog decoder vsync
    -- below). The decoder's FIELD/DE pin is intentionally not used.
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= i_vid_dec_hsync;
    s_sync_ref_vsync_n <= i_vid_dec_vsync;
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_HD_ANALOG_IN : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= i_vid_dec_hsync;
    s_sync_ref_vsync_n <= i_vid_dec_vsync;
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_SD_DUAL_IN : if C_ENABLE_SD and C_ENABLE_DUAL generate

    pll_inst : entity work.sd_video_clk_pll_2x
    port map(
      i_clk    => i_hdmi_rx_clk,
      o_clk    => o_vid_enc_clk,
      i_resetb => '1',
      i_bypass => '0'
    );

    -- Dual mode passthrough: HDMI RX -> Analog Encoder.
    -- This is the only path in the bitstream that may reference the HDMI
    -- receiver's blanking signals (HSYNC/VSYNC); DE remains unused.
    o_vid_enc_d(15 downto 8) <= i_hdmi_rx_d(15 downto 8);
    o_vid_enc_d(7 downto 0) <= i_hdmi_rx_d(7 downto 0);
    o_vid_enc_hsync <= not i_hdmi_rx_hsync;
    o_vid_enc_vsync <= not i_hdmi_rx_vsync;

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    -- Reference HDMI RX (CDC: HDMI RX clk -> vid_clk).
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_HD_DUAL_IN : if C_ENABLE_HD and C_ENABLE_DUAL generate

    o_vid_enc_clk <= i_hdmi_rx_clk;
    o_vid_enc_d(15 downto 8) <= i_hdmi_rx_d(15 downto 8);
    o_vid_enc_d(7 downto 0) <= i_hdmi_rx_d(7 downto 0);
    o_vid_enc_hsync <= not i_hdmi_rx_hsync;
    o_vid_enc_vsync <= not i_hdmi_rx_vsync;

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_SYNC_REF_DUAL_CDC : if C_ENABLE_DUAL generate
    p_sync_ref_cdc : process(vid_clk)
    begin
      if rising_edge(vid_clk) then
        s_hdmi_rx_hsync_meta <= i_hdmi_rx_hsync;
        s_sync_ref_hsync_n   <= s_hdmi_rx_hsync_meta;
        s_hdmi_rx_vsync_meta <= i_hdmi_rx_vsync;
        s_sync_ref_vsync_n   <= s_hdmi_rx_vsync_meta;
      end if;
    end process;
  end generate;

  -- ========================================================================
  -- STANDALONE INPUT GENERATES
  -- ========================================================================
  -- In standalone bitstreams the analog decoder and HDMI receiver video
  -- datapaths are disconnected from the video pipeline. The FPGA uses
  -- the ADV7181C LLC clock (i_vid_dec_clk) directly as the pixel clock:
  -- firmware configures the decoder's CP-PLL in clock-generator-only
  -- mode so the LLC frequency exactly matches the selected video timing
  -- (13.5 MHz for NTSC/PAL, 27 MHz for 480p/576p, 74.25 MHz for HD).
  -- Pin 128 (RP2040_GPOUT_CLK) is driven as a debug AVID heartbeat to
  -- the MCU, identical to all other bitstream variants.

  GEN_SD_STANDALONE_IN : if C_ENABLE_SD and C_ENABLE_STANDALONE generate
  begin
    vid_clk <= i_vid_dec_clk;

    s_video_in.y(9 downto 0) <= (others => '0');
    s_video_in.c(9 downto 0) <= (others => '0');
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= s_o_hsync;
    s_sync_ref_vsync_n <= s_o_vsync;

    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= '0';
  end generate;

  GEN_HD_STANDALONE_IN : if C_ENABLE_HD and C_ENABLE_STANDALONE generate
  begin
    vid_clk <= i_vid_dec_clk;

    s_video_in.y(9 downto 0) <= (others => '0');
    s_video_in.c(9 downto 0) <= (others => '0');
    s_video_in.hsync_n <= s_o_hsync;
    s_video_in.vsync_n <= s_o_vsync;
    s_video_in.avid    <= s_o_avid;
    s_video_in.field_n <= '1';
    s_sync_ref_hsync_n <= s_o_hsync;
    s_sync_ref_vsync_n <= s_o_vsync;

    o_mcu_gpout_clk <= s_o_avid;
    i_spi_sdo <= '0';
  end generate;

  -- ========================================================================
  -- UNCONDITIONAL SYNC ROUTING: HDMI RX -> DECODER EXT SYNC INPUTS
  -- ========================================================================
  -- Forward HDMI receiver sync signals to the analog decoder's external
  -- HSYNC_IN/VSYNC_IN pins in all bitstream variants. In analog and HDMI
  -- modes, the decoder firmware configures sync extraction from the video
  -- signal itself (ignoring these pins). In dual and standalone modes,
  -- firmware configures the decoder for external sync, genlocking it to
  -- the HDMI receiver's timing.
  o_vid_dec_hsync_in <= i_hdmi_rx_hsync;
  o_vid_dec_vsync_in <= i_hdmi_rx_vsync;

  -- yuv422_to_yuv444_inst : entity work.yuv422_to_yuv444
  --   port map(
  --     clk => vid_clk,
  --     i_data => s_video_in,
  --     o_data => s_program_in
  --   );

  s_program_in <= s_video_in;

  -- SPI RAM process with proper block RAM inference
  process (vid_clk)
  begin
    if rising_edge(vid_clk) then
      -- Write has priority
      if s_spi_wr_en = '1' then
        s_spi_ram(to_integer(s_spi_addr)) <= s_spi_dout;
      end if;
      -- Synchronous read with output register
      s_spi_din <= s_spi_ram(to_integer(s_spi_addr));
    end if;
  end process;

  spi_peripheral_inst : entity work.spi_peripheral
    generic map(
      G_DATA_WIDTH => C_SPI_TRANSFER_DATA_BITS,
      G_ADDR_WIDTH => C_SPI_TRANSFER_ADDR_WIDTH,
      G_CPOL => '0',
      G_CPHA => '0'
    )
    port map(
      clk => vid_clk,
      sck => i_spi_sck,
      sdi => i_spi_sdi,
      sdo => open,
      cs_n => i_spi_cs_n,
      din => s_spi_din,
      dout => s_spi_dout,
      wr_en => s_spi_wr_en,
      rd_en => s_spi_rd_en,
      addr => s_spi_addr
    );

  process (vid_clk)
  begin
    if rising_edge(vid_clk) then
      s_vsync_n_d <= s_program_in.vsync_n;
    end if;
  end process;

  -- Detect falling edge of active-low VSYNC (start of vertical sync).
  s_vsync_n_event <= s_vsync_n_d and not s_program_in.vsync_n;

  -- Shadow RAM process with proper block RAM inference.
  -- Latches all 9 SPI registers atomically on VSYNC, ensuring all programs
  -- see a tear-free, frame-coherent parameter snapshot for the entire field.
  process (vid_clk)
  begin
    if rising_edge(vid_clk) then
      if s_vsync_n_event = '1' then
        -- Copy entire RAM on vsync event
        for i in 0 to 8 loop
          s_spi_ram_d(i) <= s_spi_ram(i);
        end loop;
      end if;
    end if;
  end process;

  s_video_timing_id <= s_spi_ram_d(8)(3 downto 0);

  -- ========================================================================
  -- HD CLOCK DECIMATION
  -- ========================================================================
  -- When C_HD_CLOCK_DIVISOR > 1 and HD mode is active, the program runs at
  -- a divided pixel clock (37.125 MHz for div2, 18.5625 MHz for div4).
  -- The PLL produces a phase-aligned divided clock. Input video data is
  -- sampled into the slow clock domain, and output data is held for N
  -- fast clock cycles, producing pixel repetition.
  -- SD modes and HD with divisor=1 use direct connection (no PLL, no CDC).

  GEN_DIRECT_PROG_CLK : if (not C_ENABLE_HD) or (C_HD_CLOCK_DIVISOR = 1) generate
    prog_clk <= vid_clk;
    s_prog_data_in <= s_program_in;
    s_program_out <= s_prog_data_out;
    s_prog_registers <= s_spi_ram_d;
  end generate;

  GEN_DECIMATED_PROG_CLK : if C_ENABLE_HD and (C_HD_CLOCK_DIVISOR > 1) generate

    GEN_DIV2_PLL : if C_HD_CLOCK_DIVISOR = 2 generate
      hd_pll_div2_inst : entity work.hd_video_clk_pll_div2
        port map(
          i_clk    => vid_clk,
          o_clk    => prog_clk,
          i_resetb => '1',
          i_bypass => '0'
        );
    end generate;

    GEN_DIV4_PLL : if C_HD_CLOCK_DIVISOR = 4 generate
      hd_pll_div4_inst : entity work.hd_video_clk_pll_div4
        port map(
          i_clk    => vid_clk,
          o_clk    => prog_clk,
          i_resetb => '1',
          i_bypass => '0'
        );
    end generate;

    -- Input CDC: vid_clk -> prog_clk (single register stage)
    p_input_cdc : process(prog_clk)
    begin
      if rising_edge(prog_clk) then
        s_prog_data_in <= s_program_in;
        s_prog_registers <= s_spi_ram_d;
      end if;
    end process;

    -- Output CDC: prog_clk -> vid_clk (single register stage)
    p_output_cdc : process(vid_clk)
    begin
      if rising_edge(vid_clk) then
        s_program_out <= s_prog_data_out;
      end if;
    end process;

  end generate;

  yuv422_20b_top_inst : entity work.program_top
    port map(
      clk => prog_clk,
      registers_in => s_prog_registers,
      data_in => s_prog_data_in,
      data_out => s_prog_data_out
    );

  video_field_detector_inst : entity work.video_field_detector
    generic map(
      G_LINE_COUNTER_WIDTH => 12
    )
    port map(
      clk => vid_clk,
      hsync => s_sync_ref_hsync_n,
      vsync => s_sync_ref_vsync_n,
      field_n => s_o_field_n
    );

  video_sync_generator_inst : entity work.video_sync_generator
    port map(
      clk => vid_clk,
      ref_hsync => s_sync_ref_hsync_n,
      ref_vsync => s_sync_ref_vsync_n,
      ref_field_n => s_o_field_n,
      timing => s_video_timing_id,
      trisync_p => s_o_trisync_out_p,
      trisync_n => s_o_trisync_out_n,
      hsync => s_o_hsync,
      vsync => s_o_vsync,
      avid => s_o_avid
    );

  -- yuv444_blanking_inst : entity work.yuv444_blanking
  --   port map(
  --     clk => vid_clk,
  --     data_in => s_program_out,
  --     data_out => s_blanking_out
  --   );

  -- yuv444_to_yuv422_inst : entity work.yuv444_to_yuv422
  --   port map(
  --     clk => vid_clk,
  --     i_data => s_blanking_out,
  --     o_data => s_video_out
  --   );
  s_video_out <= s_program_out;

  o_vid_sync_out_p <= s_o_trisync_out_p;
  o_vid_sync_out_n <= s_o_trisync_out_n;

  GEN_SD_HDMI_OUT : if C_ENABLE_SD and C_ENABLE_HDMI generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;

    pll_inst : entity work.sd_video_clk_pll_2x
    port map(
      i_clk    => vid_clk,
      o_clk    => o_vid_enc_clk,
      i_resetb => '1',
      i_bypass => '0'
    );

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_HDMI_OUT : if C_ENABLE_HD and C_ENABLE_HDMI generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;
    o_vid_enc_clk <= not vid_clk;

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_SD_ANALOG_OUT : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;

    pll_inst : entity work.sd_video_clk_pll_2x
    port map(
      i_clk    => vid_clk,
      o_clk    => o_vid_enc_clk,
      i_resetb => '1',
      i_bypass => '0'
    );

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_ANALOG_OUT : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;
    o_vid_enc_clk <= not vid_clk;

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_SD_DUAL_OUT : if C_ENABLE_SD and C_ENABLE_DUAL generate

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_DUAL_OUT : if C_ENABLE_HD and C_ENABLE_DUAL generate

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  -- ========================================================================
  -- STANDALONE OUTPUT GENERATES
  -- ========================================================================
  -- Drive both the analog encoder (ADV7393) and HDMI transmitter
  -- (ADV7513) outputs directly from vid_clk. No oversampling PLL is
  -- used; vid_clk is the encoder pixel clock at the active rate.

  GEN_SD_STANDALONE_OUT : if C_ENABLE_SD and C_ENABLE_STANDALONE generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    o_vid_enc_clk <= not vid_clk;

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_STANDALONE_OUT : if C_ENABLE_HD and C_ENABLE_STANDALONE generate

    o_vid_enc_d(15 downto 8) <= s_video_out.y(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    o_vid_enc_clk <= not vid_clk;

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_d(3 downto 0) <= "0000";
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

end architecture;