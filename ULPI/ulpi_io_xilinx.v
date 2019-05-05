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

wire phy_clk_nobuf;
wire ulpi_clk_nobuf;
wire clk_fbout, clk_fbin;

IBUF CLK_IBUF (.I(phy_clk),  .O(phy_clk_nobuf));

// CMT for compensating clock path skew 
MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT_F(15.0),
    .CLKFBOUT_PHASE(0.0),
    .CLKIN1_PERIOD(16.666),
    .CLKOUT0_DIVIDE_F(15.0), 
    .CLKOUT1_DIVIDE(15),
    .CLKOUT2_DIVIDE(15),
    .CLKOUT3_DIVIDE(15),
    .CLKOUT4_DIVIDE(15),
    .CLKOUT5_DIVIDE(15),
    .CLKOUT6_DIVIDE(15),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),
    .CLKOUT1_PHASE(0.0),
    .CLKOUT2_PHASE(0.0),
    .CLKOUT3_PHASE(0.0),
    .CLKOUT4_PHASE(0.0),
    .CLKOUT5_PHASE(0.0),
    .CLKOUT6_PHASE(0.0),
    .CLKOUT4_CASCADE("FALSE"),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER1(0.0),
    .STARTUP_WAIT("FALSE")
)
MMCME2_BASE_inst (
    .CLKOUT0(),
    .CLKOUT0B(),
    .CLKOUT1(ulpi_clk_nobuf),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(clk_fbout),
    .CLKFBOUTB(),
    .LOCKED(),
    .CLKIN1(phy_clk_nobuf),
    .PWRDWN(1'b0),
    .RST(ulpi_rst),
    .CLKFBIN(clk_fbin)
);

BUFG CLK_BUFG (.I(ulpi_clk_nobuf), .O(ulpi_clk));
BUFG FB_BUFG (.I(clk_fbout), .O(clk_fbin));

//BUFR CLK_BUFG (.I(clk_nobuf),.O(ulpi_clk));

OBUF RST_OBUF (.I(ulpi_rst), .O(phy_rst));
IBUF DIR_IBUF (.I(phy_dir),  .O(ulpi_dir));
IBUF NXT_IBUF (.I(phy_nxt),  .O(ulpi_nxt));
OBUF STP_IBUF (.I(ulpi_stp), .O(phy_stp));

genvar i; 
generate for (i = 0; i < 8; i = i + 1) begin
    IOBUF DATA_IOBUF (.I(ulpi_data_out[i]), .O(ulpi_data_in[i]), .T(ulpi_dir), .IO(phy_data[i]));
end endgenerate

endmodule
