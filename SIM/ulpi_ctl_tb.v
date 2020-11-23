`timescale 1ns/1ps

module ulpi_ctl_tb;

wire         ulpi_clk;
reg          ulpi_rst;

wire         ulpi_dir;
wire         ulpi_nxt;
wire         ulpi_stp;
wire [7:0]   ulpi_data_in;
wire [7:0]   ulpi_data_out;

wire [1:0]   line_state;
wire [1:0]   vbus_state;
wire         rx_active;
wire         rx_error;
wire         host_disconnect;

reg          reg_en;
wire         reg_rdy;
reg          reg_we;
reg  [7:0]   reg_addr;
reg  [7:0]   reg_din;
wire [7:0]   reg_dout;

wire [7:0]   axis_rx_tdata;
wire         axis_rx_tlast;
wire         axis_rx_error;
wire         axis_rx_tvalid;
reg          axis_rx_tready;

wire  [7:0]  axis_tx_tdata;
wire         axis_tx_tlast;
wire         axis_tx_tvalid;
wire         axis_tx_tready;

ulpi_ctl CTL (
    .ulpi_clk(ulpi_clk),
    .ulpi_rst(ulpi_rst),
    
    .ulpi_dir(ulpi_dir),
    .ulpi_nxt(ulpi_nxt),
    .ulpi_stp(ulpi_stp),
    .ulpi_data_in(ulpi_data_in),
    .ulpi_data_out(ulpi_data_out),
    
    .line_state(line_state),
    .vbus_state(vbus_state),
    .rx_active(rx_active),
    .rx_error(rx_error),
    .host_disconnect(host_disconnect),
    
    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout),
    
    .axis_rx_tdata(axis_rx_tdata),
    .axis_rx_tlast(axis_rx_tlast),
    .axis_rx_error(axis_rx_error),
    .axis_rx_tvalid(axis_rx_tvalid),
    .axis_rx_tready(axis_rx_tready),
    
    .axis_tx_tdata(axis_tx_tdata),
    .axis_tx_tlast(axis_tx_tlast),
    .axis_tx_tvalid(axis_tx_tvalid),
    .axis_tx_tready(axis_tx_tready)
);

ulpi_phy_bfm ULPI (
    .ulpi_clk(ulpi_clk),
    .ulpi_rst(ulpi_rst),
    
    .ulpi_dir(ulpi_dir),
    .ulpi_nxt(ulpi_nxt),
    .ulpi_stp(ulpi_stp),
    .ulpi_data_in(ulpi_data_in),
    .ulpi_data_out(ulpi_data_out)
);

reg [7:0] axis_rx_data[1024];
reg [9:0] axis_rx_count = 10'h000;
reg       axis_rx_was_last = 1'b0;
reg       axis_rx_was_error = 1'b0;

always @(posedge ulpi_clk) begin
    if (axis_rx_tvalid & axis_rx_tready) begin
        axis_rx_was_last <= axis_rx_tlast;
        axis_rx_was_error <= axis_rx_error;
        axis_rx_data[axis_rx_was_last ? 10'h000 : axis_rx_count] <= axis_rx_tdata;
        if (axis_rx_was_last)
            axis_rx_count <= 1;
        else
            axis_rx_count <= axis_rx_count + 1;
    end
end

reg [7:0] axis_tx_data[1024];
reg [9:0] axis_tx_count = 10'h000;
reg       axis_tx_start;
reg       axis_tx_done;
reg [9:0] axis_tx_counter = 10'h3FF;

always @(posedge ulpi_clk) begin
    if (axis_tx_start)
        axis_tx_counter <= axis_tx_count - 1;
    else if (axis_tx_tvalid & axis_tx_tready)
        axis_tx_counter <= axis_tx_counter - 1;
end
assign axis_tx_tvalid = axis_tx_counter != 10'h3FF;
assign axis_tx_tlast = axis_tx_counter == 10'h000;
assign axis_tx_tdata = axis_tx_data[axis_tx_count - axis_tx_counter - 1];
assign axis_tx_done = axis_tx_tvalid & axis_tx_tready & axis_tx_tlast;

reg [9:0] i;
initial begin
    $dumpfile("ulpi_ctl_tb.lxt");
    $dumpvars(0, CTL, ulpi_ctl_tb);
    
    ulpi_rst = 1'b1;
    #100
    ulpi_rst = 1'b0;
    #100
    ULPI.cycle();
    
    axis_rx_tready = 1'b1;
    
    // Test VBUS state
    ULPI.rx_cmd(2'b00, 2'b00, 1'b0, 1'b0, 1'b0);
    ULPI.cycle();
    assert((line_state == 2'b00) && (vbus_state == 2'b00) && (rx_active == 1'b0) && (rx_error == 1'b0) && (host_disconnect == 1'b0));
    
    ULPI.rx_cmd(2'b01, 2'b00, 1'b0, 1'b0, 1'b0);
    ULPI.cycle();
    assert((line_state == 2'b01) && (vbus_state == 2'b00) && (rx_active == 1'b0) && (rx_error == 1'b0) && (host_disconnect == 1'b0));
    
    ULPI.rx_cmd(2'b11, 2'b00, 1'b0, 1'b0, 1'b0);
    ULPI.cycle();
    assert((line_state == 2'b11) && (vbus_state == 2'b00) && (rx_active == 1'b0) && (rx_error == 1'b0) && (host_disconnect == 1'b0));
    
    ULPI.idle();
    ULPI.cycle();
    
    // Test ULPI register write->read
    reg_en = 1'b1;
    reg_we = 1'b1;
    reg_addr = 8'h0A;
    reg_din = 8'hA5;
    @(posedge reg_rdy);
    reg_en = 1'b0;
    ULPI.cycle();
    
    reg_en = 1'b1;
    reg_we = 1'b0;
    reg_addr = 8'h0A;
    @(posedge reg_rdy);
    assert(reg_dout == reg_din);
    reg_en = 1'b0;
    ULPI.cycle();
    
    // Test ULPI extended register write->read
    reg_en = 1'b1;
    reg_we = 1'b1;
    reg_addr = 8'hF0;
    reg_din = 8'h5A;
    @(posedge reg_rdy);
    reg_en = 1'b0;
    ULPI.cycle();
    
    reg_en = 1'b1;
    reg_we = 1'b0;
    reg_addr = 8'hF0;
    @(posedge reg_rdy);
    assert(reg_dout == reg_din);
    reg_en = 1'b0;
    ULPI.cycle();
    
    // Test data receive
    ULPI.data[0] = 8'hA5;
    for (i = 1; i < 8; i = i + 1)
        ULPI.data[i] = i[7:0];
    
    // FullSpeed
    ULPI.rx_data(8, 1'b1, 1'b0, 1'b0);
    ULPI.cycle();
    ULPI.cycle();
    assert(axis_rx_count == 10'h008);
    assert(axis_rx_was_last == 1'b1);
    for (i = 0; i < 8; i = i + 1)
        assert(ULPI.data[i] == axis_rx_data[i]);

    // HiSpeed
    ULPI.rx_data(8, 1'b0, 1'b0, 1'b0);
    ULPI.cycle();
    ULPI.cycle();
    assert(axis_rx_count == 10'h008);
    assert(axis_rx_was_last == 1'b1);
    for (i = 0; i < 8; i = i + 1)
        assert(ULPI.data[i] == axis_rx_data[i]);
        
    // No rx cmd after last data
    ULPI.rx_data(8, 1'b0, 1'b0, 1'b1);
    ULPI.cycle();
    ULPI.cycle();
    assert(axis_rx_count == 10'h008);
    assert(axis_rx_was_last == 1'b1);
    for (i = 0; i < 8; i = i + 1)
        assert(ULPI.data[i] == axis_rx_data[i]);
        
    // Fast start (dir = 1 & nxt = 1)
    ULPI.rx_data(8, 1'b0, 1'b1, 1'b1);
    ULPI.cycle();
    ULPI.cycle();
    assert(axis_rx_count == 10'h008);
    assert(axis_rx_was_last == 1'b1);
    for (i = 0; i < 8; i = i + 1)
        assert(ULPI.data[i] == axis_rx_data[i]);
     
    // Reg write/read aborted by RX data
    reg_en = 1'b1;
    reg_we = 1'b1;
    reg_addr = 8'h0A;
    reg_din = 8'hDE;
    
    ULPI.abort_reg = 1'b1;
    @(posedge axis_rx_tvalid);
    ULPI.abort_reg = 1'b0;
    
    @(posedge reg_rdy);
    reg_en = 1'b0;
    ULPI.cycle();
    
    reg_en = 1'b1;
    reg_we = 1'b0;
    reg_addr = 8'h0A;
    
    ULPI.abort_reg = 1'b1;
    @(posedge axis_rx_tvalid);
    ULPI.abort_reg = 1'b0;
    
    @(posedge reg_rdy);
    assert(reg_dout == reg_din);
    reg_en = 1'b0;
    ULPI.cycle();
    
    // Ext. reg write/read aborted by RX data
    reg_en = 1'b1;
    reg_we = 1'b1;
    reg_addr = 8'hFA;
    reg_din = 8'hAD;
    
    ULPI.abort_reg = 1'b1;
    @(posedge axis_rx_tvalid);
    ULPI.abort_reg = 1'b0;
    
    @(posedge reg_rdy);
    reg_en = 1'b0;
    ULPI.cycle();
    
    reg_en = 1'b1;
    reg_we = 1'b0;
    reg_addr = 8'hFA;
    
    ULPI.abort_reg = 1'b1;
    @(posedge axis_rx_tvalid);
    ULPI.abort_reg = 1'b0;
    
    @(posedge reg_rdy);
    assert(reg_dout == reg_din);
    reg_en = 1'b0;
    ULPI.cycle();
    
    // Test data receive aborted by AXI trottling
    axis_rx_tready = 1'b0;
    
    ULPI.rx_data(8, 1'b0, 1'b0, 1'b1);
    
    axis_rx_tready = 1'b1;
    
    ULPI.cycle();
    ULPI.cycle();
    ULPI.cycle();
    
    assert((axis_rx_was_last == 1'b1) && (axis_rx_was_error == 1'b1));
    
    // Test data receive aborted by PHY    
    ULPI.abort_rx = 1'b1;
    ULPI.rx_data(8, 1'b0, 1'b0, 1'b1);
    ULPI.abort_rx = 1'b0;
    
    ULPI.cycle();
    ULPI.cycle();
    ULPI.cycle();
    
    assert((axis_rx_was_last == 1'b1) && (axis_rx_was_error == 1'b1));
    
    // Test ACK send
    axis_tx_data[0] = 8'h02;
    axis_tx_count = 1;
    axis_tx_start = 1'b1;
    ULPI.cycle();
    axis_tx_start = 1'b0;
    @(posedge axis_tx_done);
    ULPI.cycle();
    
    assert(ULPI.data[0][3:0] == axis_tx_data[0][3:0]);
    ULPI.cycle();

    // Test SOF send
    axis_tx_data[0] = 8'h05;
    axis_tx_data[1] = 8'h00;
    axis_tx_data[2] = 8'hF8;
    axis_tx_count = 3;
    axis_tx_start = 1'b1;
    ULPI.cycle();
    axis_tx_start = 1'b0;
    @(posedge axis_tx_done);
    ULPI.cycle();
    
    assert(ULPI.data[0][3:0] == axis_tx_data[0][3:0]);
    for (i = 1; i < 3; i = i + 1)
        assert(ULPI.data[i] == axis_tx_data[i]);
            
    #100
    $finish();
end

endmodule
