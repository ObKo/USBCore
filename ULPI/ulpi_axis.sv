module ulpi_axis (
    input           clk,
    input           rst,
    
    ulpi_iface.dst  ulpi,
    
    ulpi_axis_iface.rx_master   rx,
    ulpi_axis_iface.tx_slave    tx
);

// Bus turnaround
logic   turnaround;
// Is it RXCMD/RegData or USB data
logic   phydata;
// Active USB receive
logic   rxactive;
// TX stop
logic   txstp;

// Bus turnaround: one clock cycle after dir edge
logic dir_d;
always_ff @(posedge clk)
    if (rst)
        dir_d <= '1;
    else
        dir_d <= ulpi.dir;
assign turnaround = ulpi.dir ^ dir_d;

logic trn_d;
always_ff @(posedge clk)
    trn_d <= turnaround;

// Is it USB data or PHY service data
assign phydata = ulpi.dir & ~ulpi.nxt;

// FIXME: Still combinational ulpi.rx_data[4]
// RxActive: see ULPI spec v1.1, 3.8.2.4
always_ff @(posedge clk)
    if (rst)
        rxactive <= '0;
    else if (~ulpi.dir)
        rxactive <= '0;
    else if (~dir_d & ulpi.dir & ulpi.nxt)
        rxactive <= '1;
    else if (dir_d & ~trn_d & phydata)
        rxactive <= ulpi.rx_data[4];
        
always_ff @(posedge clk) begin
    if (rst) begin
        rx.tvalid <= '0;
        rx.tdata <= '0;
        rx.tuser <= '0;
    end else begin
        rx.tvalid <= ulpi.dir & ~turnaround;
        rx.tdata <= ulpi.rx_data;
        rx.tuser <= {rxactive, phydata};
    end
end

logic [7:0] tx_reg;
logic       tx_reg_valid;
logic       tx_reg_last;
logic       tx_reg_ready;

always_ff @(posedge clk) begin
    if (rst)
        tx_reg_valid <= 1'b0;
    else if (~tx_reg_valid & tx.tvalid)
        tx_reg_valid <= 1'b1; 
    else if (tx_reg_valid & ~tx.tvalid & tx_reg_ready)
        tx_reg_valid <= 1'b0; 
end

always_ff @(posedge clk) begin
    if (rst) begin
        tx_reg <= '0;
        tx_reg_last <= 1'b0;
    end else if (tx.tvalid & tx_reg_ready) begin
        tx_reg <= tx.tdata;
        tx_reg_last <= tx.tlast;
    end else if (~tx.tvalid & tx_reg_ready) begin
        tx_reg <= '0;
        tx_reg_last <= 1'b0;
    end
end
assign tx_reg_ready = (~ulpi.dir & ~turnaround & ulpi.nxt & ~txstp) | ~tx_reg_valid;

always_ff @(posedge clk)
    if (rst)
        txstp <= '0;
    else if (ulpi.dir)
        txstp <= 1'b0;
    else if (tx_reg_ready & tx_reg_last)
        txstp <= 1'b1;
    else
        txstp <= 1'b0;

assign tx.tready = tx_reg_ready;

// TODO: Assert RX STP when not ready
assign ulpi.stp = txstp;
assign ulpi.tx_data = tx_reg;

endmodule
