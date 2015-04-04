--
-- USB Full-Speed/Hi-Speed Device Controller core - spi_flasher.vhdl
--
-- Copyright (c) 2015 Konstantin Oblaukhov
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library work;
use work.USBCore.all;
use work.USBExtra.all;

entity spi_flasher is
  port (
    led         : out   std_logic;
    ulpi_data   : inout std_logic_vector(7 downto 0);
    ulpi_dir    : in    std_logic;
    ulpi_nxt    : in    std_logic;
    ulpi_stp    : out   std_logic;
    ulpi_reset  : out   std_logic;
    ulpi_clk60  : in    std_logic;
    
    spi_cs      : out   std_logic;
    spi_sck     : out   std_logic;
    spi_mosi    : out   std_logic;
    spi_miso    : in    std_logic;
    
    dbg_clk     : out   std_logic;
    dbg_trig    : out   std_logic;
    dbg         : out   std_logic_vector(14 downto 0)
  );
end spi_flasher;

architecture spi_flasher of spi_flasher is
  constant CONFIG_DESC : BYTE_ARRAY(0 to 8) := (
    X"09",                              -- bLength = 9
    X"02",                              -- bDescriptionType = Configuration Descriptor
    X"20", X"00",                       -- wTotalLength = 32
    X"01",                              -- bNumInterfaces = 1
    X"01",                              -- bConfigurationValue
    X"00",                              -- iConfiguration
    X"C0",                              -- bmAttributes = Self-powered
    X"32"                               -- bMaxPower = 100 mA
    );

  constant INTERFACE_DESC : BYTE_ARRAY(0 to 8) := (
    X"09",                              -- bLength = 9
    X"04",                              -- bDescriptorType = Interface Descriptor
    X"00",                              -- bInterfaceNumber = 0
    X"00",                              -- bAlternateSetting
    X"02",                              -- bNumEndpoints = 2
    X"00",                              -- bInterfaceClass
    X"00",                              -- bInterfaceSubClass
    X"00",                              -- bInterfaceProtocol
    X"00"                               -- iInterface
    );

  constant EP1_IN_DESC : BYTE_ARRAY(0 to 6) := (
    X"07",                              -- bLength = 7
    X"05",                              -- bDescriptorType = Endpoint Descriptor
    X"81",                              -- bEndpointAddress = IN1
    B"00_00_00_10",                     -- bmAttributes = Bulk
    X"40", X"00",                       -- wMaxPacketSize = 64 bytes
    X"00"                               -- bInterval
    );

  constant EP1_OUT_DESC : BYTE_ARRAY(0 to 6) := (
    X"07",                              -- bLength = 7
    X"05",                              -- bDescriptorType = Endpoint Descriptor
    X"01",                              -- bEndpointAddress = OUT1
    B"00_00_00_10",                     -- bmAttributes = Bulk
    X"40", X"00",                       -- wMaxPacketSize = 64 bytes
    X"00"                               -- bInterval
    );

  signal ulpi_data_in           : std_logic_vector(7 downto 0);
  signal ulpi_data_out          : std_logic_vector(7 downto 0);
    
  signal usb_clk                : std_logic;
  signal usb_reset              : std_logic;
    
  signal usb_idle               : std_logic;
  signal usb_suspend            : std_logic;
  signal usb_configured         : std_logic;
  signal usb_crc_error          : std_logic;
  signal usb_sof                : std_logic; 
  
  signal ctl_xfer_endpoint      : std_logic_vector(3 downto 0);
  signal ctl_xfer_type          : std_logic_vector(7 downto 0);
  signal ctl_xfer_request       : std_logic_vector(7 downto 0);
  signal ctl_xfer_value         : std_logic_vector(15 downto 0);
  signal ctl_xfer_index         : std_logic_vector(15 downto 0);
  signal ctl_xfer_length        : std_logic_vector(15 downto 0);
  signal ctl_xfer_accept        : std_logic;
  signal ctl_xfer               : std_logic;
  signal ctl_xfer_done          : std_logic;
    
  signal ctl_xfer_data_out      : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_out_valid: std_logic;
    
  signal ctl_xfer_data_in       : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_in_valid : std_logic;
  signal ctl_xfer_data_in_last  : std_logic;
  signal ctl_xfer_data_in_ready : std_logic;
  
  signal blk_xfer_endpoint      : std_logic_vector(3 downto 0);
  signal blk_in_xfer            : std_logic;
  signal blk_out_xfer           : std_logic;
    
  signal blk_xfer_in_has_data   : std_logic;
  signal blk_xfer_in_data       : std_logic_vector(7 downto 0);
  signal blk_xfer_in_data_valid : std_logic;
  signal blk_xfer_in_data_ready : std_logic;
  signal blk_xfer_in_data_last  : std_logic;
    
  signal blk_xfer_out_ready_read: std_logic;
  signal blk_xfer_out_data      : std_logic_vector(7 downto 0);
  signal blk_xfer_out_data_valid: std_logic;
  
  signal led_counter            : std_logic_vector(25 downto 0);
  
  signal spi_cs_int             : std_logic;
  signal spi_sck_int            : std_logic;
  signal spi_mosi_int           : std_logic;
  signal spi_miso_int           : std_logic;
  
  component usb_flasher is
  port (
    clk                     : in  std_logic;
    rst                     : in  std_logic;

    ctl_xfer_endpoint       : in  std_logic_vector(3 downto 0);
    ctl_xfer_type           : in  std_logic_vector(7 downto 0);
    ctl_xfer_request        : in  std_logic_vector(7 downto 0);
    ctl_xfer_value          : in  std_logic_vector(15 downto 0);
    ctl_xfer_index          : in  std_logic_vector(15 downto 0);
    ctl_xfer_length         : in  std_logic_vector(15 downto 0);
    ctl_xfer_accept         : out std_logic;
    ctl_xfer                : in  std_logic;
    ctl_xfer_done           : out std_logic;

    ctl_xfer_data_out       : in  std_logic_vector(7 downto 0);
    ctl_xfer_data_out_valid : in  std_logic;

    ctl_xfer_data_in        : out std_logic_vector(7 downto 0);
    ctl_xfer_data_in_valid  : out std_logic;
    ctl_xfer_data_in_last   : out std_logic;
    ctl_xfer_data_in_ready  : in  std_logic;

    blk_xfer_endpoint       : in  std_logic_vector(3 downto 0);
    blk_in_xfer             : in  std_logic;
    blk_out_xfer            : in  std_logic;

    blk_xfer_in_has_data    : out std_logic;
    blk_xfer_in_data        : out std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : out std_logic;
    blk_xfer_in_data_ready  : in  std_logic;
    blk_xfer_in_data_last   : out std_logic;

    blk_xfer_out_ready_read : out std_logic;
    blk_xfer_out_data       : in  std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : in  std_logic;
    
    spi_cs                  : out std_logic;
    spi_sck                 : out std_logic;
    spi_mosi                : out std_logic;
    spi_miso                : in  std_logic
    );
  end component;
    
