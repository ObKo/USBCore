`timescale 1ns / 1ps

module usb_state_controller (
    input wire      clk,
    input wire      rst,
    
    usb_control_iface.dst   control,
    
    ulpi_state_iface.dst    ulpi_state,
    axi_lite_iface.master   ulpi_csr
);

enum {S_IDLE, S_CONNECT_WR_OTG, S_CONNECT_WR_FUNC, S_CONNECTED, S_DISCONNECT_WR_FUNC} state;
enum {S_AXI_IDLE, S_AXI_WR_ADDR, S_AXI_WR_DATA, S_AXI_WR_WAIT, S_AXI_DONE} ulpi_axi_state;

always_ff @(posedge clk) begin
    if (rst)
        state <= S_IDLE;
    else case (state)
        S_IDLE:
            if (control.connected)
                state <= S_CONNECT_WR_OTG;
        
        S_CONNECT_WR_OTG:
            if (ulpi_axi_state == S_AXI_DONE)
                state <= S_CONNECT_WR_FUNC;
                
        S_CONNECT_WR_FUNC:
            if (ulpi_axi_state == S_AXI_DONE)
                state <= S_CONNECTED;
        
        S_CONNECTED:
            if (~control.connected)
                state <= S_DISCONNECT_WR_FUNC;
            
        S_DISCONNECT_WR_FUNC:
            if (ulpi_axi_state == S_AXI_DONE)
                state <= S_IDLE;

    endcase
end

logic       axi_wr_start;
logic [5:0] axi_wr_addr;
logic [7:0] axi_wr_data;

always_comb begin
    case(state)
    S_CONNECT_WR_OTG:       begin axi_wr_start <= 1'b1; axi_wr_addr <= 6'h0A; axi_wr_data <= 8'h04; end
    S_CONNECT_WR_FUNC:      begin axi_wr_start <= 1'b1; axi_wr_addr <= 6'h04; axi_wr_data <= 8'h45; end
    S_DISCONNECT_WR_FUNC:   begin axi_wr_start <= 1'b1; axi_wr_addr <= 6'h04; axi_wr_data <= 8'h49; end
    default                 begin axi_wr_start <= 1'b0; axi_wr_addr <= 6'h00; axi_wr_data <= 8'h00; end
    endcase
end

always_ff @(posedge clk) begin
    if (rst)
        ulpi_axi_state <= S_AXI_IDLE;
    else case (ulpi_axi_state)
        S_AXI_IDLE:
            if (axi_wr_start)
                ulpi_axi_state <= S_AXI_WR_ADDR;
        
        S_AXI_WR_ADDR:
            if (ulpi_csr.awready)
                ulpi_axi_state <= S_AXI_WR_DATA;
        
        S_AXI_WR_DATA:
            if (ulpi_csr.wready)
                ulpi_axi_state <= S_AXI_WR_WAIT;
            
        S_AXI_WR_WAIT:
            if (ulpi_csr.bvalid)
                ulpi_axi_state <= S_AXI_DONE;
            
        S_AXI_DONE: 
            ulpi_axi_state <= S_AXI_IDLE;
    endcase
end

assign ulpi_csr.awvalid = (ulpi_axi_state == S_AXI_WR_ADDR);
assign ulpi_csr.awaddr = {'0, axi_wr_addr};
assign ulpi_csr.awprot = '0;

assign ulpi_csr.arvalid = 1'b0;
assign ulpi_csr.araddr = '0;
assign ulpi_csr.arprot = '0;

assign ulpi_csr.wvalid = (ulpi_axi_state == S_AXI_WR_DATA);
assign ulpi_csr.wdata = axi_wr_data;
assign ulpi_csr.wstrb = {'0, 1'b1};

assign ulpi_csr.bready = (ulpi_axi_state == S_AXI_WR_WAIT);

assign ulpi_csr.rready = 1'b1;

endmodule
