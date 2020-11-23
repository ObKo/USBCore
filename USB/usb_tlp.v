module usb_tlp (
    input  wire         clk,
    input  wire         rst,
    
    output reg          rx_out,
    output reg          rx_in,
    output reg          rx_setup,
    output reg          rx_sof,
    
    output reg  [6:0]   rx_addr,
    output reg  [3:0]   rx_endpoint,
    output reg  [10:0]  rx_frame_number,
    
    output reg          rx_handshake,
    // 0 - ACK, 1 - NACK, 2 - NYET, 3 - STALL
    output reg  [1:0]   rx_handshake_type,
    
    output reg          rx_data,
    // 0 - DATA0, 1 - DATA1, 2 - DATA2, 3 - MDATA
    output reg  [1:0]   rx_data_type,
    
    output wire [7:0]   rx_data_tdata,
    output wire         rx_data_tlast,
    output wire         rx_data_error,
    output wire         rx_data_tvalid,
    input  wire         rx_data_tready,
    
    output wire         tx_ready,
    
    input  wire         tx_handshake,
    // 0 - ACK, 1 - NACK, 2 - NYET, 3 - STALL
    input  wire [1:0]   tx_handshake_type,
    
    input  wire         tx_data,
    input  wire         tx_data_null,
    // 0 - DATA0, 1 - DATA1, 2 - DATA2, 3 - MDATA
    input  wire [1:0]   tx_data_type,
    
    input  wire [7:0]   tx_data_tdata,
    input  wire         tx_data_tlast,
    input  wire         tx_data_tvalid,
    output wire         tx_data_tready,
    
    input  wire [7:0]   axis_rx_tdata,
    input  wire         axis_rx_tlast,
    input  wire         axis_rx_error,
    input  wire         axis_rx_tvalid,
    output wire         axis_rx_tready,
    
    output reg  [7:0]   axis_tx_tdata,
    output reg          axis_tx_tlast,
    output reg          axis_tx_tvalid,
    input  wire         axis_tx_tready
);

function [4:0] crc5;
    input [10:0] data;