begin
  ULPI_IO: for i in 7 downto 0 generate
  begin
    ULPI_IOBUF : IOBUF
    port map (
      O     => ulpi_data_in(i),
      IO    => ulpi_data(i),
      I     => ulpi_data_out(i),
      T     => ulpi_dir
    );
  end generate;
  
  USB_CONTROLLER: usb_tlp
  generic map (
    VENDOR_ID => X"DEAD",
    PRODUCT_ID => X"BEEF",
    MANUFACTURER => "USBCore",
    PRODUCT => "SPI Flasher",
    SERIAL => "",
    CONFIG_DESC => CONFIG_DESC & INTERFACE_DESC &
                   EP1_IN_DESC & EP1_OUT_DESC
  )
  port map (    
	ulpi_data_in => ulpi_data_in,
	ulpi_data_out => ulpi_data_out,
	ulpi_dir => ulpi_dir,
	ulpi_nxt => ulpi_nxt,
	ulpi_stp => ulpi_stp,
	ulpi_reset => ulpi_reset,
	ulpi_clk60 => ulpi_clk60,
    
    usb_clk => usb_clk,
    usb_reset => usb_reset,
    
    usb_idle => usb_idle,
    usb_suspend => usb_suspend,
    usb_configured => usb_configured,
    usb_crc_error => usb_crc_error,
    usb_sof => usb_sof,
    
    ctl_xfer_endpoint => ctl_xfer_endpoint,
    ctl_xfer_type => ctl_xfer_type,
    ctl_xfer_request => ctl_xfer_request,
    ctl_xfer_value => ctl_xfer_value,
    ctl_xfer_index => ctl_xfer_index,
    ctl_xfer_length => ctl_xfer_length,
    ctl_xfer_accept => ctl_xfer_accept,
    ctl_xfer => ctl_xfer,
    ctl_xfer_done => ctl_xfer_done,
    
    ctl_xfer_data_out => ctl_xfer_data_out,
    ctl_xfer_data_out_valid => ctl_xfer_data_out_valid,
    
    ctl_xfer_data_in => ctl_xfer_data_in,
    ctl_xfer_data_in_valid => ctl_xfer_data_in_valid,
    ctl_xfer_data_in_last => ctl_xfer_data_in_last,
    ctl_xfer_data_in_ready => ctl_xfer_data_in_ready,
    
    blk_xfer_endpoint => blk_xfer_endpoint,
    blk_in_xfer => blk_in_xfer,
    blk_out_xfer => blk_out_xfer,
    
    blk_xfer_in_has_data => blk_xfer_in_has_data,
    blk_xfer_in_data => blk_xfer_in_data,
    blk_xfer_in_data_valid => blk_xfer_in_data_valid,
    blk_xfer_in_data_ready => blk_xfer_in_data_ready,
    blk_xfer_in_data_last => blk_xfer_in_data_last,
    
    blk_xfer_out_ready_read => blk_xfer_out_ready_read,
    blk_xfer_out_data => blk_xfer_out_data,
    blk_xfer_out_data_valid => blk_xfer_out_data_valid
  );
  
  FLASHER: usb_flasher
  port map (
    clk => usb_clk,
    rst => usb_reset,
    
    ctl_xfer_endpoint => ctl_xfer_endpoint,
    ctl_xfer_type => ctl_xfer_type,
    ctl_xfer_request => ctl_xfer_request,
    ctl_xfer_value => ctl_xfer_value,
    ctl_xfer_index => ctl_xfer_index,
    ctl_xfer_length => ctl_xfer_length,
    ctl_xfer_accept => ctl_xfer_accept,
    ctl_xfer => ctl_xfer,
    ctl_xfer_done => ctl_xfer_done,
    
    ctl_xfer_data_out => ctl_xfer_data_out,
    ctl_xfer_data_out_valid => ctl_xfer_data_out_valid,
    
    ctl_xfer_data_in => ctl_xfer_data_in,
    ctl_xfer_data_in_valid => ctl_xfer_data_in_valid,
    ctl_xfer_data_in_last => ctl_xfer_data_in_last,
    ctl_xfer_data_in_ready => ctl_xfer_data_in_ready,
    
    blk_xfer_endpoint => blk_xfer_endpoint,
    blk_in_xfer => blk_in_xfer,
    blk_out_xfer => blk_out_xfer,
    
    blk_xfer_in_has_data => blk_xfer_in_has_data,
    blk_xfer_in_data => blk_xfer_in_data,
    blk_xfer_in_data_valid => blk_xfer_in_data_valid,
    blk_xfer_in_data_ready => blk_xfer_in_data_ready,
    blk_xfer_in_data_last => blk_xfer_in_data_last,
    
    blk_xfer_out_ready_read => blk_xfer_out_ready_read,
    blk_xfer_out_data => blk_xfer_out_data,
    blk_xfer_out_data_valid => blk_xfer_out_data_valid,
    
    spi_cs => spi_cs_int,
    spi_sck => spi_sck_int,
    spi_mosi => spi_mosi_int,
    spi_miso => spi_miso_int
  );
  
  spi_cs <= spi_cs_int;
  spi_sck <= spi_sck_int;
  spi_mosi <= spi_mosi_int;
  spi_miso_int <= spi_miso;
  
  dbg_clk <= usb_clk;
  dbg_trig <= '0';
  dbg(0) <= spi_cs_int;
  dbg(1) <= spi_sck_int;
  dbg(2) <= spi_mosi_int;
  dbg(3) <= spi_miso_int;
  dbg(14 downto 4) <= (others => '0');
  
  COUNT: process(usb_clk) is
  begin
    if rising_edge(usb_clk) then
      led_counter <= led_counter + 1;
    end if;
  end process;
  
  led <= '1' when usb_idle = '1' AND usb_configured = '1' else
         led_counter(led_counter'left) when usb_idle = '1' else
         '1' when led_counter(led_counter'left downto led_counter'left - 2) = "000" else
         '0';
  
end spi_flasher;
