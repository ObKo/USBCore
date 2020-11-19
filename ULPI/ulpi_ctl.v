module ulpi_ctl(
    input  wire         ulpi_clk,
    input  wire         ulpi_rst,
    
    input  wire         ulpi_dir,
    input  wire         ulpi_nxt,
    output reg          ulpi_stp,
    input  wire [7:0]   ulpi_data_in,
    output reg  [7:0]   ulpi_data_out,
    
    output reg  [1:0]   line_state,
    output reg  [1:0]   vbus_state,
    output reg          rx_active,
    output reg          rx_error,
    output reg          host_disconnect,
    
    // ULPI PHY registers port, similar to xilinx's DRP
    input  wire         reg_en,
    output reg          reg_rdy,
    input  wire         reg_we,
    input  wire [7:0]   reg_addr,
    input  wire [7:0]   reg_din,
    output reg  [7:0]   reg_dout,
    
    output reg  [7:0]   axis_rx_tdata,
    output reg          axis_rx_tlast,
    output reg          axis_rx_error,
    output reg          axis_rx_tvalid,
    input  wire         axis_rx_tready
);

localparam S_RESET = 0,
           S_TX_IDLE = 1,
           S_RX_DATA = 2,
           S_RX_CMD = 3,
           S_RX_ERROR = 4,
           S_RX_ERROR_WAIT = 5,
           S_REG_ADDR = 6,
           S_REG_EXT_ADDR = 7,
           S_REG_READ = 8,
           S_REG_WRITE = 9,
           S_REG_STP = 10;

reg  [3:0]  state;
wire        trn;
wire        rx_cmd;
wire [1:0]  rx_cmd_line_state;
wire [1:0]  rx_cmd_vbus_state;
wire        rx_cmd_rx_active;
wire        rx_cmd_rx_error;
wire        rx_is_error;
wire        rx_cmd_host_disconnect;
wire        rx_active_start, rx_active_end;

reg         csr_need_op;
reg         csr_write;
reg         csr_extended;
reg [7:0]   csr_address;
reg [7:0]   csr_data;

reg dir_prev;
always @(posedge ulpi_clk)
    dir_prev <= ulpi_dir;

