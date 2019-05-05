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
wire         ulpi_rst;
wire         ulpi_dir;
wire         ulpi_nxt;
wire         ulpi_stp;
wire [7:0]   ulpi_data_in;
wire [7:0]   ulpi_data_out;

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

wire         usb_enable;

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
    .reg_dout(reg_dout)
);

usb_state_ctl STATE_CONTROLLER (
    .clk(ulpi_clk),
    .rst(ulpi_rst),
    
    .usb_enable(usb_enable),
    
    .vbus_state(vbus_state),
  
    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout)
);

debug_vio VIO (
    .clk(ulpi_clk),
    .probe_out0(usb_enable)
);

endmodule
