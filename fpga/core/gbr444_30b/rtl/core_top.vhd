-- Videomancer SDK - Open source FPGA-based video effects development kit
-- Copyright (C) 2025 LZX Industries LLC
-- File: core.vhd - Common top level architecture for all GBR444 Core programs
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
use work.video_stream_pkg.all;
use work.video_timing_pkg.all;
use work.video_sync_pkg.all;
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
  signal s_hsync_n_d : std_logic := '0';
  signal s_hsync_n_event : std_logic := '0';
  signal s_video_timing_id : t_video_timing_id := (others => '0');
  signal s_video_in : t_video_stream_gbr422_20b;
  signal s_program_in : t_video_stream_gbr444_30b;
  signal s_program_out : t_video_stream_gbr444_30b;
  signal s_blanking_out : t_video_stream_gbr444_30b;
  signal s_video_out : t_video_stream_gbr422_20b;
  signal s_o_trisync_out_p : std_logic := '0';
  signal s_o_trisync_out_n : std_logic := '0';
  signal s_o_hsync : std_logic := '0';
  signal s_o_vsync : std_logic := '0';
  signal s_o_field_n : std_logic := '0';
  signal s_o_avid : std_logic := '0';

  -- Sync output: program-input reference on vid_clk with SPI reg 0x09 phase advance.
  signal s_sync_clk            : std_logic := '0';
  signal s_sync_timing_id      : t_video_timing_id := (others => '0');
  signal s_sync_ref_hsync_n    : std_logic := '1';
  signal s_sync_ref_vsync_n    : std_logic := '1';
  signal s_sync_phase_advance  : unsigned(C_VIDEO_SYNC_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_spi_phase_d         : std_logic_vector(C_SPI_TRANSFER_DATA_BITS - 1 downto 0) := (others => '0');

  -- SD standalone clean PLL clock. Derived inside GEN_SD_STANDALONE_IN by
  -- feeding the ADV7181C LLC pad through a fabric ÷2 register and into
  -- sd_video_clk_pll_2x (which puts a clean 27 MHz on a global clock net).
  -- vid_clk is then the ÷2 of this PLL output, so vid_clk and
  -- s_sd_standalone_clk_27_pll are deterministically phased and the
  -- ADV7393 / ADV7513 receive a clean 27 MHz CLK with a fixed phase
  -- relationship to the data registers.
  signal s_sd_standalone_clk_27_pll : std_logic := '0';

  -- HD clock decimation signals (non-standalone configs only)
  signal prog_clk : std_logic := '0';
  signal s_prog_data_in : t_video_stream_gbr444_30b;
  signal s_prog_data_out : t_video_stream_gbr444_30b;
  signal s_prog_registers : t_spi_ram := (others => (others => '0'));
  signal s_hdmi_br_phase : std_logic := '0';
  signal s_hdmi_rx_de_d  : std_logic := '0';
  -- Align HDMI RGB888 with encoder GBR422 *data* (444→422 data is 3 clocks
  -- after blanking; sync tips lead data by 1 at the ADV7393 by design).
  signal s_hdmi_gbr_d1 : t_video_stream_gbr444_30b;
  signal s_hdmi_gbr_d2 : t_video_stream_gbr444_30b;
  signal s_hdmi_gbr    : t_video_stream_gbr444_30b;

begin

  p_hdmi_br_phase : process(i_hdmi_rx_clk)
  begin
    if rising_edge(i_hdmi_rx_clk) then
      -- Phase tracks the pair grid of the downstream 422 phase logic,
      -- which drops the first sample after AVID rise and pairs from the
      -- second (B) onward: delay the alternation by one clock via a
      -- registered DE so the B slot lands on the sample the converter
      -- treats as first-of-pair. Without this the mux led the converter
      -- grid by one sample and every HDMI-input GBR pair decoded R/B
      -- swapped (vmtest finding VMT-F001), independent of the chip's
      -- DE-to-data phase.
      s_hdmi_rx_de_d <= i_hdmi_rx_de;
      if s_hdmi_rx_de_d = '0' then
        s_hdmi_br_phase <= '0';
      else
        s_hdmi_br_phase <= not s_hdmi_br_phase;
      end if;
    end if;
  end process;

  GEN_SD_HDMI_IN : if C_ENABLE_SD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    -- RGB444 SDR: R=D[23:16], G=D[15:8], B=D[7:0] → GBR422 (G + B/R on C)
    s_video_in.g(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.g(1 downto 0) <= "00";
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0) when s_hdmi_br_phase = '0'
                           else i_hdmi_rx_d(23 downto 16);
    s_video_in.c(1 downto 0) <= "00";
    s_video_in.hsync_n <= i_hdmi_rx_hsync;
    s_video_in.vsync_n <= i_hdmi_rx_vsync;
    s_video_in.avid    <= i_hdmi_rx_de;
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= i_hdmi_rx_de;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_HD_HDMI_IN : if C_ENABLE_HD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    -- RGB444 SDR: R=D[23:16], G=D[15:8], B=D[7:0] → GBR422 (G + B/R on C)
    s_video_in.g(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.g(1 downto 0) <= "00";
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0) when s_hdmi_br_phase = '0'
                           else i_hdmi_rx_d(23 downto 16);
    s_video_in.c(1 downto 0) <= "00";
    s_video_in.hsync_n <= i_hdmi_rx_hsync;
    s_video_in.vsync_n <= i_hdmi_rx_vsync;
    s_video_in.avid    <= i_hdmi_rx_de;
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= i_hdmi_rx_de;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_SD_ANALOG_IN : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    -- Keep s_video_in tied for unused HDMI-shaped nets in Dual encoder path
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_HD_ANALOG_IN : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    -- Keep s_video_in tied for unused HDMI-shaped nets in Dual encoder path
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
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
    -- HSYNC/VSYNC drive the encoder; DE clocks B/R phase for GBR422 C bus.
    -- Dual: HDMI RGB888 → encoder GBR422 (G on Y; B/R alternate on C)
    o_vid_enc_d(15 downto 8) <= i_hdmi_rx_d(15 downto 8);  -- G
    o_vid_enc_d(7 downto 0)  <= i_hdmi_rx_d(7 downto 0) when s_hdmi_br_phase = '0'
                            else i_hdmi_rx_d(23 downto 16);  -- B then R
    o_vid_enc_hsync <= not i_hdmi_rx_hsync;
    o_vid_enc_vsync <= not i_hdmi_rx_vsync;

    vid_clk <= i_vid_dec_clk;
    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    -- Keep s_video_in tied for unused HDMI-shaped nets in Dual encoder path
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_HD_DUAL_IN : if C_ENABLE_HD and C_ENABLE_DUAL generate

    o_vid_enc_clk <= i_hdmi_rx_clk;
    -- Dual: HDMI RGB888 → encoder GBR422 (G on Y; B/R alternate on C)
    o_vid_enc_d(15 downto 8) <= i_hdmi_rx_d(15 downto 8);  -- G
    o_vid_enc_d(7 downto 0)  <= i_hdmi_rx_d(7 downto 0) when s_hdmi_br_phase = '0'
                            else i_hdmi_rx_d(23 downto 16);  -- B then R
    o_vid_enc_hsync <= not i_hdmi_rx_hsync;
    o_vid_enc_vsync <= not i_hdmi_rx_vsync;

    vid_clk <= i_vid_dec_clk;
    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    -- Keep s_video_in tied for unused HDMI-shaped nets in Dual encoder path
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  -- ========================================================================
  -- STANDALONE INPUT GENERATES
  -- ========================================================================
  -- Standalone bitstreams derive vid_clk from the ADV7181C LLC pin.  Firmware
  -- programs the decoder CP-PLL as the master pixel clock and enables RGB 1V
  -- sampling; the FPGA passes decoder Y/C data and HS/VS/DE into the pipeline.

  GEN_SD_STANDALONE_IN : if C_ENABLE_SD and C_ENABLE_STANDALONE generate
    -- DDR RGB: LLC = pixel clock. Encoder 27 MHz from 2x when interlaced.
    signal s_ed_progressive : std_logic;
    signal s_clk_2x : std_logic;
  begin
    s_ed_progressive <= '1' when (s_video_timing_id = C_480P or s_video_timing_id = C_576P)
                        else '0';

    pll_inst : entity work.sd_video_clk_pll_2x
    port map(
      i_clk    => i_vid_dec_clk,
      o_clk    => s_clk_2x,
      i_resetb => '1',
      i_bypass => '0'
    );

    vid_clk <= i_vid_dec_clk;
    s_sd_standalone_clk_27_pll <= i_vid_dec_clk when s_ed_progressive = '1' else s_clk_2x;

    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    -- Keep s_video_in tied for unused HDMI-shaped nets in Dual encoder path
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
    i_spi_sdo <= i_vid_dec_vsync;
  end generate;

  GEN_HD_STANDALONE_IN : if C_ENABLE_HD and C_ENABLE_STANDALONE generate
  begin
    vid_clk <= i_vid_dec_clk;
    -- ADV7181C 12-bit DDR RGB → GBR444 program interface (no 422 round-trip)
    adv7181c_rgb_ddr_to_gbr444_inst : entity work.adv7181c_rgb_ddr_to_gbr444
      port map(
        llc       => i_vid_dec_clk,
        i_p19_8   => i_vid_dec_d(19 downto 8),
        i_hsync_n => i_vid_dec_hsync,
        i_vsync_n => i_vid_dec_vsync,
        i_avid    => i_vid_dec_field_de,
        i_field_n => '1',
        o_data    => s_program_in
      );
    s_video_in.g <= (others => '0');
    s_video_in.c <= (others => '0');
    s_video_in.hsync_n <= '1';
    s_video_in.vsync_n <= '1';
    s_video_in.avid <= '0';
    s_video_in.field_n <= '1';
    o_mcu_gpout_clk <= s_program_in.avid;  -- DE via DDR unpack (line-rate AVID)
    i_spi_sdo <= i_vid_dec_vsync;
  end generate;

  -- ========================================================================
  -- UNCONDITIONAL SYNC ROUTING: HDMI RX -> DECODER EXT SYNC INPUTS
  -- ========================================================================
  -- Forward HDMI receiver sync to the decoder EXT sync inputs.  Firmware
  -- configures the decoder to use these pins only in dual routing mode;
  -- analog, HDMI, and standalone modes ignore them.
  o_vid_dec_hsync_in <= i_hdmi_rx_hsync;
  o_vid_dec_vsync_in <= i_hdmi_rx_vsync;

  GEN_HDMI_TO_PROGRAM : if C_ENABLE_HDMI generate
    gbr422_20b_to_gbr444_30b_inst : entity work.gbr422_20b_to_gbr444_30b
      port map(
        clk => vid_clk,
        i_data => s_video_in,
        o_data => s_program_in
      );
  end generate;
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
      s_hsync_n_d <= s_program_in.hsync_n;
    end if;
  end process;

  s_hsync_n_event <= s_hsync_n_d and not s_program_in.hsync_n;

  -- Latch MCU SPI writes into shadow RAM once per line.
  -- 0x00-0x08: program-visible (per-line modulation + timing_id).
  -- 0x09 phase_advance: latched on the same HSYNC edge into a core-only
  -- register so Sync Out never pairs a new advance with a stale format.
  GEN_SHADOW_RAM_HSYNC : process (vid_clk)
  begin
    if rising_edge(vid_clk) then
      if s_hsync_n_event = '1' then
        for i in 0 to 8 loop
          s_spi_ram_d(i) <= s_spi_ram(i);
        end loop;
        s_spi_phase_d <= s_spi_ram(9);
      end if;
    end if;
  end process;

  s_video_timing_id <= s_spi_ram_d(8)(3 downto 0);

  -- ========================================================================
  -- HD CLOCK DECIMATION (non-standalone input-routing configs)
  -- ========================================================================
  GEN_DIRECT_PROG_CLK : if C_ENABLE_STANDALONE or (not C_ENABLE_HD) or (C_HD_CLOCK_DIVISOR = 1) generate
    prog_clk <= vid_clk;
    s_prog_data_in <= s_program_in;
    s_program_out <= s_prog_data_out;
    s_prog_registers <= s_spi_ram_d;
  end generate;

  GEN_DECIMATED_PROG_CLK : if (not C_ENABLE_STANDALONE) and C_ENABLE_HD and (C_HD_CLOCK_DIVISOR > 1) generate

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

    p_input_cdc : process(prog_clk)
    begin
      if rising_edge(prog_clk) then
        s_prog_data_in <= s_program_in;
        s_prog_registers <= s_spi_ram_d;
      end if;
    end process;

    p_output_cdc : process(vid_clk)
    begin
      if rising_edge(vid_clk) then
        s_program_out <= s_prog_data_out;
      end if;
    end process;

  end generate;

  gbr444_30b_top_inst : entity work.program_top
    port map(
      clk => prog_clk,
      registers_in => s_prog_registers,
      data_in => s_prog_data_in,
      data_out => s_prog_data_out
    );

  gbr444_30b_blanking_inst : entity work.gbr444_30b_blanking
    port map(
      clk => vid_clk,
      data_in => s_program_out,
      data_out => s_blanking_out
    );

  gbr444_30b_to_gbr422_20b_inst : entity work.gbr444_30b_to_gbr422_20b
    port map(
      clk => vid_clk,
      i_data => s_blanking_out,
      o_data => s_video_out
    );

  p_hdmi_align : process(vid_clk)
  begin
    if rising_edge(vid_clk) then
      s_hdmi_gbr_d1 <= s_blanking_out;
      s_hdmi_gbr_d2 <= s_hdmi_gbr_d1;
      s_hdmi_gbr    <= s_hdmi_gbr_d2;
    end if;
  end process;

  -- ========================================================================
  -- SYNC OUTPUT (program-input lock + phase advance)
  -- ========================================================================
  s_sync_clk           <= vid_clk;
  s_sync_ref_hsync_n   <= s_program_in.hsync_n;
  s_sync_ref_vsync_n   <= s_program_in.vsync_n;
  s_sync_timing_id     <= s_video_timing_id;
  s_sync_phase_advance <= resize(unsigned(s_spi_phase_d), C_VIDEO_SYNC_DATA_WIDTH);

  video_field_detector_inst : entity work.video_field_detector
    generic map(
      G_LINE_COUNTER_WIDTH => 12
    )
    port map(
      clk => s_sync_clk,
      hsync => s_sync_ref_hsync_n,
      vsync => s_sync_ref_vsync_n,
      field_n => s_o_field_n
    );

  video_sync_generator_inst : entity work.video_sync_generator
    generic map(
      G_LOCK_TO_REF   => true,
      G_PHASE_ADVANCE => true
    )
    port map(
      clk                => s_sync_clk,
      ref_hsync          => s_sync_ref_hsync_n,
      ref_vsync          => s_sync_ref_vsync_n,
      ref_field_n        => s_o_field_n,
      timing             => s_sync_timing_id,
      phase_advance_clks => s_sync_phase_advance,
      trisync_p          => s_o_trisync_out_p,
      trisync_n          => s_o_trisync_out_n,
      hsync              => s_o_hsync,
      vsync              => s_o_vsync,
      avid               => s_o_avid
    );

  o_vid_sync_out_p <= s_o_trisync_out_p;
  o_vid_sync_out_n <= s_o_trisync_out_n;

  GEN_SD_HDMI_OUT : if C_ENABLE_SD and C_ENABLE_HDMI generate

    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
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

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_HDMI_OUT : if C_ENABLE_HD and C_ENABLE_HDMI generate

    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;
    o_vid_enc_clk <= not vid_clk;

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_SD_ANALOG_OUT : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
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

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_ANALOG_OUT : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    -- o_vid_enc_hsync <= not s_o_hsync;
    -- o_vid_enc_vsync <= not s_o_vsync;
    o_vid_enc_clk <= not vid_clk;

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_SD_DUAL_OUT : if C_ENABLE_SD and C_ENABLE_DUAL generate

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_DUAL_OUT : if C_ENABLE_HD and C_ENABLE_DUAL generate

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  -- ========================================================================
  -- STANDALONE OUTPUT GENERATES
  -- ========================================================================
  -- ADV7393 analog encoder requires its CLK input at 2x the SD pixel
  -- rate (27 MHz). For SD standalone, instantiate sd_video_clk_pll_2x
  -- driven from the 13.5 MHz LLC÷2 reference to produce a 27 MHz
  -- encoder clock that is PLL-phase-locked to vid_clk. This mirrors
  -- the working SD HDMI/Analog OUT paths and gives the ADV7393 a
  -- guaranteed setup/hold relationship with the data registers.
  -- ADV7513 HDMI transmitter receives the same 27 MHz clock and
  -- handles SD content via pixel_repetition (matching SD HDMI/Analog
  -- OUT patterns). HD standalone uses vid_clk directly (74.25 MHz).

  GEN_SD_STANDALONE_OUT : if C_ENABLE_SD and C_ENABLE_STANDALONE generate
  begin
    -- Encoder CLK = 27 MHz from the standalone PLL (rising edge falls
    -- in the middle of vid_clk's data hold time, deterministic Y/C
    -- interleave for ADV7393 sd_input_format=_16bit_ycbcr).
    --
    -- HDMI tx CLK = vid_clk (13.5 MHz), matching the working SD HDMI
    -- and SD Analog OUT paths. ADV7513 internally generates the
    -- 27 MHz TMDS rate from its own PLL when pixel_repetition is
    -- enabled in firmware (required for CEA VIC 6/21 SD modes).
    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    o_vid_enc_clk <= not s_sd_standalone_clk_27_pll;

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_STANDALONE_OUT : if C_ENABLE_HD and C_ENABLE_STANDALONE generate

    o_vid_enc_d(15 downto 8) <= s_video_out.g(9 downto 2);
    o_vid_enc_d(7 downto 0) <= s_video_out.c(9 downto 2);
    o_vid_enc_hsync <= not s_video_out.hsync_n;
    o_vid_enc_vsync <= not s_video_out.vsync_n;
    o_vid_enc_clk <= not vid_clk;

    -- GBR444 → RGB888 for ADV7513 (aligned with encoder 422 *data* latency)
    o_hdmi_tx_d(23 downto 16) <= s_hdmi_gbr.r(9 downto 2);  -- R
    o_hdmi_tx_d(15 downto 8)  <= s_hdmi_gbr.g(9 downto 2);  -- G
    o_hdmi_tx_d(7 downto 0)   <= s_hdmi_gbr.b(9 downto 2);  -- B
    o_hdmi_tx_hsync <= s_hdmi_gbr.hsync_n;
    o_hdmi_tx_vsync <= s_hdmi_gbr.vsync_n;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

end architecture;