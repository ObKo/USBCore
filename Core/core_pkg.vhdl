--
-- USB Full-Speed/Hi-Speed Device Controller core - core_pkg.vhdl
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
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

package usbcore is
  type BYTE_ARRAY is array(natural range <>) of std_logic_vector(7 downto 0);
  
  component usb_std_request is
    generic (
      VENDOR_ID    : std_logic_vector(15 downto 0);
      PRODUCT_ID   : std_logic_vector(15 downto 0);
      MANUFACTURER : string;
      PRODUCT      : string;
      SERIAL       : string;
      CONFIG_DESC  : BYTE_ARRAY;
      HIGH_SPEED   : boolean
    );
    port (
      rst                     : in  std_logic;
      clk                     : in  std_logic;

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

      device_address          : out std_logic_vector(6 downto 0);
      current_configuration   : out std_logic_vector(7 downto 0);
      configured              : out std_logic;

      standart_request        : out std_logic
      );
  end component;
  
  component ulpi_port is
    generic (
      HIGH_SPEED: boolean
    );
    port (
      rst            : in  std_logic;

      ulpi_data_in   : in  std_logic_vector(7 downto 0);
      ulpi_data_out  : out std_logic_vector(7 downto 0);
      ulpi_dir       : in  std_logic;
      ulpi_nxt       : in  std_logic;
      ulpi_stp       : out std_logic;
      ulpi_reset     : out std_logic;
      ulpi_clk       : in  std_logic;

      axis_rx_tvalid : out std_logic;
      axis_rx_tready : in  std_logic;
      axis_rx_tlast  : out std_logic;
      axis_rx_tdata  : out std_logic_vector(7 downto 0);

      axis_tx_tvalid : in  std_logic;
      axis_tx_tready : out std_logic;
      axis_tx_tlast  : in  std_logic;
      axis_tx_tdata  : in  std_logic_vector(7 downto 0);
      
      usb_vbus_valid : out std_logic;
      usb_reset      : out std_logic;
      usb_idle       : out std_logic;
      usb_suspend    : out std_logic
      );
  end component;

  component usb_packet is
    port (
      rst                 : in  std_logic;
      clk                 : in  std_logic;

      axis_rx_tvalid      : in  std_logic;
      axis_rx_tready      : out std_logic;
      axis_rx_tlast       : in  std_logic;
      axis_rx_tdata       : in  std_logic_vector(7 downto 0);

      axis_tx_tvalid      : out std_logic;
      axis_tx_tready      : in  std_logic;
      axis_tx_tlast       : out std_logic;
      axis_tx_tdata       : out std_logic_vector(7 downto 0);

      trn_type            : out std_logic_vector(1 downto 0);
      trn_address         : out std_logic_vector(6 downto 0);
      trn_endpoint        : out std_logic_vector(3 downto 0);
      trn_start           : out std_logic;

      rx_trn_data_type    : out std_logic_vector(1 downto 0);
      rx_trn_end          : out std_logic;
      rx_trn_data         : out std_logic_vector(7 downto 0);
      rx_trn_valid        : out std_logic;

      rx_trn_hsk_type     : out std_logic_vector(1 downto 0);
      rx_trn_hsk_received : out std_logic;

      tx_trn_hsk_type     : in  std_logic_vector(1 downto 0);
      tx_trn_send_hsk     : in  std_logic;
      tx_trn_hsk_sended   : out std_logic;

      tx_trn_data_type    : in  std_logic_vector(1 downto 0);
      tx_trn_data_start   : in  std_logic;

      tx_trn_data         : in  std_logic_vector(7 downto 0);
      tx_trn_data_valid   : in  std_logic;
      tx_trn_data_ready   : out std_logic;
      tx_trn_data_last    : in  std_logic;

      start_of_frame      : out std_logic;
      crc_error           : out std_logic;
      device_address      : in  std_logic_vector(6 downto 0)
      );
  end component;

  component usb_xfer is
    generic (
      HIGH_SPEED: boolean
    );
    port (
      rst                     : in  std_logic;
      clk                     : in  std_logic;

      trn_type                : in  std_logic_vector(1 downto 0);
      trn_address             : in  std_logic_vector(6 downto 0);
      trn_endpoint            : in  std_logic_vector(3 downto 0);
      trn_start               : in  std_logic;

      rx_trn_data_type        : in  std_logic_vector(1 downto 0);
      rx_trn_end              : in  std_logic;
      rx_trn_data             : in  std_logic_vector(7 downto 0);
      rx_trn_valid            : in  std_logic;

      rx_trn_hsk_type         : in  std_logic_vector(1 downto 0);
      rx_trn_hsk_received     : in  std_logic;

      tx_trn_hsk_type         : out std_logic_vector(1 downto 0);
      tx_trn_send_hsk         : out std_logic;
      tx_trn_hsk_sended       : in  std_logic;

      tx_trn_data_type        : out std_logic_vector(1 downto 0);
      tx_trn_data_start       : out std_logic;

      tx_trn_data             : out std_logic_vector(7 downto 0);
      tx_trn_data_valid       : out std_logic;
      tx_trn_data_ready       : in  std_logic;
      tx_trn_data_last        : out std_logic;

      crc_error               : in  std_logic;

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

      -- Has complete packet
      blk_xfer_in_has_data    : in  std_logic;
      blk_xfer_in_data        : in  std_logic_vector(7 downto 0);
      blk_xfer_in_data_valid  : in  std_logic;
      blk_xfer_in_data_ready  : out std_logic;
      blk_xfer_in_data_last   : in  std_logic;

      -- Can accept full packet
      blk_xfer_out_ready_read : in  std_logic;
      blk_xfer_out_data       : out std_logic_vector(7 downto 0);
      blk_xfer_out_data_valid : out std_logic
      );
  end component;
  
  component usb_tlp is
  generic (
    VENDOR_ID               : std_logic_vector(15 downto 0);
    PRODUCT_ID              : std_logic_vector(15 downto 0);
    MANUFACTURER            : string;
    PRODUCT                 : string;
    SERIAL                  : string;
    CONFIG_DESC             : BYTE_ARRAY;
    HIGH_SPEED              : boolean
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
end usbcore;