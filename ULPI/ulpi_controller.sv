module ulpi_controller (
    ulpi_phy_iface.io       ulpi_phy,
    
    output                  ulpi_clk,
    input                   ulpi_rst,
    
    axi_lite_iface.slave    ulpi_csr,
    
    usb_state_iface.ctl     usb_state
);

ulpi_iface  ulpi();

(* mark_debug = "true" *)logic       dbg_dir;
(* mark_debug = "true" *)logic       dbg_nxt;
(* mark_debug = "true" *)logic       dbg_stp;
(* mark_debug = "true" *)logic [7:0] dbg_tx_data;
(* mark_debug = "true" *)logic [7:0] dbg_rx_data;

assign dbg_dir     = ulpi.dir;
assign dbg_nxt     = ulpi.nxt;
assign dbg_stp     = ulpi.stp;
assign dbg_tx_data = ulpi.tx_data;
assign dbg_rx_data = ulpi.rx_data;

(* mark_debug = "true" *)logic           dbg_awvalid;
(* mark_debug = "true" *)logic           dbg_awready;
(* mark_debug = "true" *)logic [5:0]     dbg_awaddr;
(* mark_debug = "true" *)logic           dbg_wvalid;
(* mark_debug = "true" *)logic           dbg_wready;
(* mark_debug = "true" *)logic [7:0]     dbg_wdata;
(* mark_debug = "true" *)logic           dbg_bvalid;
(* mark_debug = "true" *)logic           dbg_bready;
(* mark_debug = "true" *)logic           dbg_rvalid;
(* mark_debug = "true" *)logic           dbg_rready;
(* mark_debug = "true" *)logic [7:0]     dbg_rdata;
(* mark_debug = "true" *)logic           dbg_arvalid;
(* mark_debug = "true" *)logic           dbg_arready;
(* mark_debug = "true" *)logic [5:0]     dbg_araddr;

assign  dbg_awvalid = ulpi_csr.awvalid;
assign  dbg_awready = ulpi_csr.awready;
assign  dbg_awaddr  = ulpi_csr.awaddr; 
assign  dbg_wvalid  = ulpi_csr.wvalid; 
assign  dbg_wready  = ulpi_csr.wready; 
assign  dbg_wdata   = ulpi_csr.wdata;  
assign  dbg_bvalid  = ulpi_csr.bvalid; 
assign  dbg_bready  = ulpi_csr.bready; 
assign  dbg_rvalid  = ulpi_csr.rvalid; 
assign  dbg_rready  = ulpi_csr.rready; 
assign  dbg_rdata   = ulpi_csr.rdata;  
assign  dbg_arvalid = ulpi_csr.arvalid;
assign  dbg_arready = ulpi_csr.arready;
assign  dbg_araddr  = ulpi_csr.araddr; 

(* mark_debug = "true" *)logic [1:0] dbg_line_state;
(* mark_debug = "true" *)logic [1:0] dbg_vbus_state;
(* mark_debug = "true" *)logic       dbg_rx_active;
(* mark_debug = "true" *)logic       dbg_rx_error;
(* mark_debug = "true" *)logic       dbg_host_disconnect;
(* mark_debug = "true" *)logic       dbg_id;
(* mark_debug = "true" *)logic       dbg_update;

assign dbg_line_state      = usb_state.line_state;    
assign dbg_vbus_state      = usb_state.vbus_state;    
assign dbg_rx_active       = usb_state.rx_active;     
assign dbg_rx_error        = usb_state.rx_error;      
assign dbg_host_disconnect = usb_state.host_disconnect;
assign dbg_id              = usb_state.id;            
assign dbg_update          = usb_state.update;        

ulpi_axis_iface ulpi_rx();
ulpi_axis_iface ulpi_tx();

ulpi_io IO (
    .phy(ulpi_phy),
    
    .clk(ulpi_clk),
    .rst(ulpi_rst),

    .ulpi(ulpi)
);

ulpi_axis AXI (
    .clk(ulpi_clk),
    .rst(ulpi_rst),
    
    .ulpi(ulpi),
    
    .rx(ulpi_rx),
    .tx(ulpi_tx)
);

logic ulpi_is_rx;
assign ulpi_is_rx = ulpi_rx.tvalid;

logic rx_active_down;
logic rx_active_d;
always_ff @(posedge ulpi_clk)
    rx_active_d <= ulpi_rx.tuser[1];
assign rx_active_down = ~ulpi_rx.tuser[1] & rx_active_d;

