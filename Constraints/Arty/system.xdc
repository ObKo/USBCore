set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rxd}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_txd}]
set_property PACKAGE_PIN E3 [get_ports {sys_clk}]
set_property PACKAGE_PIN C2 [get_ports {sys_rst_n}]
set_property PACKAGE_PIN A9 [get_ports {uart_rxd}]
set_property PACKAGE_PIN D10 [get_ports {uart_txd}]

set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports {qspi_cs}];
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {qspi_dq[0]}];
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {qspi_dq[1]}];
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports {qspi_dq[2]}];
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {qspi_dq[3]}];

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
