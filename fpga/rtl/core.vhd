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
use work.core_config_pkg.all;
use work.core_pkg.all;
use work.all;

architecture core of top is

  component SB_PLL40_CORE is
    generic (
      FEEDBACK_PATH : string := "SIMPLE";
      DIVR : std_logic_vector(3 downto 0) := "0000";
      DIVF : std_logic_vector(6 downto 0) := "0000000";
      DIVQ : std_logic_vector(2 downto 0) := "000";
      FILTER_RANGE : std_logic_vector(2 downto 0) := "000"
    );
    port (
      REFERENCECLK : in std_logic;
      PLLOUTCORE : out std_logic;
      PLLOUTGLOBAL : out std_logic;
      RESETB : in std_logic;
      BYPASS : in std_logic
    );
  end component SB_PLL40_CORE;

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
  signal s_video_in : t_video_stream_yuv422;
  signal s_program_in : t_video_stream_yuv444;
  signal s_program_out : t_video_stream_yuv444;
  signal s_blanking_out : t_video_stream_yuv444;
  signal s_video_out : t_video_stream_yuv422;
  signal s_o_trisync_out_p : std_logic := '0';
  signal s_o_trisync_out_n : std_logic := '0';
  signal s_o_hsync : std_logic := '0';
  signal s_o_vsync : std_logic := '0';
  signal s_o_field_n : std_logic := '0';
  signal s_o_avid : std_logic := '0';

