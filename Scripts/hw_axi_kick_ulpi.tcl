#create_hw_axi_txn ulpi_rst -force -type WRITE -address 0x04 -data 0x00000020 -len 1 [get_hw_axis hw_axi_1]
create_hw_axi_txn ulpi_0A -force -type WRITE -address 0x0A -data 0x00000000 -len 1 [get_hw_axis hw_axi_1]
create_hw_axi_txn ulpi_04 -force -type WRITE -address 0x04 -data 0x00000045 -len 1 [get_hw_axis hw_axi_1]

run_hw_axi ulpi_0A ulpi_04
