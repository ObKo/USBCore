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
(* mark_debug = "true" *)reg          ulpi_rst;
(* mark_debug = "true" *)wire         ulpi_dir;
(* mark_debug = "true" *)wire         ulpi_nxt;
(* mark_debug = "true" *)wire         ulpi_stp;
(* mark_debug = "true" *)wire [7:0]   ulpi_data_in;
(* mark_debug = "true" *)wire [7:0]   ulpi_data_out;

// Dirty
always @(posedge ulpi_clk, negedge rst_btn)
    if (~rst_btn)
        ulpi_rst <= 1'b1;
    else
        ulpi_rst <= 1'b0;
    
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

assign ulpi_stp = 1'b0;
assign ulpi_data_out = 8'h00;

endmodule
