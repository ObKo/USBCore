module usb_state_ctl (
    input  wire         clk,
    input  wire         rst,
    
    input  wire         usb_enable,
    output reg          usb_reset,
    
    input  wire [1:0]   line_state,
  
    output wire         reg_en,
    input  wire         reg_rdy,
    output wire         reg_we,
    output reg  [7:0]   reg_addr,
    output reg  [7:0]   reg_din,
    input  wire [7:0]   reg_dout
);

localparam S_DISCONNECTED = 0,
           S_WR_OTG_CTL = 1,
           S_WR_FUNCT_CTL = 2,
           S_RESET = 3,
           S_IDLE = 4;
           
localparam S_REG_IDLE = 0,
           S_REG_WR = 1,
           S_REG_WAIT = 2,
           S_REG_DONE = 3;
           
reg  [2:0]      state;
reg  [1:0]      reg_state;
reg             enabling;
reg  [7:0]      reset_counter;

always @(posedge clk) begin
    if (rst)
        state <= S_DISCONNECTED;
    else if (((state == S_RESET) | (state == S_IDLE)) & ~usb_enable) 
        state <= S_WR_OTG_CTL;
    else case (state)
    S_DISCONNECTED:
        if (usb_enable)
            state <= S_WR_OTG_CTL;
            
    S_RESET:
        if (line_state == 2'b01)
            state <= S_IDLE;
            
    S_IDLE:
        if (reset_counter >= 8'd150) // 2.5us
            state <= S_RESET;
        
    S_WR_OTG_CTL:
        if (reg_state == S_REG_DONE)
            state <= S_WR_FUNCT_CTL;
       
    S_WR_FUNCT_CTL:
        if (reg_state == S_REG_DONE)
            state <= enabling ? S_RESET : S_DISCONNECTED;
    endcase  
end

always @(posedge clk)
    if (rst)
        reset_counter <= 8'h00;
    else if ((state != S_IDLE) || (line_state != 2'b00))
        reset_counter <= 8'h00;
    else
        reset_counter <= reset_counter + 1;

always @(posedge clk)
    if (rst)
        usb_reset <= 1'b1;
    else if (state != S_IDLE)
        usb_reset <= 1'b1;
    else
        usb_reset <= 1'b0;

always @(posedge clk) 
    if (usb_enable & (state == S_DISCONNECTED))
        enabling <= 1'b1;
    else if (~usb_enable & ((state == S_RESET) | (state == S_IDLE)))
        enabling <= 1'b0;

always @(posedge clk) begin
    if (rst)
        reg_state <= S_REG_IDLE;
    else case (reg_state)
    S_REG_IDLE:
        if ((state == S_WR_OTG_CTL) | (state == S_WR_FUNCT_CTL))
            reg_state <= S_REG_WR;
            
    S_REG_WR:
        reg_state <= S_REG_WAIT;
            
    S_REG_WAIT:
        if (reg_rdy)
            reg_state <= S_REG_DONE;
        
    S_REG_DONE:
        reg_state <= S_REG_IDLE;
    endcase  
end


assign reg_en = (reg_state == S_REG_WR);
assign reg_we = (reg_state == S_REG_WR);

always @(*) begin
    if (state == S_WR_OTG_CTL)
        reg_addr <= 8'h0A;
    else if (state == S_WR_FUNCT_CTL)
        reg_addr <= 8'h04;
    else
        reg_addr <= 8'h00;
end

always @(*) begin
    if (state == S_WR_OTG_CTL)
        reg_din <= 8'h00;
    else if (state == S_WR_FUNCT_CTL)
        reg_din <= enabling ? 8'h45 : 8'h49;
    else
        reg_din <= 8'h00;
end

endmodule
