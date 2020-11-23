module usb_xfer (
    input  wire         clk,
    input  wire         rst,

    (* mark_debug = "true" *)input  wire         rx_in,
    (* mark_debug = "true" *)input  wire         rx_out,
    (* mark_debug = "true" *)input  wire         rx_setup,
    (* mark_debug = "true" *)input  wire [6:0]   rx_addr,
    (* mark_debug = "true" *)input  wire [3:0]   rx_endpoint,
    
    (* mark_debug = "true" *)input  wire         rx_handshake,
    // 0 - ACK, 1 - NACK, 2 - NYET, 3 - STALL
    (* mark_debug = "true" *)input  wire [1:0]   rx_handshake_type,
    
    (* mark_debug = "true" *)input  wire         rx_data,
    // 0 - DATA0, 1 - DATA1, 2 - DATA2, 3 - MDATA
    (* mark_debug = "true" *)input  wire [1:0]   rx_data_type,
    
    (* mark_debug = "true" *)input  wire [7:0]   rx_data_tdata,
    (* mark_debug = "true" *)input  wire         rx_data_tlast,
    (* mark_debug = "true" *)input  wire         rx_data_error,
    (* mark_debug = "true" *)input  wire         rx_data_tvalid,
    (* mark_debug = "true" *)output reg          rx_data_tready,
    
    (* mark_debug = "true" *)input  wire         tx_ready,
    
    (* mark_debug = "true" *)output reg          tx_handshake,
    // 0 - ACK, 1 - NACK, 2 - NYET, 3 - STALL
    (* mark_debug = "true" *)output reg  [1:0]   tx_handshake_type,
    
    (* mark_debug = "true" *)output wire         tx_data,
    (* mark_debug = "true" *)output wire         tx_data_null,
    // 0 - DATA0, 1 - DATA1, 2 - DATA2, 3 - MDATA
    (* mark_debug = "true" *)output reg  [1:0]   tx_data_type,
    
    (* mark_debug = "true" *)output wire [7:0]   tx_data_tdata,
    (* mark_debug = "true" *)output wire         tx_data_tlast,
    (* mark_debug = "true" *)output wire         tx_data_tvalid,
    (* mark_debug = "true" *)input  wire         tx_data_tready,
    
    (* mark_debug = "true" *)output reg  [3:0]   ctl_endpoint,
    (* mark_debug = "true" *)output reg  [7:0]   ctl_request_type,
    (* mark_debug = "true" *)output reg  [7:0]   ctl_request,
    (* mark_debug = "true" *)output reg  [15:0]  ctl_value,
    (* mark_debug = "true" *)output reg  [15:0]  ctl_index,
    (* mark_debug = "true" *)output reg  [15:0]  ctl_length,
    (* mark_debug = "true" *)output wire         ctl_req,
    (* mark_debug = "true" *)input  wire         ctl_ack,
    
    output wire [7:0]   xfer_rx_tdata,
    output wire         xfer_rx_tlast,
    output wire         xfer_rx_error,
    output wire         xfer_rx_tvalid,
    input  wire         xfer_rx_tready,
   
    input  wire [7:0]   xfer_tx_tdata,
    input  wire         xfer_tx_tlast,
    input  wire         xfer_tx_tvalid,
    output wire         xfer_tx_tready
);

localparam S_IDLE = 0, S_CTL_SETUP_DATA = 2, S_CTL_REQ = 3, S_CTL_SETUP_ACK = 4,
           S_CTL_DATA_TOKEN = 5, S_CTL_DATA_START = 6, S_CTL_DATA = 7, S_CTL_DATA_ACK = 8,
           S_CTL_STATUS_TOKEN = 9, S_CTL_STATUS_DATA_START = 10, S_CTL_STATUS_DATA = 11, 
           S_CTL_STATUS_ACK = 12;

reg  [3:0]  state;
wire        rx_data_strobe;
reg  [15:0] rx_data_counter;
wire        ctl_request_in;
reg  [15:0] tx_data_counter;
reg  [3:0]  xfer_ack_timeout;
reg         xfer_nack;

assign ctl_request_in = ctl_request_type[7];
assign rx_data_strobe = rx_data_tvalid & rx_data_tready;

always @(posedge clk)
    if (state != S_CTL_REQ)
        xfer_ack_timeout <= 4'hF;
    else
        xfer_ack_timeout <= xfer_ack_timeout - 1;