assign trn = ulpi_dir != dir_prev;
assign rx_cmd = ulpi_dir & ~trn & ~ulpi_nxt & (state != S_REG_READ);
assign rx_cmd_line_state = ulpi_data_in[1:0];
assign rx_cmd_vbus_state = ulpi_data_in[3:2];
assign rx_cmd_rx_active = ulpi_data_in[4];
assign rx_cmd_rx_error = (ulpi_data_in[5:4] == 2'b11);
assign rx_cmd_host_disconnect = (ulpi_data_in[5:4] == 2'b10);

always @(posedge ulpi_clk) begin
    if (ulpi_rst)
        state <= S_RESET;
    else if (((state == S_TX_IDLE) | (state == S_REG_ADDR) | (state == S_REG_EXT_ADDR) | 
              (state == S_REG_WRITE) | (state == S_REG_STP)) & ulpi_dir) begin
        if (trn & ulpi_nxt)
            state <= S_RX_DATA;
        else
            state <= S_RX_CMD;
    end else case (state)
    S_RESET:
        if (ulpi_dir)
            state <= S_TX_IDLE;
    
    S_TX_IDLE:
        if (csr_need_op)
            state <= S_REG_ADDR;
    
    S_RX_DATA:
        // TODO: handle stp
        if (~ulpi_dir)
            state <= S_TX_IDLE;
        else if (rx_is_error)
            state <= S_RX_ERROR;
        else if (rx_cmd & ~rx_cmd_rx_active)
            state <= S_RX_CMD;
        
    S_RX_CMD:
        if (~ulpi_dir)
            state <= S_TX_IDLE;
        else if (rx_is_error)
            state <= S_RX_ERROR;
        else if (rx_cmd & rx_cmd_rx_active)
            state <= S_RX_DATA;
            
    S_RX_ERROR:
        state <= S_RX_ERROR_WAIT;
            
    S_RX_ERROR_WAIT:
        if (axis_rx_tlast & axis_rx_tvalid & axis_rx_tready)
            state <= S_RX_CMD;
        
    S_REG_ADDR:
        if (ulpi_nxt & csr_extended)
            state <= S_REG_EXT_ADDR;
        else if (ulpi_nxt)
            state <= csr_write ? S_REG_WRITE : S_REG_READ;
    
    S_REG_EXT_ADDR:
        if (ulpi_nxt)
            state <= csr_write ? S_REG_WRITE : S_REG_READ;
            
    S_REG_WRITE:
        if (ulpi_nxt)
            state <= S_REG_STP;
            
    S_REG_STP:
        state <= S_TX_IDLE;
        
    S_REG_READ:
        if (ulpi_dir & trn & ulpi_nxt)
            state <= S_RX_DATA;
        else if (ulpi_dir & ~trn)
            state <= S_RX_CMD;           
        
    endcase
end

always @(posedge ulpi_clk) begin
    if (ulpi_rst) begin
        line_state <= 2'b00;
        vbus_state <= 2'b00;
        rx_error <= 1'b0;
        host_disconnect <= 1'b0;
    end else if (rx_cmd) begin
        line_state <= rx_cmd_line_state;
        vbus_state <= rx_cmd_vbus_state;
        rx_error <= rx_cmd_rx_error;
        host_disconnect <= rx_cmd_host_disconnect;
    end
end

assign rx_active_start = ~rx_active & (ulpi_dir & trn & ulpi_nxt | (rx_cmd & rx_cmd_rx_active));
assign rx_active_end = rx_active & (~ulpi_dir | (rx_cmd & ~rx_cmd_rx_active));
always @(posedge ulpi_clk)
    if (ulpi_rst) 
        rx_active <= 1'b0;
    else if (rx_active_end)
        rx_active <= 1'b0;
    else if (rx_active_start)
        rx_active <= 1'b1;

wire csr_done;
assign csr_done = csr_write ? (state == S_REG_STP) : ((state == S_REG_READ) & ulpi_dir & ~trn);

always @(posedge ulpi_clk) begin
    if (ulpi_rst) 
        csr_need_op <= 1'b0;
    else if (csr_need_op & csr_done)
        csr_need_op <= 1'b0;
    else if (csr_need_op & csr_done)
        csr_need_op <= 1'b0;
    else if (reg_en & ~csr_need_op) begin
        csr_need_op <= 1'b1;
        csr_write <= reg_we;
        csr_address <= reg_addr;
        csr_extended <= (reg_addr[7:6] != 2'b00);
        if (reg_we)
            csr_data <= reg_din;
    end
end

always @(posedge ulpi_clk) begin
    if (ulpi_rst) 
        reg_rdy <= 1'b0;
    else if (csr_need_op & csr_done) begin
        reg_rdy <= 1'b1;
        if (~csr_write)
            reg_dout <= ulpi_data_in;
    end else
        reg_rdy <= 1'b0;
end

reg [7:0]   axis_buffer;
reg         axis_buffer_valid;
always @(posedge ulpi_clk)
    if (rx_active & ulpi_nxt)
        axis_buffer <= ulpi_data_in;
        
always @(posedge ulpi_clk)
    if (ulpi_rst)
        axis_buffer_valid <= 1'b0;
    else if (rx_active_end)
        axis_buffer_valid <= 1'b0;
    else if ((state == S_RX_DATA) & rx_active & ulpi_nxt)
        axis_buffer_valid <= 1'b1;
        
wire ulpi_data_valid;
assign ulpi_data_valid = (state == S_RX_DATA) & (rx_active & ulpi_nxt | rx_active_end);

always @(posedge ulpi_clk) begin
    if (ulpi_rst)  begin
        axis_rx_tvalid <= 1'b0;
        axis_rx_tlast <= 1'b0;
        axis_rx_error <= 1'b0;
    end else if ((state == S_RX_ERROR_WAIT) & ~axis_rx_tvalid) begin
        axis_rx_tvalid <= 1'b1;
        axis_rx_tlast <= 1'b1;
        axis_rx_error <= 1'b1;
    end else if (axis_buffer_valid & ulpi_data_valid) begin
        axis_rx_tvalid <= 1'b1;
        axis_rx_tdata <= axis_buffer;
        axis_rx_tlast <= rx_active_end;
        axis_rx_error <= 1'b0;
    end else if (axis_rx_tvalid & axis_rx_tready) begin
        axis_rx_tvalid <= 1'b0;
    end
end
assign rx_is_error = rx_cmd & rx_cmd_rx_error | axis_rx_tvalid & ~axis_rx_tready & ulpi_data_valid;

always @(*) begin
    if (((state == S_TX_IDLE) & csr_need_op) | (state == S_REG_ADDR))
        ulpi_data_out = {(csr_write ? 2'b10 : 2'b11), (csr_extended ? 6'b101111 : csr_address[5:0])};
    else if (state == S_REG_EXT_ADDR)
        ulpi_data_out = csr_address;
    else if (state == S_REG_WRITE) 
        ulpi_data_out = csr_data;
    else
        ulpi_data_out = 8'h00;
end

always @(*) begin
    if (state == S_REG_STP)
        ulpi_stp = 1'b1;
    else if (state == S_RX_ERROR)
        ulpi_stp = 1'b1;
    else
        ulpi_stp = 1'b0;
end

endmodule
