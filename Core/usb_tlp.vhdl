--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_tlp.vhdl
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

library work;
use work.USBCore.all;

entity usb_tlp is
  generic (
    VENDOR_ID    : std_logic_vector(15 downto 0) := X"DEAD";
    PRODUCT_ID   : std_logic_vector(15 downto 0) := X"BEEF";
    MANUFACTURER : string                        := "";
    PRODUCT      : string                        := "";
    SERIAL       : string                        := "";
    CONFIG_DESC  : BYTE_ARRAY := (
      -- Configuration descriptor
      X"09",        -- bLength = 9
      X"02",        -- bDescriptionType = Configuration Descriptor
      X"12", X"00", -- wTotalLength = 18
      X"01",        -- bNumInterfaces = 1
      X"01",        -- bConfigurationValue
      X"00",        -- iConfiguration
      X"C0",        -- bmAttributes = Self-powered
      X"32",        -- bMaxPower = 100 mA
      -- Interface descriptor
      X"09",        -- bLength = 9
      X"04",        -- bDescriptorType = Interface Descriptor
      X"00",        -- bInterfaceNumber = 0
      X"00",        -- bAlternateSetting
      X"00",        -- bNumEndpoints = 0
      X"00",        -- bInterfaceClass
      X"00",        -- bInterfaceSubClass
      X"00",        -- bInterfaceProtocol
      X"00"         -- iInterface
      );
    HIGH_SPEED   : boolean := true
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
    -- Pulse when SOF packet received
    usb_sof                 : out std_logic;

    -- Control transfer signals
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

    -- Bulk transfer signals
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
end usb_tlp;

architecture usb_tlp of usb_tlp is
  signal axis_rx_tvalid              : std_logic;
  signal axis_rx_tready              : std_logic;
  signal axis_rx_tlast               : std_logic;
  signal axis_rx_tdata               : std_logic_vector(7 downto 0);

  signal axis_tx_tvalid              : std_logic;
  signal axis_tx_tready              : std_logic;
  signal axis_tx_tlast               : std_logic;
  signal axis_tx_tdata               : std_logic_vector(7 downto 0);

  signal usb_vbus_valid              : std_logic;

  signal trn_type                    : std_logic_vector(1 downto 0);
  signal trn_address                 : std_logic_vector(6 downto 0);
  signal trn_endpoint                : std_logic_vector(3 downto 0);
  signal trn_start                   : std_logic;

  signal rx_trn_data_type            : std_logic_vector(1 downto 0);
  signal rx_trn_end                  : std_logic;
  signal rx_trn_data                 : std_logic_vector(7 downto 0);
  signal rx_trn_valid                : std_logic;

  signal rx_trn_hsk_type             : std_logic_vector(1 downto 0);
  signal rx_trn_hsk_received         : std_logic;

  signal tx_trn_hsk_type             : std_logic_vector(1 downto 0);
  signal tx_trn_send_hsk             : std_logic;
  signal tx_trn_hsk_sended           : std_logic;

  signal tx_trn_data_type            : std_logic_vector(1 downto 0);
  signal tx_trn_data_start           : std_logic;

  signal tx_trn_data                 : std_logic_vector(7 downto 0);
  signal tx_trn_data_valid           : std_logic;
  signal tx_trn_data_ready           : std_logic;
  signal tx_trn_data_last            : std_logic;

  signal ctl_xfer_endpoint_int       : std_logic_vector(3 downto 0);
  signal ctl_xfer_type_int           : std_logic_vector(7 downto 0);
  signal ctl_xfer_request_int        : std_logic_vector(7 downto 0);
  signal ctl_xfer_value_int          : std_logic_vector(15 downto 0);
  signal ctl_xfer_index_int          : std_logic_vector(15 downto 0);
  signal ctl_xfer_length_int         : std_logic_vector(15 downto 0);
  signal ctl_xfer_accept_int         : std_logic;
  signal ctl_xfer_int                : std_logic;
  signal ctl_xfer_done_int           : std_logic;
  
  signal ctl_xfer_accept_std         : std_logic;
  signal ctl_xfer_std                : std_logic;
  signal ctl_xfer_done_std           : std_logic;

  signal ctl_xfer_data_out_int       : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_out_valid_int : std_logic;

  signal ctl_xfer_data_in_int        : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_in_valid_int  : std_logic;
  signal ctl_xfer_data_in_last_int   : std_logic;
  signal ctl_xfer_data_in_ready_int  : std_logic;
  
  signal ctl_xfer_data_in_std        : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_in_valid_std  : std_logic;
  signal ctl_xfer_data_in_last_std   : std_logic;

  signal current_configuration       : std_logic_vector(7 downto 0);

  signal usb_reset_int               : std_logic;
  signal usb_crc_error_int           : std_logic;
  
  signal standart_request            : std_logic;
  
  signal device_address              : std_logic_vector(6 downto 0);  
begin
  ULPI : ulpi_port
    generic map (
      HIGH_SPEED => HIGH_SPEED
    )
    port map (
      rst            => '0',

      ulpi_data_in   => ulpi_data_in,
      ulpi_data_out  => ulpi_data_out,
      ulpi_dir       => ulpi_dir,
      ulpi_nxt       => ulpi_nxt,
      ulpi_stp       => ulpi_stp,
      ulpi_reset     => ulpi_reset,
      ulpi_clk       => ulpi_clk60,

      axis_rx_tvalid => axis_rx_tvalid,
      axis_rx_tready => axis_rx_tready,
      axis_rx_tlast  => axis_rx_tlast,
      axis_rx_tdata  => axis_rx_tdata,

      axis_tx_tvalid => axis_tx_tvalid,
      axis_tx_tready => axis_tx_tready,
      axis_tx_tlast  => axis_tx_tlast,
      axis_tx_tdata  => axis_tx_tdata,

      usb_vbus_valid => usb_vbus_valid,
      usb_reset      => usb_reset_int,
      usb_idle       => usb_idle,
      usb_suspend    => usb_suspend
      );

  PACKET_CONTROLLER : usb_packet
    port map (
      rst                 => usb_reset_int,
      clk                 => ulpi_clk60,

      axis_rx_tvalid      => axis_rx_tvalid,
      axis_rx_tready      => axis_rx_tready,
      axis_rx_tlast       => axis_rx_tlast,
      axis_rx_tdata       => axis_rx_tdata,

      axis_tx_tvalid      => axis_tx_tvalid,
      axis_tx_tready      => axis_tx_tready,
      axis_tx_tlast       => axis_tx_tlast,
      axis_tx_tdata       => axis_tx_tdata,

      trn_type            => trn_type,
      trn_address         => trn_address,
      trn_endpoint        => trn_endpoint,
      trn_start           => trn_start,

      rx_trn_data_type    => rx_trn_data_type,
      rx_trn_end          => rx_trn_end,
      rx_trn_data         => rx_trn_data,
      rx_trn_valid        => rx_trn_valid,

      rx_trn_hsk_type     => rx_trn_hsk_type,
      rx_trn_hsk_received => rx_trn_hsk_received,

      tx_trn_hsk_type     => tx_trn_hsk_type,
      tx_trn_send_hsk     => tx_trn_send_hsk,
      tx_trn_hsk_sended   => tx_trn_hsk_sended,

      tx_trn_data_type    => tx_trn_data_type,
      tx_trn_data_start   => tx_trn_data_start,

      tx_trn_data         => tx_trn_data,
      tx_trn_data_valid   => tx_trn_data_valid,
      tx_trn_data_ready   => tx_trn_data_ready,
      tx_trn_data_last    => tx_trn_data_last,

      start_of_frame      => usb_sof,
      crc_error           => usb_crc_error_int,
      device_address      => device_address
      );

  TRANSFER_CONTROLLER : usb_xfer
    generic map (
      HIGH_SPEED => HIGH_SPEED
    )
    port map (
      rst                     => usb_reset_int,
      clk                     => ulpi_clk60,

      trn_type                => trn_type,
      trn_address             => trn_address,
      trn_endpoint            => trn_endpoint,
      trn_start               => trn_start,

      rx_trn_data_type        => rx_trn_data_type,
      rx_trn_end              => rx_trn_end,
      rx_trn_data             => rx_trn_data,
      rx_trn_valid            => rx_trn_valid,

      rx_trn_hsk_type         => rx_trn_hsk_type,
      rx_trn_hsk_received     => rx_trn_hsk_received,

      tx_trn_hsk_type         => tx_trn_hsk_type,
      tx_trn_send_hsk         => tx_trn_send_hsk,
      tx_trn_hsk_sended       => tx_trn_hsk_sended,

      tx_trn_data_type        => tx_trn_data_type,
      tx_trn_data_start       => tx_trn_data_start,

      tx_trn_data             => tx_trn_data,
      tx_trn_data_valid       => tx_trn_data_valid,
      tx_trn_data_ready       => tx_trn_data_ready,
      tx_trn_data_last        => tx_trn_data_last,

      crc_error               => usb_crc_error_int,

      ctl_xfer_endpoint       => ctl_xfer_endpoint_int,
      ctl_xfer_type           => ctl_xfer_type_int,
      ctl_xfer_request        => ctl_xfer_request_int,
      ctl_xfer_value          => ctl_xfer_value_int,
      ctl_xfer_index          => ctl_xfer_index_int,
      ctl_xfer_length         => ctl_xfer_length_int,
      ctl_xfer_accept         => ctl_xfer_accept_int,
      ctl_xfer                => ctl_xfer_int,
      ctl_xfer_done           => ctl_xfer_done_int,

      ctl_xfer_data_out       => ctl_xfer_data_out_int,
      ctl_xfer_data_out_valid => ctl_xfer_data_out_valid_int,

      ctl_xfer_data_in        => ctl_xfer_data_in_int,
      ctl_xfer_data_in_valid  => ctl_xfer_data_in_valid_int,
      ctl_xfer_data_in_last   => ctl_xfer_data_in_last_int,
      ctl_xfer_data_in_ready  => ctl_xfer_data_in_ready_int,

      blk_xfer_endpoint       => blk_xfer_endpoint,
      blk_in_xfer             => blk_in_xfer,
      blk_out_xfer            => blk_out_xfer,

      blk_xfer_in_has_data    => blk_xfer_in_has_data,
      blk_xfer_in_data        => blk_xfer_in_data,
      blk_xfer_in_data_valid  => blk_xfer_in_data_valid,
      blk_xfer_in_data_ready  => blk_xfer_in_data_ready,
      blk_xfer_in_data_last   => blk_xfer_in_data_last,

      blk_xfer_out_ready_read => blk_xfer_out_ready_read,
      blk_xfer_out_data       => blk_xfer_out_data,
      blk_xfer_out_data_valid => blk_xfer_out_data_valid
      );

  STD_REQ_CONTROLLER : usb_std_request
    generic map (
      VENDOR_ID    => VENDOR_ID,
      PRODUCT_ID   => PRODUCT_ID,
      MANUFACTURER => MANUFACTURER,
      PRODUCT      => PRODUCT,
      SERIAL       => SERIAL,
      CONFIG_DESC  => CONFIG_DESC,
      HIGH_SPEED   => HIGH_SPEED
      )
    port map (
      rst                     => usb_reset_int,
      clk                     => ulpi_clk60,

      ctl_xfer_endpoint       => ctl_xfer_endpoint_int,
      ctl_xfer_type           => ctl_xfer_type_int,
      ctl_xfer_request        => ctl_xfer_request_int,
      ctl_xfer_value          => ctl_xfer_value_int,
      ctl_xfer_index          => ctl_xfer_index_int,
      ctl_xfer_length         => ctl_xfer_length_int,
      ctl_xfer_accept         => ctl_xfer_accept_std,
      ctl_xfer                => ctl_xfer_int,
      ctl_xfer_done           => ctl_xfer_done_std,

      ctl_xfer_data_out       => ctl_xfer_data_out_int,
      ctl_xfer_data_out_valid => ctl_xfer_data_out_valid_int,

      ctl_xfer_data_in        => ctl_xfer_data_in_std,
      ctl_xfer_data_in_valid  => ctl_xfer_data_in_valid_std,
      ctl_xfer_data_in_last   => ctl_xfer_data_in_last_std,
      ctl_xfer_data_in_ready  => ctl_xfer_data_in_ready_int,

      device_address          => device_address,
      current_configuration   => current_configuration,
      configured              => usb_configured,
      
      standart_request        => standart_request
      );

  usb_clk       <= ulpi_clk60;
  usb_reset     <= usb_reset_int;
  usb_crc_error <= usb_crc_error_int;
  
  ctl_xfer_endpoint <= ctl_xfer_endpoint_int;
  ctl_xfer_type     <= ctl_xfer_type_int;
  ctl_xfer_request  <= ctl_xfer_request_int;
  ctl_xfer_value    <= ctl_xfer_value_int;
  ctl_xfer_index    <= ctl_xfer_index_int;
  ctl_xfer_length   <= ctl_xfer_length_int;
  
  ctl_xfer_accept_int <= ctl_xfer_accept_std when standart_request = '1' else
                         ctl_xfer_accept;
  ctl_xfer            <= ctl_xfer_int when standart_request = '0' else
                         '0';
  ctl_xfer_done_int   <= ctl_xfer_done_std when standart_request = '1' else
                         ctl_xfer_done;
                         
  ctl_xfer_data_out       <= ctl_xfer_data_out_int;
  ctl_xfer_data_out_valid <= ctl_xfer_data_out_valid_int when standart_request = '0' else
                             '0';
                             
  ctl_xfer_data_in_int       <= ctl_xfer_data_in_std when standart_request = '1' else
                                ctl_xfer_data_in;
  ctl_xfer_data_in_valid_int <= ctl_xfer_data_in_valid_std when standart_request = '1' else
                                ctl_xfer_data_in_valid;
  ctl_xfer_data_in_last_int  <= ctl_xfer_data_in_last_std when standart_request = '1' else
                                ctl_xfer_data_in_last;
  ctl_xfer_data_in_ready     <= ctl_xfer_data_in_ready_int when standart_request = '0' else
                                '0';
end usb_tlp;
