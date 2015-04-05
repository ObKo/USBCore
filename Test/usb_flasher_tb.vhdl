--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_flasher_tb.vhdl
--
-- Copyright (c) 2015 Konstantin Oblaukhov
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
 
ENTITY usb_flasher_tb IS
END usb_flasher_tb;
 
architecture usb_flasher_tb of usb_flasher_tb is
  component usb_flasher
  port(
    clk                     : in  std_logic;
    rst                     : in  std_logic;
    
    ctl_xfer_endpoint       : in  std_logic_vector(3 downto 0);
    ctl_xfer_type           : in  std_logic_vector(7 downto 0);
    ctl_xfer_request        : in  std_logic_vector(7 downto 0);
    ctl_xfer_value          : in  std_logic_vector(15 downto 0);
    ctl_xfer_index          : in  std_logic_vector(15 downto 0);
    ctl_xfer_length         : in  std_logic_vector(15 downto 0);
    ctl_xfer_accept         : out std_logic;
    ctl_xfer                : in  std_logic;
    ctl_xfer_done           : out std_logic;
    ctl_xfer_data_out       : in  std_logic_vector(7 downto 0);
    ctl_xfer_data_out_valid : in  std_logic;
    ctl_xfer_data_in        : out std_logic_vector(7 downto 0);
    ctl_xfer_data_in_valid  : out std_logic;
    ctl_xfer_data_in_last   : out std_logic;
    ctl_xfer_data_in_ready  : in  std_logic;
    
    blk_xfer_endpoint       : in  std_logic_vector(3 downto 0);
    blk_in_xfer             : in  std_logic;
    blk_out_xfer            : in  std_logic;
    blk_xfer_in_has_data    : out std_logic;
    blk_xfer_in_data        : out std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : out std_logic;
    blk_xfer_in_data_ready  : in  std_logic;
    blk_xfer_in_data_last   : out std_logic;
    blk_xfer_out_ready_read : out std_logic;
    blk_xfer_out_data       : in  std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : in  std_logic;
    
    spi_cs                  : out std_logic;
    spi_sck                 : out std_logic;
    spi_mosi                : out std_logic;
    spi_miso                : in  std_logic
    );
  end component;
    

   --Inputs
  signal clk                     : std_logic := '0';
  signal rst                     : std_logic := '0';
  
  signal ctl_xfer_endpoint       : std_logic_vector(3 downto 0) := (others => '0');
  signal ctl_xfer_type           : std_logic_vector(7 downto 0) := (others => '0');
  signal ctl_xfer_request        : std_logic_vector(7 downto 0) := (others => '0');
  signal ctl_xfer_value          : std_logic_vector(15 downto 0) := (others => '0');
  signal ctl_xfer_index          : std_logic_vector(15 downto 0) := (others => '0');
  signal ctl_xfer_length         : std_logic_vector(15 downto 0) := (others => '0');
  signal ctl_xfer                : std_logic := '0';
  signal ctl_xfer_data_out       : std_logic_vector(7 downto 0) := (others => '0');
  signal ctl_xfer_data_out_valid : std_logic := '0';
  signal ctl_xfer_data_in_ready  : std_logic := '0';
  
  signal blk_xfer_endpoint       : std_logic_vector(3 downto 0) := (others => '0');
  signal blk_in_xfer             : std_logic := '0';
  signal blk_out_xfer            : std_logic := '0';
  signal blk_xfer_in_data_ready  : std_logic := '0';
  signal blk_xfer_out_data       : std_logic_vector(7 downto 0) := (others => '0');
  signal blk_xfer_out_data_valid : std_logic := '0';
  
  signal spi_miso                : std_logic := '0';

 	--Outputs
  signal ctl_xfer_accept         : std_logic;
  signal ctl_xfer_done           : std_logic;
  signal ctl_xfer_data_in        : std_logic_vector(7 downto 0);
  signal ctl_xfer_data_in_valid  : std_logic;
  signal ctl_xfer_data_in_last   : std_logic;
  signal blk_xfer_in_has_data    : std_logic;
  signal blk_xfer_in_data        : std_logic_vector(7 downto 0);
  signal blk_xfer_in_data_valid  : std_logic;
  signal blk_xfer_in_data_last   : std_logic;
  signal blk_xfer_out_ready_read : std_logic;
   
  signal spi_cs                  : std_logic;
  signal spi_sck                 : std_logic;
  signal spi_mosi                : std_logic;

  constant clk_period : time := 10 ns;
 
