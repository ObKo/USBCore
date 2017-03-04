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
        
always_ff @(posedge clk)
    if (rst)
        txstp <= '0;
    else if (tx.tvalid & tx.tready & tx.tlast)
        txstp <= 1'b1;
    else
        txstp <= 1'b0;        

assign rx.tvalid = ulpi.dir & ~turnaround;
assign rx.tdata = ulpi.rx_data;
assign rx.tuser = {rxactive, phydata};

assign tx.tready = ~ulpi.dir & ~turnaround & ulpi.nxt & ~txstp;

assign ulpi.stp = ulpi.dir ? ~rx.tready : txstp;
assign ulpi.tx_data = (tx.tvalid & ~txstp) ? tx.tdata : 8'h00;

endmodule
