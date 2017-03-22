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

interface axi_stream_iface;
    logic       tvalid;
    logic       tready;
    logic [7:0] tdata;
    logic       tlast;
        
    modport master (
        input  tready,
        output tvalid, tdata, tlast
    );
    modport slave (
        output tready,
        input  tvalid, tdata, tlast
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

interface ulpi_state_iface;
    logic [1:0] line_state;
    logic [1:0] vbus_state;
    logic       rx_active;
    logic       rx_error;
    logic       host_disconnect;
    logic       id;
    logic       update;
    
    modport ctl (
        output line_state, vbus_state, rx_active, rx_error, host_disconnect,
               id, update
    );
    modport dst (
        input  line_state, vbus_state, rx_active, rx_error, host_disconnect,
               id, update
    );
endinterface

interface usb_control_iface;
    logic       connected;
    
    modport src (
        output connected
    );
    modport dst (
        input  connected
    );
endinterface
