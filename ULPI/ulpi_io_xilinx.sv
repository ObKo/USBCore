module ulpi_io (
    ulpi_phy_iface.io   phy, 
    
    (* keep = "true" *)
    output              clk,
    input               rst,
    
    ulpi_iface.io       ulpi
);

logic clk_nobuf;

IBUF CLK_IBUF (.I(phy.clk),  .O(clk_nobuf));
BUFR CLK_BUFG (.I(clk_nobuf),.O(clk));
OBUF RST_OBUF (.I(rst),      .O(phy.rst));
IBUF DIR_IBUF (.I(phy.dir),  .O(ulpi.dir));
IBUF NXT_IBUF (.I(phy.nxt),  .O(ulpi.nxt));
OBUF STP_IBUF (.I(ulpi.stp), .O(phy.stp));

genvar i; generate for (i = 0; i < 8; i = i + 1)
    IOBUF DATA_IOBUF (.I(ulpi.tx_data[i]), .O(ulpi.rx_data[i]), .T(ulpi.dir), .IO(phy.data[i]));
endgenerate

endmodule
