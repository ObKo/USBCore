set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]

set_property PACKAGE_PIN C2 [get_ports rst_btn]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