BEGIN
  FLASHER: usb_flasher 
  port map (
    clk => clk,
    rst => rst,
    
    ctl_xfer_endpoint => ctl_xfer_endpoint,
    ctl_xfer_type => ctl_xfer_type,
    ctl_xfer_request => ctl_xfer_request,
    ctl_xfer_value => ctl_xfer_value,
    ctl_xfer_index => ctl_xfer_index,
    ctl_xfer_length => ctl_xfer_length,
    ctl_xfer_accept => ctl_xfer_accept,
    ctl_xfer => ctl_xfer,
    ctl_xfer_done => ctl_xfer_done,
    ctl_xfer_data_out => ctl_xfer_data_out,
    ctl_xfer_data_out_valid => ctl_xfer_data_out_valid,
    ctl_xfer_data_in => ctl_xfer_data_in,
    ctl_xfer_data_in_valid => ctl_xfer_data_in_valid,
    ctl_xfer_data_in_last => ctl_xfer_data_in_last,
    ctl_xfer_data_in_ready => ctl_xfer_data_in_ready,
    
    blk_xfer_endpoint => blk_xfer_endpoint,
    blk_in_xfer => blk_in_xfer,
    blk_out_xfer => blk_out_xfer,
    blk_xfer_in_has_data => blk_xfer_in_has_data,
    blk_xfer_in_data => blk_xfer_in_data,
    blk_xfer_in_data_valid => blk_xfer_in_data_valid,
    blk_xfer_in_data_ready => blk_xfer_in_data_ready,
    blk_xfer_in_data_last => blk_xfer_in_data_last,
    blk_xfer_out_ready_read => blk_xfer_out_ready_read,
    blk_xfer_out_data => blk_xfer_out_data,
    blk_xfer_out_data_valid => blk_xfer_out_data_valid,
    
    spi_cs => spi_cs,
    spi_sck => spi_sck,
    spi_mosi => spi_mosi,
    spi_miso => spi_miso
  );
  
  ctl_xfer_endpoint <= X"0";
  ctl_xfer_type <= X"C0";
  ctl_xfer_request <= X"04";
  ctl_xfer_value <= X"0085";
  ctl_xfer_index <= (others => '0');
  ctl_xfer_length <= X"0001";
  ctl_xfer_data_in_ready <= '0';
  
  ctl_xfer_data_out <= X"A5";
     
  CLK_GEN: process
  begin
    clk <= '0';
	wait for clk_period/2;
	clk <= '1';
	wait for clk_period/2;
  end process;
 
  STIM: process
  begin		
    wait for 100 ns;	
    rst <= '1';
    wait for clk_period*10;
    rst <= '0';
    wait for clk_period;
    
--    blk_out_xfer <= '1';
--    blk_xfer_out_data_valid <= '1';  
--    blk_xfer_out_data <= X"A5";
--    
--    wait for clk_period;
--    blk_xfer_out_data <= X"88";
--
--    wait for clk_period*255;
--    blk_out_xfer <= '0';
--    blk_xfer_out_data_valid <= '0';
    
    ctl_xfer <= '1';
    ctl_xfer_data_out_valid <= '1';
    wait for clk_period*100;
    ctl_xfer <= '0';

    --blk_in_xfer <= '1';
    --blk_xfer_in_data_ready <= '1';
    
    --wait for clk_period*256;
    --blk_in_xfer <= '0';
    --blk_xfer_in_data_ready <= '0';
        
    wait;
  end process;

end;