always @(posedge clk)
    if (state == S_IDLE)
        xfer_nack <= 1'b0;
    else if ((state == S_CTL_REQ) & (xfer_ack_timeout == 4'h0))
        xfer_nack <= 1'b1;

always @(posedge clk) begin
    if (rst)
        state <= S_IDLE;
    else case (state)
    S_IDLE:
        if (rx_setup)
            state <= S_CTL_SETUP_DATA;
            
    S_CTL_SETUP_DATA:
        if (rx_data_strobe & rx_data_tlast & ~rx_data_error)
            state <= S_CTL_REQ;
            
    S_CTL_REQ:
        if (ctl_ack | (xfer_ack_timeout == 4'h0))
            state <= S_CTL_SETUP_ACK;
   
    S_CTL_SETUP_ACK:
        if (tx_ready) begin
            if (xfer_nack)
                state <= S_IDLE;
            else if (ctl_length != 16'h0000)
                state <= S_CTL_DATA_TOKEN;
            else 
                state <= S_CTL_STATUS_TOKEN;
        end
            
    S_CTL_DATA_TOKEN:
        if (rx_in)
            state <= S_CTL_DATA_START;
        else if (rx_out)
            state <= S_CTL_DATA;
    
    S_CTL_DATA_START:
        if (tx_ready)
            state <= S_CTL_DATA;
    
    S_CTL_DATA:
        if (ctl_request_in & tx_data_tvalid & tx_data_tready & tx_data_tlast)
            state <= S_CTL_DATA_ACK;
        else if (~ctl_request_in & rx_data_tvalid & rx_data_tready & rx_data_tlast)
            state <= S_CTL_DATA_ACK;
    
    S_CTL_DATA_ACK:
        if (ctl_request_in ? (rx_handshake & (rx_handshake_type == 2'b00)) : tx_ready)
            state <= S_CTL_STATUS_TOKEN;
    
    S_CTL_STATUS_TOKEN:
        if (rx_out)
            state <= S_CTL_STATUS_DATA;
        else if (rx_in)
            state <= S_CTL_STATUS_DATA_START;
    
    S_CTL_STATUS_DATA_START:
        if (tx_ready)
            state <= S_CTL_STATUS_ACK;
            
    S_CTL_STATUS_DATA:
        if (ctl_request_in ? rx_data : tx_ready)
            state <= S_CTL_STATUS_ACK;

    S_CTL_STATUS_ACK:
        if (ctl_request_in ? tx_ready : (rx_handshake & (rx_handshake_type == 2'b00)))
            state <= S_IDLE;
        
    endcase
end

always @(posedge clk)
    if (rst)
        rx_data_counter <= 16'h0000;
    else if ((state == S_IDLE) | (state == S_CTL_SETUP_ACK))
        rx_data_counter <= 16'h0000;
    else if (rx_data_tvalid & rx_data_tready)
        rx_data_counter <= rx_data_counter + 1;        

always @(posedge clk)
    if (rst)
        tx_data_counter <= 16'h0000;
    else if (state == S_CTL_SETUP_ACK)
        tx_data_counter <= 16'h0000;
    else if (tx_data_tvalid & tx_data_tready)
        tx_data_counter <= tx_data_counter + 1;  
        
always @(*) begin
    case (state)
    S_CTL_SETUP_DATA:   rx_data_tready = 1'b1;
    S_CTL_DATA:         rx_data_tready = ctl_request_in ? 1'b0 : xfer_rx_tready;
    S_CTL_STATUS_DATA:  rx_data_tready = ctl_request_in ? 1'b1 : 1'b0;
    default:            rx_data_tready = 1'b0;
    endcase
end

always @(*) begin
    case (state)
    S_CTL_SETUP_ACK:    tx_handshake = 1'b1;
    S_CTL_DATA_ACK:     tx_handshake = ctl_request_in ? 1'b0 : 1'b1;
    S_CTL_STATUS_ACK:   tx_handshake = ctl_request_in ? 1'b1 : 1'b0;
    default:            tx_handshake = 1'b0;
    endcase
end

always @(*) begin
    case (state)
    S_CTL_SETUP_ACK:    tx_handshake_type = xfer_nack ? 2'b01 : 2'b00;
    default:            tx_handshake_type = 2'b00;
    endcase
end

assign tx_data = (state == S_CTL_DATA_START) | (state == S_CTL_STATUS_DATA_START);
assign tx_data_null = (state == S_CTL_STATUS_DATA_START);

always @(posedge clk)
    if (state == S_CTL_SETUP_ACK)
        tx_data_type <= 2'b01;
    else if (tx_data_tvalid & tx_data_tready & tx_data_tlast)
        tx_data_type[0] <= ~tx_data_type[0];

assign tx_data_tdata = xfer_tx_tdata;
assign tx_data_tlast = xfer_tx_tlast | (tx_data_counter[5:0] == 6'b111111);
assign tx_data_tvalid = (state == S_CTL_DATA) & ctl_request_in & xfer_tx_tvalid;

assign ctl_req = (state == S_CTL_REQ);

always @(posedge clk) begin
    if ((state == S_IDLE) & rx_setup)
        ctl_endpoint <= rx_endpoint;
        
    if ((state == S_CTL_SETUP_DATA) & rx_data_strobe) begin
        case (rx_data_counter)
        9'h000: ctl_request_type <= rx_data_tdata;
        9'h001: ctl_request <= rx_data_tdata;
        9'h002: ctl_value[7:0] <= rx_data_tdata;
        9'h003: ctl_value[15:8] <= rx_data_tdata;
        9'h004: ctl_index[7:0] <= rx_data_tdata;
        9'h005: ctl_index[15:8] <= rx_data_tdata;
        9'h006: ctl_length[7:0] <= rx_data_tdata;
        9'h007: ctl_length[15:8] <= rx_data_tdata;
        endcase
    end
end

assign xfer_rx_tdata = rx_data_tdata;
assign xfer_rx_error = rx_data_error;
assign xfer_rx_tlast = rx_data_counter == (ctl_length - 1);
assign xfer_rx_tvalid = (state == S_CTL_DATA) & ~ctl_request_in & rx_data_tvalid;

assign xfer_tx_tready = ((state == S_CTL_DATA) & ctl_request_in) ? tx_data_tready : 1'b0;

endmodule
