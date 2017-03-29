module ulpi_controller (
    ulpi_phy_iface.io           ulpi_phy,
    
    output                      ulpi_clk,
    input                       ulpi_rst,
    
    axi_lite_iface.slave        ulpi_csr,
    
    ulpi_state_iface.ctl        usb_state,
    axi_stream_iface.master     rx,
    axi_stream_iface.slave      tx
);

ulpi_iface  ulpi();

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

logic ulpi_tx_busy;
logic ulpi_grab_tx;

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
        if (~ulpi_tx_busy) begin
            if (ulpi_csr.awvalid) begin
                state <= S_WAIT_WRITE;
                csr_rw <= 1'b1;
            end else if (ulpi_csr.arvalid) begin
                state <= S_WRITE_ADDR;
                csr_rw <= 1'b0;
            end
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

assign ulpi_grab_tx = (state != S_IDLE);

always_ff @(posedge ulpi_clk)
    if (ulpi_rst)
        ulpi_tx_busy <= 1'b0;
    else if (tx.tvalid & tx.tready & tx.tlast) 
        ulpi_tx_busy <= 1'b0;
    else if (tx.tvalid & ~ulpi_grab_tx)
        ulpi_tx_busy <= 1'b1;

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
        
assign ulpi_csr.awready = (state == S_IDLE) & ~ulpi_tx_busy;
assign ulpi_csr.arready = (state == S_IDLE) & ~ulpi_csr.awvalid & ~ulpi_tx_busy;

assign ulpi_csr.wready = (state == S_WAIT_WRITE);

assign ulpi_csr.bvalid = (state == S_RESPONSE) & csr_rw;

assign ulpi_csr.bresp = 2'b00;

assign ulpi_csr.rvalid = (state == S_RESPONSE) & ~csr_rw;
assign ulpi_csr.rdata = csr_rd_data;
assign ulpi_csr.rresp = 2'b00;

assign ulpi_tx.tvalid = ulpi_grab_tx ? ((state == S_WRITE_ADDR) | (state == S_WRITE_DATA)) : tx.tvalid;
assign ulpi_tx.tdata = ulpi_grab_tx ? ((state == S_WRITE_ADDR) ? {1'b1, ~csr_rw, csr_reg} : csr_wr_data) : tx.tdata;
assign ulpi_tx.tlast = ulpi_grab_tx ? (state == S_WRITE_DATA) : tx.tlast;
assign tx.tready = ulpi_grab_tx ? 1'b0 : ulpi_tx.tready;

assign ulpi_rx.tready = 1'b1; // (state == S_READ_DATA)

logic [7:0] rx_reg;
logic       rx_reg_ce;
logic       rx_reg_valid;
logic       rx_reg_last;

assign rx_reg_ce = ulpi_rx.tvalid & (ulpi_rx.tuser == 2'b10);
assign rx_reg_last = ~ulpi_rx.tuser[1];

always_ff @(posedge ulpi_clk)
    if (rx_reg_ce)
        rx_reg <= ulpi_rx.tdata;
        
always_ff @(posedge ulpi_clk)
    if (ulpi_rst)
        rx_reg_valid <= 1'b0;
    else if (~rx_reg_valid & rx_reg_ce)
        rx_reg_valid <= 1'b1;
    else if (rx_reg_valid & rx_reg_last)
        rx_reg_valid <= 1'b0;

assign rx.tdata = rx_reg;
assign rx.tvalid = rx_reg_valid & (rx_reg_ce | rx_reg_last);
assign rx.tlast = rx_reg_valid & rx_reg_last;

endmodule
