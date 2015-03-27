--
-- USB Full-Speed/Hi-Speed Device Controller core - blk_ep_out_ctl.vhdl
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity blk_ep_out_ctl is
  port (
    rst                     : in  std_logic;
    usb_clk                 : in  std_logic;
    axis_clk                : in  std_logic;
    
    blk_out_xfer            : in  std_logic;

    blk_xfer_out_ready_read : out std_logic;
    blk_xfer_out_data       : in  std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : in  std_logic;
    
    axis_tdata              : out std_logic_vector(7 downto 0);
    axis_tvalid             : out std_logic;
    axis_tready             : in  std_logic;
    axis_tlast              : out std_logic
  );
end blk_ep_out_ctl;

architecture blk_ep_out_ctl of blk_ep_out_ctl is
  component blk_out_fifo
  port (
    m_aclk          : in  std_logic;
    s_aclk          : in  std_logic;
    
    s_aresetn       : in  std_logic;
    
    s_axis_tvalid   : in  std_logic;
    s_axis_tready   : out std_logic;
    s_axis_tdata    : in  std_logic_vector(7 downto 0);
    
    m_axis_tvalid   : out std_logic;
    m_axis_tready   : in  std_logic;
    m_axis_tdata    : out std_logic_vector(7 downto 0);
    
    axis_prog_full  : out std_logic
  );
  end component;
  
  signal s_axis_tvalid  : std_logic;
  signal s_axis_tready  : std_logic;
  signal s_axis_tdata   : std_logic_vector(7 downto 0);
      
  signal axis_prog_full : std_logic;
begin
  FULL_LATCH: process(usb_clk) is
  begin
    if rising_edge(usb_clk) then
      blk_xfer_out_ready_read <= NOT axis_prog_full;
    end if;
  end process;
  
  FIFO: blk_out_fifo
  port map (
    m_aclk => axis_clk,
    s_aclk => usb_clk,
    
    s_aresetn => NOT rst,
    
    s_axis_tvalid => blk_xfer_out_data_valid,
    s_axis_tready => open,
    s_axis_tdata => blk_xfer_out_data,
    
    m_axis_tvalid => axis_tvalid,
    m_axis_tready => axis_tready,
    m_axis_tdata => axis_tdata,
    
    axis_prog_full => axis_prog_full
  );
  
  axis_tlast <= '0';
 
end blk_ep_out_ctl;