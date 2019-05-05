module ulpi_ctl(
    input  wire         ulpi_clk,
    (* mark_debug = "true" *)input  wire         ulpi_rst,
    
    (* mark_debug = "true" *)input  wire         ulpi_dir,
    (* mark_debug = "true" *)input  wire         ulpi_nxt,
    (* mark_debug = "true" *)output wire         ulpi_stp,
    (* mark_debug = "true" *)input  wire [7:0]   ulpi_data_in,
    (* mark_debug = "true" *)output wire [7:0]   ulpi_data_out,
    
    (* mark_debug = "true" *)output wire [1:0]   line_state,
    (* mark_debug = "true" *)output wire [1:0]   vbus_state,
    (* mark_debug = "true" *)output wire         rx_active,
    (* mark_debug = "true" *)output wire         rx_error,
    (* mark_debug = "true" *)output wire         host_disconnect,
    
    // ULPI PHY registers port, similar to xilinx's DRP
    (* mark_debug = "true" *)input  wire         reg_en,
    (* mark_debug = "true" *)output wire         reg_rdy,
    (* mark_debug = "true" *)input  wire         reg_we,
    (* mark_debug = "true" *)input  wire [7:0]   reg_addr,
    (* mark_debug = "true" *)input  wire [7:0]   reg_din,
    (* mark_debug = "true" *)output wire [7:0]   reg_dout
);

localparam S_REG_IDLE = 0,
           S_REG_WR_ADDR = 1,
           S_REG_WR_DATA = 2,
           S_REG_RD_DATA_TURN = 3,
           S_REG_RD_DATA = 4,
           S_REG_DONE = 5;

(* mark_debug = "true" *)wire        turnaround;
(* mark_debug = "true" *)wire        rx_cmd;

reg         reg_we_reg;
reg  [7:0]  reg_addr_reg;
reg  [7:0]  reg_din_reg;
reg  [7:0]  reg_dout_reg;
(* mark_debug = "true" *)reg  [2:0]  reg_state;

reg         ulpi_dir_d;
reg         rx_active_reg, rx_error_reg, host_disconnect_reg;
reg [1:0]   line_state_reg;
reg [1:0]   vbus_state_reg;

reg [1:0]   ulpi_stp_reg;
reg [7:0]   ulpi_data_out_reg;

always @(posedge ulpi_clk)
    ulpi_dir_d <= ulpi_dir;
assign turnaround = ulpi_dir_d != ulpi_dir;

assign rx_cmd = ~turnaround & ulpi_dir & ~ulpi_nxt & (reg_state != S_REG_RD_DATA);

always @(posedge ulpi_clk)
    if (ulpi_rst)
        rx_active_reg <= 1'b0;
    else if (turnaround & ~ulpi_dir)
        rx_active_reg <= 1'b0;
    else if (turnaround & ulpi_dir & ulpi_nxt)
        rx_active_reg <= 1'b1;
    else if (rx_cmd)
        rx_active_reg <= ulpi_data_in[4];

always @(posedge ulpi_clk) begin
    if (ulpi_rst) begin
        rx_error_reg <= 1'b0;
        host_disconnect_reg <= 1'b0;
        line_state_reg <= 2'b00;
        vbus_state_reg <= 2'b00;
    end else if (rx_cmd) begin
        rx_error_reg <= (ulpi_data_in[5:4] == 2'b11);
        host_disconnect_reg <= (ulpi_data_in[5:4] == 2'b10);
        line_state_reg <= ulpi_data_in[1:0];
        vbus_state_reg <= ulpi_data_in[3:2];
    end
end

always @(posedge ulpi_clk) begin
    if (ulpi_rst)
        reg_state <= S_REG_IDLE;
    else case (reg_state)
    S_REG_IDLE:
        if (reg_en)
            reg_state <= S_REG_WR_ADDR;
       
    S_REG_WR_ADDR:
        if (~turnaround & ~ulpi_dir & ulpi_nxt) //TODO: & granted
            reg_state <= reg_we_reg ? S_REG_WR_DATA : S_REG_RD_DATA_TURN;
        
    S_REG_WR_DATA:
        if (turnaround)
            reg_state <= S_REG_WR_ADDR;
        else if (ulpi_nxt)
            reg_state <= S_REG_DONE;
    
    S_REG_RD_DATA_TURN:
        if (turnaround & ulpi_dir & ulpi_nxt)
            reg_state <= S_REG_WR_ADDR;
        else if (turnaround & ulpi_dir)
            reg_state <= S_REG_RD_DATA;
            
    S_REG_RD_DATA:
        if (rx_active_reg | ulpi_nxt)
            reg_state <= S_REG_WR_ADDR;
        else 
            reg_state <= S_REG_DONE;     
    
    S_REG_DONE:
        reg_state <= S_REG_IDLE;
    
    endcase
end

always @(posedge ulpi_clk) begin
    if ((reg_state == S_REG_IDLE) & reg_en) begin
        reg_we_reg   <= reg_we;
        reg_addr_reg <= reg_addr;
        reg_din_reg  <= reg_din;
    end        
end

always @(posedge ulpi_clk)
    if ((reg_state == S_REG_RD_DATA) & ~rx_active_reg & ~ulpi_nxt)
        reg_dout_reg <= ulpi_data_in;

always @(posedge ulpi_clk)
    if ((reg_state == S_REG_WR_DATA) & ~turnaround)
        ulpi_stp_reg <= 1'b1;
    else
        ulpi_stp_reg <= 1'b0; 

always @(*) begin
    if (reg_state == S_REG_WR_ADDR)
        ulpi_data_out_reg <= {reg_we_reg ? 2'b10 : 2'b11, reg_addr_reg[5:0]};
    else if (reg_state == S_REG_WR_DATA)
        ulpi_data_out_reg <= reg_din_reg;
    else
        ulpi_data_out_reg <= 8'h00;
end

assign line_state = line_state_reg;
assign rx_active = rx_active_reg;
assign rx_error = rx_error_reg;
assign host_disconnect = host_disconnect_reg;
assign vbus_state = vbus_state_reg;

assign reg_rdy = (reg_state == S_REG_DONE);
assign reg_dout = reg_dout_reg;

assign ulpi_stp = ulpi_stp_reg;

assign ulpi_data_out = ulpi_data_out_reg;

endmodule