always_ff @(posedge ulpi_clk) begin
    if (ulpi_rst) begin
        usb_state.line_state <= 2'b00;
        usb_state.vbus_state <= 2'b00;
        usb_state.rx_error <= 1'b0;
        usb_state.host_disconnect <= 1'b0;
        usb_state.id <= 1'b0;        
    end else if (ulpi_rx.tvalid & ulpi_rx.tuser[0]) begin
        usb_state.line_state <= ulpi_rx.tdata[1:0];
        usb_state.vbus_state <= ulpi_rx.tdata[3:2];
        usb_state.rx_error <= (ulpi_rx.tdata[5:4] == 2'b11);
        usb_state.host_disconnect <= (ulpi_rx.tdata[5:4] == 2'b10);
        usb_state.id <= ulpi_rx.tdata[6];
    end
    if ((ulpi_rx.tvalid & ulpi_rx.tuser[0]) | rx_active_down) begin
        usb_state.rx_active <= ulpi_rx.tuser[1];
        usb_state.update <= 1'b1;
    end else
        usb_state.update <= 1'b0;
end

logic           csr_rw;
logic [5:0]     csr_reg;
logic [7:0]     csr_wr_data;
logic [7:0]     csr_rd_data;

enum {S_IDLE, S_WAIT_WRITE, S_WRITE_ADDR, S_WRITE_DATA, S_READ_DATA, S_ABORT, S_RESPONSE} state;

always_ff @(posedge ulpi_clk) begin
    if (ulpi_rst)
        state <= S_IDLE;
    else case (state)
    S_IDLE:
        if (ulpi_csr.awvalid) begin
            state <= S_WAIT_WRITE;
            csr_rw <= 1'b1;
        end else if (ulpi_csr.arvalid) begin
            state <= S_WRITE_ADDR;
            csr_rw <= 1'b0;
        end
        
    S_WAIT_WRITE:
        if (ulpi_csr.wvalid)
            state <= S_WRITE_ADDR;
        
    S_WRITE_ADDR:
        if (ulpi_is_rx)
            state <= S_ABORT;
        else if (ulpi_tx.tready)
            state <= csr_rw ? S_WRITE_DATA : S_READ_DATA;
            
    S_WRITE_DATA:
        if (ulpi_is_rx)
            state <= S_ABORT;
        else if (ulpi_tx.tready)
            state <= S_RESPONSE;
            
    S_READ_DATA:
        if (ulpi_rx.tvalid) begin
            if (~ulpi_rx.tuser[0] | ulpi_rx.tuser[1])
                state <= S_ABORT;
            else
                state <= S_RESPONSE;
        end
        
    S_ABORT:
        if (~ulpi_is_rx)
            state <= S_WRITE_ADDR;
            
    S_RESPONSE:
        if (csr_rw ? ulpi_csr.bready : ulpi_csr.rready) 
            state <= S_IDLE;
    
    endcase
end

always_ff @(posedge ulpi_clk) begin
    if (state == S_IDLE)
        if (ulpi_csr.awvalid)
            csr_reg <= ulpi_csr.awaddr[5:0];
        else if (ulpi_csr.arvalid)
            csr_reg <= ulpi_csr.araddr[5:0];
end

always_ff @(posedge ulpi_clk) 
    if ((state == S_WAIT_WRITE) & ulpi_csr.wvalid)
        csr_wr_data <= ulpi_csr.wdata[7:0];

always_ff @(posedge ulpi_clk) 
    if ((state == S_READ_DATA) & ulpi_rx.tvalid & ulpi_rx.tuser[0] & ~ulpi_rx.tuser[1])
        csr_rd_data <= ulpi_rx.tdata;
        
assign ulpi_csr.awready = (state == S_IDLE);
assign ulpi_csr.arready = (state == S_IDLE) & ~ulpi_csr.awvalid;

assign ulpi_csr.wready = (state == S_WAIT_WRITE);

assign ulpi_csr.bvalid = (state == S_RESPONSE) & csr_rw;

assign ulpi_csr.bresp = 2'b00;

assign ulpi_csr.rvalid = (state == S_RESPONSE) & ~csr_rw;
assign ulpi_csr.rdata = csr_rd_data;
assign ulpi_csr.rresp = 2'b00;

assign ulpi_tx.tvalid = (state == S_WRITE_ADDR) | (state == S_WRITE_DATA);
assign ulpi_tx.tdata = (state == S_WRITE_ADDR) ? {1'b1, ~csr_rw, csr_reg} : csr_wr_data;
assign ulpi_tx.tlast = (state == S_WRITE_DATA);

assign ulpi_rx.tready = 1'b1; // (state == S_READ_DATA)

endmodule