begin
    crc5[4] = ~(1'b1 ^ data[10] ^ data[7] ^ data[5] ^ data[4] ^ data[1] ^ data[0]);
    crc5[3] = ~(1'b1 ^ data[9]  ^ data[6] ^ data[4] ^ data[3] ^ data[0]);
    crc5[2] = ~(1'b1 ^ data[10] ^ data[8] ^ data[7] ^ data[4] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
    crc5[1] = ~(1'b0 ^ data[9]  ^ data[7] ^ data[6] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
    crc5[0] = ~(1'b1 ^ data[8]  ^ data[6] ^ data[5] ^ data[2] ^ data[1] ^ data[0]);
end endfunction

function [15:0] crc16;
    input [7:0]  d;
    input [15:0] c;
begin
	crc16[0] = (c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[7] ^ c[8] ^ d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7]);
	crc16[1] = (c[9]);
	crc16[2] = (c[10]);
	crc16[3] = (c[11]);
	crc16[4] = (c[12]);
	crc16[5] = (c[13]);
	crc16[6] = (c[0] ^ c[14] ^ d[0]);
	crc16[7] = (c[0] ^ c[1] ^ c[15] ^ d[0] ^ d[1]);
	crc16[8] = (c[1] ^ c[2] ^ d[1] ^ d[2]);
	crc16[9] = (c[2] ^ c[3] ^ d[2] ^ d[3]);
	crc16[10] = (c[3] ^ c[4] ^ d[3] ^ d[4]);
	crc16[11] = (c[4] ^ c[5] ^ d[4] ^ d[5]);
	crc16[12] = (c[5] ^ c[6] ^ d[5] ^ d[6]);
	crc16[13] = (c[6] ^ c[7] ^ d[6] ^ d[7]);
	crc16[14] = (c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6]);
	crc16[15] = (c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[7] ^ d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7]);
end endfunction

localparam 
    S_RX_IDLE = 0,
    S_RX_TOKEN = 1,
    S_RX_DATA = 2,
    S_RX_SOF = 3,
    S_RX_ERROR = 4;
    
reg  [2:0]  rx_state;
reg  [1:0]  rx_axis_counter;
reg  [3:0]  rx_pid;
wire        rx_strobe;

assign rx_strobe = axis_rx_tvalid & axis_rx_tready;

always @(posedge clk)
    if (rst)
        rx_axis_counter <= 3'h0;
    else if (rx_strobe & axis_rx_tlast)
        rx_axis_counter <= 3'h0;
    else if (rx_strobe & (rx_axis_counter != 2'h3))
        rx_axis_counter <= rx_axis_counter + 1;
        
reg [7:0] rx_data_delay[0:1];
always @(posedge clk) begin
    if (rx_strobe) begin
        rx_data_delay[0] <= axis_rx_tdata;
        rx_data_delay[1] <= rx_data_delay[0];
    end
end

wire rx_valid_pid;
assign rx_valid_pid = ~axis_rx_error & (axis_rx_tdata[3:0] == ~axis_rx_tdata[7:4]);
      
always @(posedge clk)
    if ((rx_state == S_RX_IDLE) & rx_strobe & rx_valid_pid)
        rx_pid <= axis_rx_tdata[3:0];
        
always @(posedge clk) begin
    if (rst)
        rx_state <= S_RX_IDLE;
    else if (rx_strobe & axis_rx_tlast)
        rx_state <= S_RX_IDLE;
    else if (rx_strobe & axis_rx_error)
        rx_state <= S_RX_ERROR;
    else case (rx_state)
    S_RX_IDLE:
        if (rx_strobe) begin
            if (rx_valid_pid) begin
                case (axis_rx_tdata[1:0])
                2'b00: // Special packets not supported yet
                    rx_state <= S_RX_ERROR;
               
                2'b01:
                    rx_state <= (axis_rx_tdata[3:2] == 2'b01) ? S_RX_SOF : S_RX_TOKEN;
                
                2'b10: // Reached this only when handshake and not last, so error
                    rx_state <= S_RX_ERROR;
                    
                2'b11:
                    rx_state <= S_RX_DATA;
                    
                endcase 
            end else 
                rx_state <= S_RX_ERROR;
        end    
         
    S_RX_TOKEN:
        if (rx_strobe & (rx_axis_counter == 2'd2))
            rx_state <= S_RX_ERROR;
    
    S_RX_DATA:
        rx_state <= S_RX_DATA;
        
    S_RX_SOF:
        if (rx_strobe & (rx_axis_counter == 2'd2))
            rx_state <= S_RX_ERROR;
            
    S_RX_ERROR:
        rx_state <= S_RX_ERROR;
        
    endcase
end

wire crc5_valid;
assign crc5_valid = crc5({axis_rx_tdata[2:0], rx_data_delay[0]}) == axis_rx_tdata[7:3];

always @(posedge clk) begin
    if (((rx_state == S_RX_TOKEN) | (rx_state == S_RX_SOF)) & rx_strobe & axis_rx_tlast & crc5_valid) begin
        case (rx_pid[3:2])
        2'b00:
            rx_out <= 1'b1;
        2'b01:
            rx_sof <= 1'b1;
        2'b10:
            rx_in <= 1'b1;
        2'b11:
            rx_setup <= 1'b1;
        endcase
        if (rx_state == S_RX_TOKEN) begin
            rx_addr <= rx_data_delay[0][6:0];
            rx_endpoint <= {axis_rx_tdata[2:0], rx_data_delay[0][7]};
        end else if (rx_state == S_RX_SOF)
            rx_frame_number <= {axis_rx_tdata[2:0], rx_data_delay[0]};
    end else begin
        rx_out <= 1'b0;
        rx_in <= 1'b0;
        rx_setup <= 1'b0;
        rx_sof <= 1'b0;
    end
end

always @(posedge clk) begin
    if ((rx_state == S_RX_IDLE) & rx_strobe & axis_rx_tlast & rx_valid_pid & (axis_rx_tdata[1:0] == 2'b10)) begin
        rx_handshake <= 1'b1;
        rx_handshake_type <= {axis_rx_tdata[2], axis_rx_tdata[3]};
    end else begin
        rx_handshake <= 1'b0;
    end
end

always @(posedge clk) begin
    if ((rx_state == S_RX_IDLE) & rx_strobe & rx_valid_pid & (axis_rx_tdata[1:0] == 2'b11)) begin
        rx_data <= 1'b1;
        rx_data_type <= {axis_rx_tdata[2], axis_rx_tdata[3]};
    end else begin
        rx_data <= 1'b0;
    end
end

reg [15:0] rx_data_crc;
always @(posedge clk)
    if ((rx_state == S_RX_DATA) & rx_strobe & (rx_axis_counter >= 2'h2))
        rx_data_crc <= crc16(rx_data_delay[0], rx_data_crc);
    else if (rx_state != S_RX_DATA)
        rx_data_crc <= 16'hFFFF;

assign rx_data_tdata = rx_data_delay[1];
assign rx_data_tlast = axis_rx_tlast;
assign rx_data_error = axis_rx_error | (axis_rx_tlast & (~rx_data_crc != {axis_rx_tdata, rx_data_delay[0]}));
assign rx_data_tvalid = (rx_state == S_RX_DATA) & (rx_axis_counter >= 2'h3) & axis_rx_tvalid;
assign axis_rx_tready = ((rx_state == S_RX_DATA) & (rx_axis_counter >= 2'h3)) ? rx_data_tready : 1'b1;


localparam 
    S_TX_IDLE = 0,
    S_TX_HANDSHAKE = 1,
    S_TX_DATA_PID = 2,
    S_TX_DATA = 3,
    S_TX_DATA_CRC = 4;
    
reg  [2:0]  tx_state;
reg  [3:0]  tx_pid;
wire        tx_strobe;
reg         tx_null;

assign tx_strobe = axis_tx_tvalid & axis_tx_tready;
                   
reg         tx_crc_hi;
always @(posedge clk)
    if (tx_state != S_TX_DATA_CRC)
        tx_crc_hi <= 1'b0;
    else if (tx_strobe)
        tx_crc_hi <= 1'b1;

always @(posedge clk) 
    if ((tx_state == S_TX_IDLE) & tx_data)
        tx_null <= tx_data_null;

always @(posedge clk) begin
    if (rst)
        tx_state <= S_TX_IDLE;
    else case (tx_state)
    S_TX_IDLE:
        if (tx_handshake)
            tx_state <= S_TX_HANDSHAKE;
        else if (tx_data)
            tx_state <= S_TX_DATA_PID;
            
    S_TX_HANDSHAKE:
        if (tx_strobe)
            tx_state <= S_TX_IDLE;
    
    S_TX_DATA_PID:
        if (tx_strobe)
            tx_state <= tx_null ? S_TX_DATA_CRC : S_TX_DATA;
    
    S_TX_DATA:
        if (tx_strobe & tx_data_tlast)
            tx_state <= S_TX_DATA_CRC;
            
    S_TX_DATA_CRC:
        if (tx_strobe & tx_crc_hi)
            tx_state <= S_TX_IDLE;
                
    endcase
end

always @(posedge clk) begin
    if (tx_state == S_TX_IDLE) begin
        if (tx_handshake)
            tx_pid <= {tx_handshake_type[0], tx_handshake_type[1], 2'b10};
        else if (tx_data)
            tx_pid <= {tx_data_type[0], tx_data_type[1], 2'b11};
    end
end

reg [15:0] tx_data_crc;
always @(posedge clk)
    if ((tx_state == S_TX_DATA) & tx_strobe)
        tx_data_crc <= crc16(tx_data_tdata, tx_data_crc);
    else if (tx_state == S_TX_IDLE)
        tx_data_crc <= 16'hFFFF;
    
assign tx_ready = (tx_state == S_TX_IDLE);
assign tx_data_tready = (tx_state == S_TX_DATA) & axis_tx_tready;

always @(*) begin
    if ((tx_state == S_TX_HANDSHAKE) | (tx_state == S_TX_DATA_PID))
        axis_tx_tdata = tx_pid;
    else if (tx_state == S_TX_DATA_CRC)
        axis_tx_tdata = tx_crc_hi ? ~tx_data_crc[15:8] : ~tx_data_crc[7:0];
    else
        axis_tx_tdata = tx_data_tdata;
end
always @(*) begin
    if (tx_state == S_TX_HANDSHAKE)
        axis_tx_tlast = 1'b1;
    else if (tx_state == S_TX_DATA_CRC)
        axis_tx_tlast = tx_crc_hi;
    else
        axis_tx_tlast = 1'b0;
end
always @(*) begin
    if (tx_state == S_TX_HANDSHAKE)
        axis_tx_tvalid = 1'b1;
    else if (tx_state == S_TX_DATA_PID)
        axis_tx_tvalid = 1'b1;
    else if (tx_state == S_TX_DATA)
        axis_tx_tvalid = tx_data_tvalid;
    else if (tx_state == S_TX_DATA_CRC)
        axis_tx_tvalid = 1'b1;
    else
        axis_tx_tvalid = 1'b0;
end

endmodule
