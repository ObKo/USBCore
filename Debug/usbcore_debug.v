module usbcore_debug (
    inout  wire         rst_btn,

    input  wire         phy_clk,
    output wire         phy_rst,
    
    input  wire         phy_dir,
    input  wire         phy_nxt,
    output wire         phy_stp,
    inout  wire [7:0]   phy_data
);

(* keep = "true" *)
wire         ulpi_clk;
(* mark_debug = "true" *)wire         ulpi_rst;
(* mark_debug = "true" *)wire         ulpi_dir;
(* mark_debug = "true" *)wire         ulpi_nxt;
(* mark_debug = "true" *)wire         ulpi_stp;
(* mark_debug = "true" *)wire [7:0]   ulpi_data_in;
(* mark_debug = "true" *)wire [7:0]   ulpi_data_out;

// Dirty
assign ulpi_rst = ~rst_btn;
    
ulpi_io IO (
    .phy_clk        (phy_clk),
    .phy_rst        (phy_rst),
    
    .phy_dir        (phy_dir),
    .phy_nxt        (phy_nxt),
    .phy_stp        (phy_stp),
    .phy_data       (phy_data),
    
    .ulpi_clk       (ulpi_clk),
    .ulpi_rst       (ulpi_rst),
    
    .ulpi_dir       (ulpi_dir),
    .ulpi_nxt       (ulpi_nxt),
    .ulpi_stp       (ulpi_stp),
    .ulpi_data_in   (ulpi_data_in),
    .ulpi_data_out  (ulpi_data_out)
);

(* mark_debug = "true" *)wire         usb_enable;
(* mark_debug = "true" *)wire         usb_reset;

wire [1:0]   line_state;
wire [1:0]   vbus_state;
wire         rx_active;
wire         rx_error;
wire         host_disconnect;

wire         reg_en;
wire         reg_rdy;
wire         reg_we;
wire [7:0]   reg_addr;
wire [7:0]   reg_din;
wire [7:0]   reg_dout;

wire [7:0]   axis_rx_tdata;
wire         axis_rx_tlast;
wire         axis_rx_error;
wire         axis_rx_tvalid;
wire         axis_rx_tready;

wire [7:0]   axis_tx_tdata;
wire         axis_tx_tlast;
wire         axis_tx_tvalid;
wire         axis_tx_tready;

ulpi_ctl ULPI_CONTROLLER (
    .ulpi_clk(ulpi_clk),
    .ulpi_rst(ulpi_rst),
    
    .ulpi_dir(ulpi_dir),
    .ulpi_nxt(ulpi_nxt),
    .ulpi_stp(ulpi_stp),
    .ulpi_data_in(ulpi_data_in),
    .ulpi_data_out(ulpi_data_out),
   
    .line_state(line_state),
    .vbus_state(vbus_state),
    .rx_active(rx_active),
    .rx_error(rx_error),
    .host_disconnect(host_disconnect),
    
    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout),
    
    .axis_rx_tdata(axis_rx_tdata),
    .axis_rx_tlast(axis_rx_tlast),
    .axis_rx_error(axis_rx_error),
    .axis_rx_tvalid(axis_rx_tvalid),
    .axis_rx_tready(axis_rx_tready),
    
    .axis_tx_tdata(axis_tx_tdata),
    .axis_tx_tlast(axis_tx_tlast),
    .axis_tx_tvalid(axis_tx_tvalid),
    .axis_tx_tready(axis_tx_tready)
);

usb_state_ctl STATE_CONTROLLER (
    .clk(ulpi_clk),
    .rst(ulpi_rst),
    
    .usb_enable(usb_enable),
    .usb_reset(usb_reset),
    
    .line_state(line_state),
  
    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout)
);

wire         rx_out;
wire         rx_in;
wire         rx_setup;
wire         rx_sof;

wire [6:0]   rx_addr;
wire [3:0]   rx_endpoint;
wire [10:0]  rx_frame_number;

wire         rx_handshake;
wire [1:0]   rx_handshake_type;

wire         rx_data;
wire [1:0]   rx_data_type;

wire [7:0]   rx_data_tdata;
wire         rx_data_tlast;
wire         rx_data_error;
wire         rx_data_tvalid;
wire         rx_data_tready;

wire         tx_ready;

wire         tx_handshake;
wire [1:0]   tx_handshake_type;

wire         tx_data;
wire         tx_data_null;
wire [1:0]   tx_data_type;

wire [7:0]   tx_data_tdata;
wire         tx_data_tlast;
wire         tx_data_tvalid;
wire         tx_data_tready;

