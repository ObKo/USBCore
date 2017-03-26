set_property IOSTANDARD LVCMOS33 [get_ports {phy\.dir}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy\.clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy\.nxt}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy\.rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy\.stp}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy\.data[*]}]

set_property PACKAGE_PIN E15 [get_ports {phy\.dir}]
set_property PACKAGE_PIN D15 [get_ports {phy\.clk}]
set_property PACKAGE_PIN J17 [get_ports {phy\.nxt}]
set_property PACKAGE_PIN J18 [get_ports {phy\.rst}]
set_property PACKAGE_PIN K15 [get_ports {phy\.stp}]
set_property PACKAGE_PIN U12 [get_ports {phy\.data[7]}]
set_property PACKAGE_PIN V12 [get_ports {phy\.data[5]}]
set_property PACKAGE_PIN V10 [get_ports {phy\.data[3]}]
set_property PACKAGE_PIN V11 [get_ports {phy\.data[1]}]
set_property PACKAGE_PIN U14 [get_ports {phy\.data[6]}]
set_property PACKAGE_PIN V14 [get_ports {phy\.data[4]}]
set_property PACKAGE_PIN T13 [get_ports {phy\.data[2]}]
set_property PACKAGE_PIN U13 [get_ports {phy\.data[0]}]

create_clock -period 16.666 -name ulpi_clk [get_ports {phy\.clk}]

# USB3300 timing from datasheet
set_input_delay -clock ulpi_clk -min 2.0 [get_ports {{phy\.data[*]} {phy\.nxt}}];
set_input_delay -clock ulpi_clk -max 5.0 [get_ports {{phy\.data[*]} {phy\.nxt}}];
set_output_delay -clock ulpi_clk -max 5.0 [get_ports {{phy\.data[*]} {phy\.stp} {phy\.rst}}];
#set_property IOB TRUE [get_ports {{phy\.data[*]} {phy\.nxt} {phy\.stp}}]

