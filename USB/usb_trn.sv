module usb_trn (
    input                       clk,
    input                       rst,
    
    axi_stream_iface.slave      rx,
    axi_stream_iface.master     tx
);

enum {S_RX_P_IDLE, S_RX_P_TOKEN, S_RX_P_RECEIVED, S_RX_P_ERR_WAIT_END} rx_packet_state;
logic [1:0] rx_packet_counter;

(* mark_debug = "true" *)logic [1:0]     trn_type;
(* mark_debug = "true" *)logic [6:0]     trn_address;
(* mark_debug = "true" *)logic [3:0]     trn_endpoint;
(* mark_debug = "true" *)logic [10:0]    trn_frame_number;
(* mark_debug = "true" *)logic [4:0]     trn_crc5;
(* mark_debug = "true" *)logic           trn_start;
(* mark_debug = "true" *)logic           trn_sof;

assign trn_start = (rx_packet_state == S_RX_P_RECEIVED) & (trn_type != 2'b01);
assign trn_sof = (rx_packet_state == S_RX_P_RECEIVED) & (trn_type == 2'b01);
assign trn_frame_number = {trn_endpoint, trn_address};

always_ff @(posedge clk) begin
    if (rst) begin
        rx_packet_state <= S_RX_P_IDLE;
        trn_type <= '0;
    end else case (rx_packet_state)
    S_RX_P_IDLE:
        if (rx.tvalid) begin
            if (rx.tdata[1:0] == 2'b01) begin
                rx_packet_state <= S_RX_P_TOKEN;
                trn_type <= rx.tdata[3:2];
            end else begin
                rx_packet_state <= S_RX_P_ERR_WAIT_END;
            end
        end
                
    S_RX_P_TOKEN:
        if (rx.tvalid) begin
            if (rx.tlast) begin
                if (rx_packet_counter == 2'b01)
                    rx_packet_state <= S_RX_P_RECEIVED;
                else
                    rx_packet_state <= S_RX_P_IDLE;
            end else if (rx_packet_counter == 2'b01)
                rx_packet_state <= S_RX_P_ERR_WAIT_END;                
        end
        
    S_RX_P_RECEIVED:
        rx_packet_state <= S_RX_P_IDLE;
        
    S_RX_P_ERR_WAIT_END:
        if (rx.tvalid & rx.tlast)
            rx_packet_state <= S_RX_P_IDLE;
            
    endcase
end
    
always_ff @(posedge clk)
    if (rx_packet_state == S_RX_P_IDLE)
        rx_packet_counter <= '0;
    else if ((rx_packet_state == S_RX_P_TOKEN) & rx.tvalid)
        rx_packet_counter <= rx_packet_counter + 1;

always_ff @(posedge clk) begin
    if (rst) begin
        trn_address <= '0;
        trn_endpoint <= '0;
        trn_crc5 <= '0;
    end else if ((rx_packet_state == S_RX_P_TOKEN) & rx.tvalid) begin
        if (rx_packet_counter == 2'b00) begin
             trn_address <= rx.tdata[6:0];
             trn_endpoint[0] <= rx.tdata[7];
        end else if (rx_packet_counter == 2'b01) begin
             trn_endpoint[3:1] <= rx.tdata[2:0];
             trn_crc5 <= rx.tdata[7:3];
        end 
    end
end

assign rx.tready = 1'b1;

(* mark_debug = "true" *)logic       dbg_rx_tvalid;
(* mark_debug = "true" *)logic       dbg_rx_tready;
(* mark_debug = "true" *)logic [7:0] dbg_rx_tdata;
(* mark_debug = "true" *)logic       dbg_rx_tlast;

(* mark_debug = "true" *)logic       dbg_tx_tvalid;
(* mark_debug = "true" *)logic       dbg_tx_tready;
(* mark_debug = "true" *)logic [7:0] dbg_tx_tdata;
(* mark_debug = "true" *)logic       dbg_tx_tlast;

assign dbg_rx_tvalid = rx.tvalid;
assign dbg_rx_tready = rx.tready;
assign dbg_rx_tdata  = rx.tdata;
assign dbg_rx_tlast  = rx.tlast;

assign dbg_tx_tvalid = tx.tvalid;
assign dbg_tx_tready = tx.tready;
assign dbg_tx_tdata  = tx.tdata;
assign dbg_tx_tlast  = tx.tlast;

endmodule
