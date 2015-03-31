--
-- USB Full-Speed/Hi-Speed Device Controller core - extra_pkg.vhdl
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

library work;
use work.USBCore.all;

package USBExtra is
  component blk_ep_out_ctl is
  generic (
    USE_ASYNC_FIFO          : boolean := false
  );
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
  end component;
  
  component blk_ep_in_ctl is
  generic (
    USE_ASYNC_FIFO          : boolean := false
  );
  port (
    rst                     : in  std_logic;
    usb_clk                 : in  std_logic;
    axis_clk                : in  std_logic;

    blk_in_xfer             : in  std_logic;
    
    blk_xfer_in_has_data    : out std_logic;
    blk_xfer_in_data        : out std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : out std_logic;
    blk_xfer_in_data_ready  : in  std_logic;
    blk_xfer_in_data_last   : out std_logic;
    
    axis_tdata              : in  std_logic_vector(7 downto 0);
    axis_tvalid             : in  std_logic;
    axis_tready             : out std_logic;
    axis_tlast              : in  std_logic
  );
  end component;
end USBExtra;