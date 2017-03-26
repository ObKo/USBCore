create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list ULPI_CTL/IO/clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {TRN_CTL/trn_endpoint[0]} {TRN_CTL/trn_endpoint[1]} {TRN_CTL/trn_endpoint[2]} {TRN_CTL/trn_endpoint[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 5 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {TRN_CTL/trn_crc5[0]} {TRN_CTL/trn_crc5[1]} {TRN_CTL/trn_crc5[2]} {TRN_CTL/trn_crc5[3]} {TRN_CTL/trn_crc5[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 11 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {TRN_CTL/trn_frame_number[0]} {TRN_CTL/trn_frame_number[1]} {TRN_CTL/trn_frame_number[2]} {TRN_CTL/trn_frame_number[3]} {TRN_CTL/trn_frame_number[4]} {TRN_CTL/trn_frame_number[5]} {TRN_CTL/trn_frame_number[6]} {TRN_CTL/trn_frame_number[7]} {TRN_CTL/trn_frame_number[8]} {TRN_CTL/trn_frame_number[9]} {TRN_CTL/trn_frame_number[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {TRN_CTL/trn_type[0]} {TRN_CTL/trn_type[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 7 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {TRN_CTL/trn_address[0]} {TRN_CTL/trn_address[1]} {TRN_CTL/trn_address[2]} {TRN_CTL/trn_address[3]} {TRN_CTL/trn_address[4]} {TRN_CTL/trn_address[5]} {TRN_CTL/trn_address[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {TRN_CTL/dbg_rx_tdata[0]} {TRN_CTL/dbg_rx_tdata[1]} {TRN_CTL/dbg_rx_tdata[2]} {TRN_CTL/dbg_rx_tdata[3]} {TRN_CTL/dbg_rx_tdata[4]} {TRN_CTL/dbg_rx_tdata[5]} {TRN_CTL/dbg_rx_tdata[6]} {TRN_CTL/dbg_rx_tdata[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list TRN_CTL/dbg_rx_tlast]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list TRN_CTL/dbg_rx_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list TRN_CTL/dbg_rx_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list TRN_CTL/trn_sof]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list TRN_CTL/trn_start]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ulpi_clk]
