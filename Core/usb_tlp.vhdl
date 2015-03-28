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

entity usb_tlp is
  generic (
    VENDOR_ID    : std_logic_vector(15 downto 0) := X"DEAD";
    PRODUCT_ID   : std_logic_vector(15 downto 0) := X"BEEF";
    MANUFACTURER : string                        := "";
    PRODUCT      : string                        := "";
    SERIAL       : string                        := ""
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
  signal axis_rx_tdata               : std_logic_vector(7 downto 0);

  signal axis_tx_tvalid              : std_logic;
  signal axis_tx_tready              : std_logic;
  signal axis_tx_tlast               : std_logic;
  signal axis_tx_tdata               : std_logic_vector(7 downto 0);

  signal usb_line_state              : std_logic_vector(1 downto 0);
  signal usb_rx_active               : std_logic;
  signal usb_rx_error                : std_logic;
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

  signal reset_data_bit_toggling     : std_logic;

  signal current_configuration       : std_logic_vector(7 downto 0);

  signal usb_reset_int               : std_logic;
  signal usb_crc_error_int           : std_logic;
  
  signal standart_request            : std_logic;

  component ulpi_port is
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
      axis_rx_tdata  : out std_logic_vector(7 downto 0);

      axis_tx_tvalid : in  std_logic;
      axis_tx_tready : out std_logic;
      axis_tx_tlast  : in  std_logic;
      axis_tx_tdata  : in  std_logic_vector(7 downto 0);

      usb_line_state : out std_logic_vector(1 downto 0);
      usb_rx_active  : out std_logic;
      usb_rx_error   : out std_logic;
      usb_vbus_valid : out std_logic
      );
  end component;

  component usb_packet is
    port (
      rst                 : in  std_logic;
      clk                 : in  std_logic;

      axis_rx_tvalid      : in  std_logic;
      axis_rx_tready      : out std_logic;
      axis_rx_tdata       : in  std_logic_vector(7 downto 0);

      axis_tx_tvalid      : out std_logic;
      axis_tx_tready      : in  std_logic;
      axis_tx_tlast       : out std_logic;
      axis_tx_tdata       : out std_logic_vector(7 downto 0);

      usb_rx_active       : in  std_logic;
      usb_rx_error        : in  std_logic;

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
      crc_error           : out std_logic
      );
  end component;

  component usb_xfer is
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
      blk_xfer_out_data_valid : out std_logic;

      reset_data_bit_toggling : in  std_logic
      );
  end component;

  component usb_std_request is
    generic (
      VENDOR_ID    : std_logic_vector(15 downto 0) := X"DEAD";
      PRODUCT_ID   : std_logic_vector(15 downto 0) := X"BEEF";
      MANUFACTURER : string                        := "";
      PRODUCT      : string                        := "";
      SERIAL       : string                        := ""
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

      current_configuration   : out std_logic_vector(7 downto 0);
      configured              : out std_logic;

      reset_data_bit_toggling : out std_logic;
      standart_request        : out std_logic
      );
  end component;

  component usb_state is
    port (
      rst            : in  std_logic;
      clk            : in  std_logic;

      usb_line_state : in  std_logic_vector(1 downto 0);

      reset          : out std_logic;
      idle           : out std_logic;
      suspend        : out std_logic
      );
  end component;

begin
  ULPI : ulpi_port
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
      axis_rx_tdata  => axis_rx_tdata,

      axis_tx_tvalid => axis_tx_tvalid,
      axis_tx_tready => axis_tx_tready,
      axis_tx_tlast  => axis_tx_tlast,
      axis_tx_tdata  => axis_tx_tdata,

      usb_line_state => usb_line_state,
      usb_rx_active  => usb_rx_active,
      usb_rx_error   => usb_rx_error,
      usb_vbus_valid => usb_vbus_valid
      );

  PACKET_CONTROLLER : usb_packet
    port map (
      rst                 => usb_reset_int,
      clk                 => ulpi_clk60,

      axis_rx_tvalid      => axis_rx_tvalid,
      axis_rx_tready      => axis_rx_tready,
      axis_rx_tdata       => axis_rx_tdata,

      axis_tx_tvalid      => axis_tx_tvalid,
      axis_tx_tready      => axis_tx_tready,
      axis_tx_tlast       => axis_tx_tlast,
      axis_tx_tdata       => axis_tx_tdata,

      usb_rx_active       => usb_rx_active,
      usb_rx_error        => usb_rx_error,

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
      crc_error           => usb_crc_error_int
      );

  TRANSFER_CONTROLLER : usb_xfer
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
      blk_xfer_out_data_valid => blk_xfer_out_data_valid,

      reset_data_bit_toggling => reset_data_bit_toggling
      );

  STD_REQ_CONTROLLER : usb_std_request
    generic map (
      VENDOR_ID    => VENDOR_ID,
      PRODUCT_ID   => PRODUCT_ID,
      MANUFACTURER => MANUFACTURER,
      PRODUCT      => PRODUCT,
      SERIAL       => SERIAL
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

      current_configuration   => current_configuration,
      configured              => usb_configured,

      reset_data_bit_toggling => reset_data_bit_toggling,
      standart_request        => standart_request
      );

  STATE_CONTROLLER : usb_state
    port map (
      rst            => '0',
      clk            => ulpi_clk60,

      usb_line_state => usb_line_state,

      reset          => usb_reset_int,
      idle           => usb_idle,
      suspend        => usb_suspend
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
