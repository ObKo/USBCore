module ulpi_io (
    input  wire         phy_clk,
    output wire         phy_rst,
    
    input  wire         phy_dir,
    input  wire         phy_nxt,
    output wire         phy_stp,
    inout  wire [7:0]   phy_data,
    
    output wire         ulpi_clk,
    input  wire         ulpi_rst,
    
    output wire         ulpi_dir,
    output wire         ulpi_nxt,
    input  wire         ulpi_stp,
    output wire [7:0]   ulpi_data_in,
    input  wire [7:0]   ulpi_data_out
);

logic clk_nobuf;

IBUF CLK_IBUF (.I(phy_clk),  .O(clk_nobuf));
BUFR CLK_BUFG (.I(clk_nobuf),.O(ulpi_clk));
OBUF RST_OBUF (.I(ulpi_rst), .O(phy_rst));
IBUF DIR_IBUF (.I(phy_dir),  .O(ulpi_dir));
IBUF NXT_IBUF (.I(phy_nxt),  .O(ulpi_nxt));
OBUF STP_IBUF (.I(ulpi_stp), .O(phy_stp));

genvar i; generate for (i = 0; i < 8; i = i + 1)
    IOBUF DATA_IOBUF (.I(ulpi_data_out[i]), .O(ulpi_data_in[i]), .T(ulpi_dir), .IO(phy_data[i]));
endgenerate

endmodule
