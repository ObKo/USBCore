module ulpi_phy_bfm (
    output reg          ulpi_clk,
    input  wire         ulpi_rst,
    
    output reg          ulpi_dir,
    output reg          ulpi_nxt,
    input  wire         ulpi_stp,
    output reg [7:0]    ulpi_data_in,
    input  wire [7:0]   ulpi_data_out
);

reg [7:0] registers[0:255];
reg [7:0] data[0:1023];
reg abort_reg = 1'b0;
reg abort_rx = 1'b0;

task cycle;
begin
    @(posedge ulpi_clk);
    #1;
end endtask

task rx_cmd;
    input [1:0] line_state;
    input [1:0] vbus_state;
    input       rx_active;
    input       rx_error;
    input       host_disconnect;
begin
    ulpi_dir = 1'b1;
    ulpi_nxt = 1'b0;
    ulpi_data_in = {1'b0, 1'b0, host_disconnect ? 2'b10 : (rx_error ? 2'b11 : (rx_active ? 2'b01 : 2'b00)), vbus_state, line_state};
end endtask

task rx_data;
    input [7:0] length;
    input fullspeed;
    input fast_start;
    input idle_on_last;
    reg [7:0] i;
    reg [5:0] j;
    reg was_stp;
begin
    if (fast_start) begin
        ulpi_nxt = 1'b1;
        ulpi_dir = 1'b1;
        cycle();
    end else begin
        rx_cmd(2'b01, 2'b11, 1'b1, 1'b0, 1'b0);
        cycle();
        cycle();
    end
    
    was_stp = 1'b0;
    for (i = 0; (i < length) && !was_stp; i = i + 1) begin
        ulpi_data_in = data[i];
        ulpi_nxt = 1'b1;
        cycle();
        
        if (ulpi_stp)
            was_stp = 1'b1;
            
        if (abort_rx && (i == length / 2)) begin
            rx_cmd(2'b01, 2'b11, 1'b0, 1'b1, 1'b0);
            cycle();
            was_stp = 1'b1;
        end
        
        if (fullspeed && !was_stp) begin
            ulpi_nxt = 1'b0;
            rx_cmd(2'b01, 2'b11, 1'b1, 1'b0, 1'b0);
            for (j = 0; j < 40; j = j + 1)
                cycle();
        end
    end
    
    if (idle_on_last || was_stp) begin
        idle();
        cycle();
    end else begin
        rx_cmd(2'b01, 2'b11, 1'b0, 1'b0, 1'b0);
        cycle();
    end
end endtask

task idle;
begin
    ulpi_dir = 1'b0;
    ulpi_nxt = 1'b0;
    ulpi_data_in = 8'h00;
end endtask

task reg_read;
    input [5:0] addr;
begin
    cycle();
    ulpi_nxt = 1'b1;        
    cycle();
    
    if (abort_reg)
        rx_data(10'h008, 1'b0, 1'b1, 1'b1);
    else begin
        ulpi_nxt = 1'b0;
        ulpi_dir = 1'b1;
        cycle();
        ulpi_data_in = registers[addr];
        cycle();
    end
    idle();
end endtask

task reg_read_ext;
    reg [7:0] addr;
begin
    cycle();
    ulpi_nxt = 1'b1;
    cycle();
    addr = ulpi_data_out;
    ulpi_nxt = 1'b1;
    
    if (abort_reg)
        rx_data(10'h008, 1'b0, 1'b1, 1'b1);
    else begin
        cycle();
        ulpi_nxt = 1'b0;
        ulpi_dir = 1'b1;
        cycle();
        ulpi_data_in = registers[addr];
        cycle();
    end
    idle();
end endtask

task reg_write;
    input [5:0] addr;
begin
    cycle();
    ulpi_nxt = 1'b1;
    cycle();
    if (abort_reg)
        rx_data(10'h008, 1'b0, 1'b1, 1'b1);
    else begin
        registers[addr] = ulpi_data_out;
        ulpi_nxt = 1'b1;
        cycle();
    end
    idle();
end endtask

task reg_write_ext;
    reg [7:0] addr;
begin
    cycle();
    ulpi_nxt = 1'b1;
    cycle();
    addr = ulpi_data_out;
    ulpi_nxt = 1'b1;
    cycle();
    if (abort_reg)
        rx_data(10'h008, 1'b0, 1'b1, 1'b1);
    else begin
        registers[addr] = ulpi_data_out;
        ulpi_nxt = 1'b1;
        cycle();
    end
    idle();
end endtask

initial begin
    forever begin
        #8.333
        ulpi_clk <= 1'b0;
        #8.333
        ulpi_clk <= 1'b1;
    end
end 

initial begin
    forever begin
        if (ulpi_rst) begin
            ulpi_dir = 1'b1;
            ulpi_nxt = 1'b1;
            ulpi_data_in = 8'h00;
            cycle();
        end else begin
            cycle();
            if ((ulpi_dir == 1'b0) && (ulpi_data_out[7:0] == 8'b11101111))
                reg_read_ext();
            else if ((ulpi_dir == 1'b0) && (ulpi_data_out[7:0] == 8'b10101111))
                reg_write_ext();
            else if ((ulpi_dir == 1'b0) && (ulpi_data_out[7:6] == 2'b11))
                reg_read(ulpi_data_out[5:0]);
            else if ((ulpi_dir == 1'b0) && (ulpi_data_out[7:6] == 2'b10))
                reg_write(ulpi_data_out[5:0]);
        end
    end
end 

endmodule