usb_tlp TLP (
    .clk(ulpi_clk),
    .rst(usb_reset),
    
    .rx_out(rx_out),
    .rx_in(rx_in),
    .rx_setup(rx_setup),
    .rx_sof(rx_sof),
    
    .rx_addr(rx_addr),
    .rx_endpoint(rx_endpoint),
    .rx_frame_number(rx_frame_number),
    
    .rx_handshake(rx_handshake),
    .rx_handshake_type(rx_handshake_type),
    
    .rx_data(rx_data),
    .rx_data_type(rx_data_type),
    
    .rx_data_tdata(rx_data_tdata),
    .rx_data_tlast(rx_data_tlast),
    .rx_data_error(rx_data_error),
    .rx_data_tvalid(rx_data_tvalid),
    .rx_data_tready(rx_data_tready),
    
    .tx_ready(tx_ready),
    
    .tx_handshake(tx_handshake),
    .tx_handshake_type(tx_handshake_type),
    
    .tx_data(tx_data),
    .tx_data_null(tx_data_null),
    .tx_data_type(tx_data_type),
    
    .tx_data_tdata(tx_data_tdata),
    .tx_data_tlast(tx_data_tlast),
    .tx_data_tvalid(tx_data_tvalid),
    .tx_data_tready(tx_data_tready),
    
    .axis_rx_tdata(axis_rx_tdata),
    .axis_rx_tlast(axis_rx_tlast),
    .axis_rx_error(axis_rx_error),
    .axis_rx_tvalid(axis_rx_tvalid),
    .axis_rx_tready(axis_rx_tready),
    
    .axis_tx_tdata(axis_tx_tdata),
    .axis_tx_tlast(axis_tx_tlast),
    .axis_tx_tvalid(axis_tx_tvalid),
    .axis_tx_tready(axis_tx_tready)
);

wire [3:0]   ctl_endpoint;
wire [7:0]   ctl_request_type;
wire [7:0]   ctl_request;
wire [15:0]  ctl_value;
wire [15:0]  ctl_index;
wire [15:0]  ctl_length;
wire         ctl_req;

wire [7:0]   xfer_rx_tdata;
wire         xfer_rx_tlast;
wire         xfer_rx_error;
wire         xfer_rx_tvalid;
wire         xfer_rx_tready;

wire [7:0]   xfer_tx_tdata;
wire         xfer_tx_tlast;
wire         xfer_tx_tvalid;
wire         xfer_tx_tready;

usb_xfer XFER (
    .clk(ulpi_clk),
    .rst(usb_reset),

    .rx_out(rx_out),
    .rx_in(rx_in),
    .rx_setup(rx_setup),
    .rx_addr(rx_addr),
    .rx_endpoint(rx_endpoint),
    
    .rx_handshake(rx_handshake),
    .rx_handshake_type(rx_handshake_type),
    
    .rx_data(rx_data),
    .rx_data_type(rx_data_type),
    
    .rx_data_tdata(rx_data_tdata),
    .rx_data_tlast(rx_data_tlast),
    .rx_data_error(rx_data_error),
    .rx_data_tvalid(rx_data_tvalid),
    .rx_data_tready(rx_data_tready),
    
    .tx_ready(tx_ready),
    
    .tx_handshake(tx_handshake),
    .tx_handshake_type(tx_handshake_type),
    
    .tx_data(tx_data),
    .tx_data_null(tx_data_null),
    .tx_data_type(tx_data_type),
    
    .tx_data_tdata(tx_data_tdata),
    .tx_data_tlast(tx_data_tlast),
    .tx_data_tvalid(tx_data_tvalid),
    .tx_data_tready(tx_data_tready),
    
    .ctl_endpoint(ctl_endpoint),
    .ctl_request_type(ctl_request_type),
    .ctl_request(ctl_request),
    .ctl_value(ctl_value),
    .ctl_index(ctl_index),
    .ctl_length(ctl_length),
    .ctl_req(ctl_req),
    .ctl_ack(ctl_ack),
    
    .xfer_rx_tdata(xfer_rx_tdata),
    .xfer_rx_tlast(xfer_rx_tlast),
    .xfer_rx_error(xfer_rx_error),
    .xfer_rx_tvalid(xfer_rx_tvalid),
    .xfer_rx_tready(xfer_rx_tready),
   
    .xfer_tx_tdata(xfer_tx_tdata),
    .xfer_tx_tlast(xfer_tx_tlast),
    .xfer_tx_tvalid(xfer_tx_tvalid),
    .xfer_tx_tready(xfer_tx_tready)
);

assign xfer_rx_tready = 1'b1;

assign xfer_tx_tdata  = 8'hDE;
assign xfer_tx_tlast  = 1'b0;
assign xfer_tx_tvalid = 1'b1;

debug_vio VIO (
    .clk(ulpi_clk),
    .probe_out0(usb_enable),
    .probe_out1(ctl_ack)
);

endmodule
