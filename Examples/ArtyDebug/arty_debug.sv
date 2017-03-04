module arty_debug (
    ulpi_phy_iface.io phy
);

logic       ulpi_clk;
logic       ulpi_rst;

axi_lite_iface ulpi_csr();


ulpi_controller ULPI_CTL (
    .ulpi_phy(phy),
    
    .ulpi_clk(ulpi_clk),
    .ulpi_rst(ulpi_rst),
    
    .ulpi_csr(ulpi_csr)
);

assign ulpi_rst = 1'b0;

jtag_axi JTAG (
    .aclk(ulpi_clk),
    .aresetn(~ulpi_rst),
    .m_axi_awaddr(ulpi_csr.awaddr),
    .m_axi_awprot(ulpi_csr.awprot),
    .m_axi_awvalid(ulpi_csr.awvalid),
    .m_axi_awready(ulpi_csr.awready),
    .m_axi_wdata(ulpi_csr.wdata),
    .m_axi_wstrb(ulpi_csr.wstrb),
    .m_axi_wvalid(ulpi_csr.wvalid),
    .m_axi_wready(ulpi_csr.wready),
    .m_axi_bresp(ulpi_csr.bresp),
    .m_axi_bvalid(ulpi_csr.bvalid),
    .m_axi_bready(ulpi_csr.bready),
    .m_axi_araddr(ulpi_csr.araddr),
    .m_axi_arprot(ulpi_csr.arprot),
    .m_axi_arvalid(ulpi_csr.arvalid),
    .m_axi_arready(ulpi_csr.arready),
    .m_axi_rdata(ulpi_csr.rdata),
    .m_axi_rresp(ulpi_csr.rresp),
    .m_axi_rvalid(ulpi_csr.rvalid),
    .m_axi_rready(ulpi_csr.rready)
);

endmodule
