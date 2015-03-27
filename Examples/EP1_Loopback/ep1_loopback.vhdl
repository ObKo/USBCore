--
-- USB Full-Speed/Hi-Speed Device Controller core - ep1_loopback.vhdl
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

entity ep1_loopback is
  port (
    led         : out   std_logic;
    ulpi_data   : inout std_logic_vector(7 downto 0);
    ulpi_dir    : in    std_logic;
    ulpi_nxt    : in    std_logic;
    ulpi_stp    : out   std_logic;
    ulpi_reset  : out   std_logic;
    ulpi_clk60  : in    std_logic;
    
    main_clk    : in    std_logic
        
--    dbg         : out   std_logic_vector(13 downto 0);
--    dbg_clk     : out   std_logic;
--    dbg_trig    : out   std_logic;
--    rstn        : in    std_logic
  );
end ep1_loopback;

architecture ep1_loopback of ep1_loopback is  
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
  
  signal ep1_in_axis_tdata      : std_logic_vector(7 downto 0);
  signal ep1_in_axis_tvalid     : std_logic;
  signal ep1_in_axis_tready     : std_logic;
  signal ep1_in_axis_tlast      : std_logic;
  
  signal ep1_out_axis_tdata     : std_logic_vector(7 downto 0);
  signal ep1_out_axis_tvalid    : std_logic;
  signal ep1_out_axis_tready    : std_logic;
  signal ep1_out_axis_tlast     : std_logic;
  
  signal led_counter            : std_logic_vector(25 downto 0);
  
  component usb_tlp is
    generic (
    VENDOR_ID               : std_logic_vector(15 downto 0) := X"DEAD";
    PRODUCT_ID              : std_logic_vector(15 downto 0) := X"BEEF";
    MANUFACTURER            : string := "";
    PRODUCT                 : string := "";
    SERIAL                  : string := ""
  );
  port (
    ulpi_data_in            : in  std_logic_vector(7 downto 0);
    ulpi_data_out           : out std_logic_vector(7 downto 0);
    ulpi_dir                : in  std_logic;
    ulpi_nxt                : in  std_logic;
    ulpi_stp                : out std_logic;
    ulpi_reset              : out std_logic;
    ulpi_clk60              : in  std_logic;
    
    usb_clk                 : out std_logic;
    usb_reset               : out std_logic;
    
    usb_idle                : out std_logic;
    usb_suspend             : out std_logic;
    usb_configured          : out std_logic;
    usb_crc_error           : out std_logic;
    usb_sof                 : out std_logic;
    
    ctl_xfer_endpoint       : out std_logic_vector(3 downto 0);
    ctl_xfer_type           : out std_logic_vector(7 downto 0);
    ctl_xfer_request        : out std_logic_vector(7 downto 0);
    ctl_xfer_value          : out std_logic_vector(15 downto 0);
    ctl_xfer_index          : out std_logic_vector(15 downto 0);
    ctl_xfer_length         : out std_logic_vector(15 downto 0);
    ctl_xfer_accept         : in  std_logic;
    ctl_xfer                : out std_logic;
    ctl_xfer_done           : in  std_logic;
    
    ctl_xfer_data_out       : out std_logic_vector(7 downto 0);
    ctl_xfer_data_out_valid : out std_logic;
    
    ctl_xfer_data_in        : in  std_logic_vector(7 downto 0);
    ctl_xfer_data_in_valid  : in  std_logic;
    ctl_xfer_data_in_last   : in  std_logic;
    ctl_xfer_data_in_ready  : out std_logic;
        
    blk_xfer_endpoint       : out std_logic_vector(3 downto 0);
    blk_in_xfer             : out std_logic;
    blk_out_xfer            : out std_logic;
    
    blk_xfer_in_has_data    : in  std_logic;
    blk_xfer_in_data        : in  std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : in  std_logic;
    blk_xfer_in_data_ready  : out std_logic;
    blk_xfer_in_data_last   : in  std_logic;
    
    blk_xfer_out_ready_read : in  std_logic;
    blk_xfer_out_data       : out std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : out std_logic
  );
  end component;
  
  component blk_ep_out_ctl is
  port (
    rst                     : in  std_logic;
    usb_clk                 : in  std_logic;
    axis_clk                : in  std_logic;
    
    blk_out_xfer            : in  std_logic;

    blk_xfer_out_ready_read : out std_logic;
    blk_xfer_out_data       : in  std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : in  std_logic;
    
    axis_tdata              : out std_logic_vector(7 downto 0);
    axis_tvalid             : out std_logic;
    axis_tready             : in  std_logic;
    axis_tlast              : out std_logic
  );
  end component;
  
  component blk_ep_in_ctl is
  port (
    rst                     : in  std_logic;
    usb_clk                 : in  std_logic;
    axis_clk                : in  std_logic;

    blk_in_xfer             : in  std_logic;
    
    blk_xfer_in_has_data    : out std_logic;
    blk_xfer_in_data        : out std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : out std_logic;
    blk_xfer_in_data_ready  : in  std_logic;
    blk_xfer_in_data_last   : out std_logic;
    
    axis_tdata              : in  std_logic_vector(7 downto 0);
    axis_tvalid             : in  std_logic;
    axis_tready             : out std_logic;
    axis_tlast              : in  std_logic
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
    PRODUCT => "Endpoint 1 Loopback Device",
    SERIAL => ""
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
  
  EP1_IN_CTL: blk_ep_in_ctl 
  port map (
    rst => usb_reset,
    usb_clk => usb_clk,
    axis_clk => main_clk,

    blk_in_xfer => blk_in_xfer,
    
    blk_xfer_in_has_data => blk_xfer_in_has_data,
    blk_xfer_in_data => blk_xfer_in_data,
    blk_xfer_in_data_valid => blk_xfer_in_data_valid,
    blk_xfer_in_data_ready => blk_xfer_in_data_ready,
    blk_xfer_in_data_last => blk_xfer_in_data_last,
    
    axis_tdata => ep1_in_axis_tdata,
    axis_tvalid => ep1_in_axis_tvalid,
    axis_tready => ep1_in_axis_tready,
    axis_tlast => ep1_in_axis_tlast
  );
  
  EP1_OUT_CTL: blk_ep_out_ctl 
  port map (
    rst => usb_reset,
    usb_clk => usb_clk,
    axis_clk => main_clk,

    blk_out_xfer => blk_out_xfer,
    
    blk_xfer_out_ready_read => blk_xfer_out_ready_read,
    blk_xfer_out_data => blk_xfer_out_data,
    blk_xfer_out_data_valid => blk_xfer_out_data_valid,
    
    axis_tdata => ep1_out_axis_tdata,
    axis_tvalid => ep1_out_axis_tvalid,
    axis_tready => ep1_out_axis_tready,
    axis_tlast => ep1_out_axis_tlast
  );
  
  ep1_in_axis_tdata <= ep1_out_axis_tdata;
  ep1_in_axis_tvalid <= ep1_out_axis_tvalid;
  ep1_out_axis_tready <= ep1_in_axis_tready;
  ep1_in_axis_tlast <= ep1_out_axis_tlast;
  
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
  
end ep1_loopback;
