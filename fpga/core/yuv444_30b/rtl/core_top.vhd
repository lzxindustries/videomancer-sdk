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
use work.video_stream_pkg.all;
use work.video_timing_pkg.all;
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
    o_mcu_gpout_clk         : out   std_logic;

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
  signal s_video_in : t_video_stream_yuv422_20b;
  signal s_program_in : t_video_stream_yuv444_30b;
  signal s_program_out : t_video_stream_yuv444_30b;
  signal s_blanking_out : t_video_stream_yuv444_30b;
  signal s_video_out : t_video_stream_yuv422_20b;
  signal s_o_trisync_out_p : std_logic := '0';
  signal s_o_trisync_out_n : std_logic := '0';
  signal s_o_hsync : std_logic := '0';
  signal s_o_vsync : std_logic := '0';
  signal s_o_field_n : std_logic := '0';
  signal s_o_avid : std_logic := '0';

begin

  GEN_SD_HDMI_IN : if C_ENABLE_SD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    s_video_in.y(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0);
    s_video_in.y(1 downto 0) <= i_hdmi_rx_d(23 downto 22);
    s_video_in.c(1 downto 0) <= i_hdmi_rx_d(19 downto 18);
    s_video_in.hsync_n <= i_hdmi_rx_hsync;
    s_video_in.vsync_n <= i_hdmi_rx_vsync;
    s_video_in.avid <= i_hdmi_rx_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_hdmi_rx_hsync;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_HD_HDMI_IN : if C_ENABLE_HD and C_ENABLE_HDMI generate

    vid_clk <= i_hdmi_rx_clk;
    s_video_in.y(9 downto 2) <= i_hdmi_rx_d(15 downto 8);
    s_video_in.c(9 downto 2) <= i_hdmi_rx_d(7 downto 0);
    s_video_in.y(1 downto 0) <= i_hdmi_rx_d(23 downto 22);
    s_video_in.c(1 downto 0) <= i_hdmi_rx_d(19 downto 18);
    s_video_in.hsync_n <= i_hdmi_rx_hsync;
    s_video_in.vsync_n <= i_hdmi_rx_vsync;
    s_video_in.avid <= i_hdmi_rx_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_hdmi_rx_hsync;
    i_spi_sdo <= i_hdmi_rx_vsync;

  end generate;

  GEN_SD_ANALOG_IN : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= i_vid_dec_hsync;
    s_video_in.vsync_n <= i_vid_dec_vsync;
    s_video_in.avid <= i_vid_dec_field_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_vid_dec_hsync;
    i_spi_sdo <= i_vid_dec_vsync;

  end generate;

  GEN_HD_ANALOG_IN : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= i_vid_dec_hsync;
    s_video_in.vsync_n <= i_vid_dec_vsync;
    s_video_in.avid <= i_vid_dec_field_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_vid_dec_hsync;
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

    o_vid_enc_d(15 downto 8) <= i_hdmi_rx_d(15 downto 8);
    o_vid_enc_d(7 downto 0) <= i_hdmi_rx_d(7 downto 0);
    o_vid_enc_hsync <= not i_hdmi_rx_hsync;
    o_vid_enc_vsync <= not i_hdmi_rx_vsync;

    vid_clk <= i_vid_dec_clk;
    s_video_in.y(9 downto 0) <= i_vid_dec_d(9 downto 0);
    s_video_in.c(9 downto 0) <= i_vid_dec_d(19 downto 10);
    s_video_in.hsync_n <= i_vid_dec_hsync;
    s_video_in.vsync_n <= i_vid_dec_vsync;
    s_video_in.avid <= i_vid_dec_field_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_vid_dec_hsync;
    i_spi_sdo <= i_vid_dec_vsync;
    o_vid_dec_hsync_in <= i_hdmi_rx_hsync;
    o_vid_dec_vsync_in <= i_hdmi_rx_vsync;

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
    s_video_in.hsync_n <= i_vid_dec_hsync;
    s_video_in.vsync_n <= i_vid_dec_vsync;
    s_video_in.avid <= i_vid_dec_field_de;
    s_video_in.field_n <= '1';
    -- o_mcu_gpout_clk <= i_vid_dec_hsync;
    i_spi_sdo <= i_vid_dec_vsync;
    o_vid_dec_hsync_in <= i_hdmi_rx_hsync;
    o_vid_dec_vsync_in <= i_hdmi_rx_vsync;

  end generate;

  yuv422_20b_to_yuv444_30b_inst : entity work.yuv422_20b_to_yuv444_30b
    port map(
      clk => vid_clk,
      i_data => s_video_in,
      o_data => s_program_in
    );
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
      DATA_WIDTH => C_SPI_TRANSFER_DATA_BITS,
      ADDR_WIDTH => C_SPI_TRANSFER_ADDR_WIDTH,
      CPOL => '0',
      CPHA => '0'
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

  -- Shadow RAM process with proper block RAM inference
  process (vid_clk)
  begin
    if rising_edge(vid_clk) then
      if s_hsync_n_event = '1' then
        -- Copy entire RAM on hsync event
        for i in 0 to 8 loop
          s_spi_ram_d(i) <= s_spi_ram(i);
        end loop;
      end if;
    end if;
  end process;

  s_video_timing_id <= s_spi_ram_d(8)(3 downto 0);

  yuv444_30b_top_inst : entity work.program_top
    port map(
      clk => vid_clk,
      registers_in => s_spi_ram_d,
      data_in => s_program_in,
      data_out => s_program_out
    );

  video_field_detector_inst : entity work.video_field_detector
    generic map(
      G_LINE_COUNTER_WIDTH => 12
    )
    port map(
      clk => vid_clk,
      hsync => s_video_out.hsync_n,
      vsync => s_video_out.vsync_n,
      field_n => s_o_field_n
    );

  video_sync_generator_inst : entity work.video_sync_generator
    port map(
      clk => vid_clk,
      ref_hsync => s_video_out.hsync_n,
      ref_vsync => s_video_out.vsync_n,
      ref_field_n => s_o_field_n,
      timing => s_video_timing_id,
      trisync_p => s_o_trisync_out_p,
      trisync_n => s_o_trisync_out_n,
      hsync => s_o_hsync,
      vsync => s_o_vsync
    );

  yuv444_30b_blanking_inst : entity work.yuv444_30b_blanking
    port map(
      clk => vid_clk,
      data_in => s_program_out,
      data_out => s_blanking_out
    );

  yuv444_30b_to_yuv422_20b_inst : entity work.yuv444_30b_to_yuv422_20b
    port map(
      clk => vid_clk,
      i_data => s_blanking_out,
      o_data => s_video_out
    );

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
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_SD_DUAL_OUT : if C_ENABLE_SD and C_ENABLE_DUAL generate

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

  GEN_HD_DUAL_OUT : if C_ENABLE_HD and C_ENABLE_DUAL generate

    o_hdmi_tx_d(23 downto 14) <= s_video_out.y(9 downto 0);
    o_hdmi_tx_d(13 downto 4) <= s_video_out.c(9 downto 0);
    o_hdmi_tx_hsync <= s_video_out.hsync_n;
    o_hdmi_tx_vsync <= s_video_out.vsync_n;
    -- o_hdmi_tx_hsync <= s_o_hsync;
    -- o_hdmi_tx_vsync <= s_o_vsync;
    o_hdmi_tx_clk <= not vid_clk;

  end generate;

end architecture;