begin

  GEN_SD_HDMI_IN : if C_ENABLE_SD and C_ENABLE_HDMI generate

    vid_clk <= HDMI_RX_CLK;
    s_video_in.y(9 downto 2) <= HDMI_RX_D(15 downto 8);
    s_video_in.c(9 downto 2) <= HDMI_RX_D(7 downto 0);
    s_video_in.y(1 downto 0) <= HDMI_RX_D(23 downto 22);
    s_video_in.c(1 downto 0) <= HDMI_RX_D(19 downto 18);
    s_video_in.hsync_n <= HDMI_RX_HSYNC;
    s_video_in.vsync_n <= HDMI_RX_VSYNC;
    s_video_in.avid <= HDMI_RX_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= HDMI_RX_HSYNC;
    SPI_SDO <= HDMI_RX_VSYNC;

  end generate;

  GEN_HD_HDMI_IN : if C_ENABLE_HD and C_ENABLE_HDMI generate

    vid_clk <= HDMI_RX_CLK;
    s_video_in.y(9 downto 2) <= HDMI_RX_D(15 downto 8);
    s_video_in.c(9 downto 2) <= HDMI_RX_D(7 downto 0);
    s_video_in.y(1 downto 0) <= HDMI_RX_D(23 downto 22);
    s_video_in.c(1 downto 0) <= HDMI_RX_D(19 downto 18);
    s_video_in.hsync_n <= HDMI_RX_HSYNC;
    s_video_in.vsync_n <= HDMI_RX_VSYNC;
    s_video_in.avid <= HDMI_RX_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= HDMI_RX_HSYNC;
    SPI_SDO <= HDMI_RX_VSYNC;

  end generate;

  GEN_SD_ANALOG_IN : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    vid_clk <= VID_DEC_CLK;
    s_video_in.y(9 downto 0) <= VID_DEC_D(9 downto 0);
    s_video_in.c(9 downto 0) <= VID_DEC_D(19 downto 10);
    s_video_in.hsync_n <= VID_DEC_HSYNC;
    s_video_in.vsync_n <= VID_DEC_VSYNC;
    s_video_in.avid <= VID_DEC_FIELD_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= VID_DEC_HSYNC;
    SPI_SDO <= VID_DEC_VSYNC;

  end generate;

  GEN_HD_ANALOG_IN : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    vid_clk <= VID_DEC_CLK;
    s_video_in.y(9 downto 0) <= VID_DEC_D(9 downto 0);
    s_video_in.c(9 downto 0) <= VID_DEC_D(19 downto 10);
    s_video_in.hsync_n <= VID_DEC_HSYNC;
    s_video_in.vsync_n <= VID_DEC_VSYNC;
    s_video_in.avid <= VID_DEC_FIELD_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= VID_DEC_HSYNC;
    SPI_SDO <= VID_DEC_VSYNC;

  end generate;

  GEN_SD_DUAL_IN : if C_ENABLE_SD and C_ENABLE_DUAL generate
  
    pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000", -- Reference divider = 0+1 = 1 (input / 1 = 13.5MHz)
      DIVF => "0011111", -- Feedback divider = 31+1 = 32 (VCO = 13.5 * 32 = 432MHz)
      DIVQ => "100", -- Output divider = 2^4 = 16 (output = 432 / 16 = 27MHz)
      FILTER_RANGE => "001" -- PLL filter range for 13.5MHz input
    )
    port map(
      REFERENCECLK => HDMI_RX_CLK,
      PLLOUTCORE => open,
      PLLOUTGLOBAL => VID_ENC_CLK,
      RESETB => '1',
      BYPASS => '0'
    );

    VID_ENC_D(15 downto 8) <= HDMI_RX_D(15 downto 8);
    VID_ENC_D(7 downto 0) <= HDMI_RX_D(7 downto 0);
    VID_ENC_HSYNC <= not HDMI_RX_HSYNC;
    VID_ENC_VSYNC <= not HDMI_RX_VSYNC;

    vid_clk <= VID_DEC_CLK;
    s_video_in.y(9 downto 0) <= VID_DEC_D(9 downto 0);
    s_video_in.c(9 downto 0) <= VID_DEC_D(19 downto 10);
    s_video_in.hsync_n <= VID_DEC_HSYNC;
    s_video_in.vsync_n <= VID_DEC_VSYNC;
    s_video_in.avid <= VID_DEC_FIELD_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= VID_DEC_HSYNC;
    SPI_SDO <= VID_DEC_VSYNC;
    VID_DEC_HSYNC_IN <= HDMI_RX_HSYNC;
    VID_DEC_VSYNC_IN <= HDMI_RX_VSYNC;

  end generate;

  GEN_HD_DUAL_IN : if C_ENABLE_HD and C_ENABLE_DUAL generate
  
    VID_ENC_CLK <= HDMI_RX_CLK;
    VID_ENC_D(15 downto 8) <= HDMI_RX_D(15 downto 8);
    VID_ENC_D(7 downto 0) <= HDMI_RX_D(7 downto 0);
    VID_ENC_HSYNC <= not HDMI_RX_HSYNC;
    VID_ENC_VSYNC <= not HDMI_RX_VSYNC;

    vid_clk <= VID_DEC_CLK;
    s_video_in.y(9 downto 0) <= VID_DEC_D(9 downto 0);
    s_video_in.c(9 downto 0) <= VID_DEC_D(19 downto 10);
    s_video_in.hsync_n <= VID_DEC_HSYNC;
    s_video_in.vsync_n <= VID_DEC_VSYNC;
    s_video_in.avid <= VID_DEC_FIELD_DE;
    s_video_in.field_n <= '1';
    -- MCU_GPOUT_CLK <= VID_DEC_HSYNC;
    SPI_SDO <= VID_DEC_VSYNC;
    VID_DEC_HSYNC_IN <= HDMI_RX_HSYNC;
    VID_DEC_VSYNC_IN <= HDMI_RX_VSYNC;

  end generate;

  yuv422_to_yuv444_inst : entity work.yuv422_to_yuv444
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
      sck => SPI_SCK,
      sdi => SPI_SDI,
      sdo => open,
      cs_n => SPI_CS_N,
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

  program_yuv444_inst : entity work.program_yuv444
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

  blanking_yuv444_inst : entity work.blanking_yuv444
    port map(
      clk => vid_clk,
      data_in => s_program_out,
      data_out => s_blanking_out
    );

  yuv444_to_yuv422_inst : entity work.yuv444_to_yuv422
    port map(
      clk => vid_clk,
      i_data => s_blanking_out,
      o_data => s_video_out
    );

  VID_SYNC_OUT_P <= s_o_trisync_out_p;
  VID_SYNC_OUT_N <= s_o_trisync_out_n;

  GEN_SD_HDMI_OUT : if C_ENABLE_SD and C_ENABLE_HDMI generate

    VID_ENC_D(15 downto 8) <= s_video_out.y(9 downto 2);
    VID_ENC_D(7 downto 0) <= s_video_out.c(9 downto 2);
    VID_ENC_HSYNC <= not s_video_out.hsync_n;
    VID_ENC_VSYNC <= not s_video_out.vsync_n;
    -- VID_ENC_HSYNC <= not s_o_hsync;
    -- VID_ENC_VSYNC <= not s_o_vsync;

    pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000", -- Reference divider = 0+1 = 1 (input / 1 = 13.5MHz)
      DIVF => "0011111", -- Feedback divider = 31+1 = 32 (VCO = 13.5 * 32 = 432MHz)
      DIVQ => "100", -- Output divider = 2^4 = 16 (output = 432 / 16 = 27MHz)
      FILTER_RANGE => "001" -- PLL filter range for 13.5MHz input
    )
    port map(
      REFERENCECLK => vid_clk,
      PLLOUTCORE => open,
      PLLOUTGLOBAL => VID_ENC_CLK,
      RESETB => '1',
      BYPASS => '0'
    );

    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

  GEN_HD_HDMI_OUT : if C_ENABLE_HD and C_ENABLE_HDMI generate

    VID_ENC_D(15 downto 8) <= s_video_out.y(9 downto 2);
    VID_ENC_D(7 downto 0) <= s_video_out.c(9 downto 2);
    VID_ENC_HSYNC <= not s_video_out.hsync_n;
    VID_ENC_VSYNC <= not s_video_out.vsync_n;
    -- VID_ENC_HSYNC <= not s_o_hsync;
    -- VID_ENC_VSYNC <= not s_o_vsync;
    VID_ENC_CLK <= not vid_clk;

    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

  GEN_SD_ANALOG_OUT : if C_ENABLE_SD and C_ENABLE_ANALOG generate

    VID_ENC_D(15 downto 8) <= s_video_out.y(9 downto 2);
    VID_ENC_D(7 downto 0) <= s_video_out.c(9 downto 2);
    VID_ENC_HSYNC <= not s_video_out.hsync_n;
    VID_ENC_VSYNC <= not s_video_out.vsync_n;
    -- VID_ENC_HSYNC <= not s_o_hsync;
    -- VID_ENC_VSYNC <= not s_o_vsync;

    pll_inst : SB_PLL40_CORE
    generic map(
      FEEDBACK_PATH => "SIMPLE",
      DIVR => "0000", -- Reference divider = 0+1 = 1 (input / 1 = 13.5MHz)
      DIVF => "0011111", -- Feedback divider = 31+1 = 32 (VCO = 13.5 * 32 = 432MHz)
      DIVQ => "100", -- Output divider = 2^4 = 16 (output = 432 / 16 = 27MHz)
      FILTER_RANGE => "001" -- PLL filter range for 13.5MHz input
    )
    port map(
      REFERENCECLK => vid_clk,
      PLLOUTCORE => open,
      PLLOUTGLOBAL => VID_ENC_CLK,
      RESETB => '1',
      BYPASS => '0'
    );

    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

  GEN_HD_ANALOG_OUT : if C_ENABLE_HD and C_ENABLE_ANALOG generate

    VID_ENC_D(15 downto 8) <= s_video_out.y(9 downto 2);
    VID_ENC_D(7 downto 0) <= s_video_out.c(9 downto 2);
    VID_ENC_HSYNC <= not s_video_out.hsync_n;
    VID_ENC_VSYNC <= not s_video_out.vsync_n;
    -- VID_ENC_HSYNC <= not s_o_hsync;
    -- VID_ENC_VSYNC <= not s_o_vsync;
    VID_ENC_CLK <= not vid_clk;

    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

  GEN_SD_DUAL_OUT : if C_ENABLE_SD and C_ENABLE_DUAL generate
  
    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

  GEN_HD_DUAL_OUT : if C_ENABLE_HD and C_ENABLE_DUAL generate
  
    HDMI_TX_D(23 downto 14) <= s_video_out.y(9 downto 0);
    HDMI_TX_D(13 downto 4) <= s_video_out.c(9 downto 0);
    HDMI_TX_HSYNC <= s_video_out.hsync_n;
    HDMI_TX_VSYNC <= s_video_out.vsync_n;
    -- HDMI_TX_HSYNC <= s_o_hsync;
    -- HDMI_TX_VSYNC <= s_o_vsync;
    HDMI_TX_CLK <= not vid_clk;

  end generate;

end architecture;