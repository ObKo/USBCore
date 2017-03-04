interface ulpi_phy_iface;
    logic       clk;
    logic       rst;
    logic       dir;
    logic       nxt;
    logic       stp;
    logic [7:0] data;
    
    modport io (
        input  clk, dir, nxt,
        output rst, stp,
        inout  data
    );
endinterface

interface ulpi_iface;
    logic       dir;
    logic       nxt;
    logic       stp;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    
    modport io (
        output dir, nxt, rx_data,
        input  stp, tx_data
    );
    modport dst (
        input  dir, nxt, rx_data,
        output stp, tx_data
    );
endinterface

interface ulpi_axis_iface;
    logic       tvalid;
    logic       tready;
    logic [7:0] tdata;
    logic       tlast;
    logic [1:0] tuser;
        
    modport tx_master (
        input  tready,
        output tvalid, tdata, tlast
    );
    modport tx_slave (
        output tready,
        input  tvalid, tdata, tlast
    );
    modport rx_master (
        input  tready,
        output tvalid, tdata, tuser
    );
    modport rx_slave (
        output tready,
        input  tvalid, tdata, tuser
    );
endinterface

interface axi_lite_iface;
    logic           awvalid;
    logic           awready;
    logic [31:0]    awaddr;
    logic [2:0]     awprot;
    
    logic           wvalid;
    logic           wready;
    logic [31:0]    wdata;
    logic [3:0]     wstrb;
    
    logic           bvalid;
    logic           bready;
    logic [1:0]     bresp;
            
    logic           rvalid;
    logic           rready;
    logic [31:0]    rdata;
    logic [1:0]     rresp;

    logic           arvalid;
    logic           arready;
    logic [31:0]    araddr;
    logic [2:0]     arprot;
    
    modport master (
        input  awready, arready,
               wready, bvalid, bresp,
               rvalid, rdata, rresp,
        output awvalid, awaddr, awprot, 
               arvalid, araddr, arprot,
               wvalid, wdata, wstrb, bready,
               rready
    );
   
    modport slave (
       output awready, arready,
              wready, bvalid, bresp,
              rvalid, rdata, rresp,
       input  awvalid, awaddr, awprot, 
              arvalid, araddr, arprot,
              wvalid, wdata, wstrb, bready,
              rready
    );
endinterface
