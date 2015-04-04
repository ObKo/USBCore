--
-- USB Full-Speed/Hi-Speed Device Controller core - blk_ep_in_ctl.vhdl
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

library work;
use work.USBCore.all;
use work.USBExtra.all;

entity blk_ep_in_ctl is
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
end blk_ep_in_ctl;

architecture blk_ep_in_ctl of blk_ep_in_ctl is
  component blk_in_fifo
  port (
    m_aclk          : in  std_logic;
    s_aclk          : in  std_logic;
    
    s_aresetn       : in  std_logic;
    
    s_axis_tvalid   : in  std_logic;
    s_axis_tready   : out std_logic;
    s_axis_tdata    : in  std_logic_vector(7 downto 0);
    s_axis_tlast    : in  std_logic;
    
    m_axis_tvalid   : out std_logic;
    m_axis_tready   : in  std_logic;
    m_axis_tdata    : out std_logic_vector(7 downto 0);
    m_axis_tlast    : in std_logic;
    
    axis_prog_full  : out std_logic
  );
  end component;
  
  type MACHINE is (S_Idle, S_Xfer);
  signal state          : MACHINE := S_Idle;
  
  signal s_axis_tvalid  : std_logic;
  signal s_axis_tready  : std_logic;
  signal s_axis_tdata   : std_logic_vector(7 downto 0);
  signal s_axis_tlast   : std_logic;
    
  signal m_axis_tvalid  : std_logic;
  signal m_axis_tready  : std_logic;
  signal m_axis_tdata   : std_logic_vector(7 downto 0);
  signal m_axis_tlast   : std_logic;
  
  signal prog_full      : std_logic;
  
  signal was_last_usb   : std_logic;
  signal was_last       : std_logic;
  signal was_last_d     : std_logic;
  signal was_last_dd    : std_logic;
begin  
  FSM: process(usb_clk) is
  begin
    if rst = '1' then
      state <= S_Idle;
      blk_xfer_in_has_data <= '0';
    elsif rising_edge(usb_clk) then
      case state is
        when S_Idle =>
          if was_last_usb = '1' OR prog_full = '1' then
            blk_xfer_in_has_data <= '1';
          end if;
          if blk_in_xfer = '1' then
            state <= S_Xfer;
          end if;
          
        when S_Xfer =>
          if blk_in_xfer = '0' then
            blk_xfer_in_has_data <= '0';
            state <= S_Idle;
          end if; 
      end case;          
    end if;
  end process;
   
  ASYNC: if USE_ASYNC_FIFO generate
    -- 3 of data clk => axis_clk < 180 MHz if usb_clk = 60 MHz
    was_last_usb <= was_last OR was_last_d OR was_last_dd;
    
    FIFO: blk_in_fifo
    port map (
      m_aclk => usb_clk,
      s_aclk => axis_clk,
    
      s_aresetn => NOT rst,
    
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tdata => s_axis_tdata,
      s_axis_tlast => s_axis_tlast,
    
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      m_axis_tdata => m_axis_tdata,
      m_axis_tlast => m_axis_tlast,
    
      axis_prog_full => prog_full
    );
  end generate;
  
  SYNC: if not USE_ASYNC_FIFO generate
    was_last_usb <= was_last;
    
    FIFO: sync_fifo
    generic map (
      FIFO_WIDTH => 8,
      FIFO_DEPTH => 1024,
      PROG_FULL_VALUE => 64
    )
    port map (
      clk => usb_clk,
      rst => rst,
    
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tdata => s_axis_tdata,
      s_axis_tlast => s_axis_tlast,
    
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      m_axis_tdata => m_axis_tdata,
      m_axis_tlast => m_axis_tlast,
    
      prog_full => prog_full
    );
  end generate;
  
  WAS_LAST_LATCHER: process(axis_clk) is
  begin
    if rst = '1' then
      was_last <= '0';
      was_last_d <= '0';
      was_last_dd <= '0';
    elsif rising_edge(axis_clk) then
      if s_axis_tvalid = '1' AND s_axis_tready = '1' AND s_axis_tlast = '1' then
        was_last <= '1';
      elsif s_axis_tvalid = '1' AND s_axis_tready = '1' AND s_axis_tlast = '0' then
        was_last <= '0';
      end if;
      was_last_d <= was_last;
      was_last_dd <= was_last_d;
    end if;
  end process;
  
  s_axis_tdata <= axis_tdata;
  s_axis_tvalid <= axis_tvalid;
  axis_tready <= s_axis_tvalid;
  s_axis_tlast <= axis_tlast;
  
  blk_xfer_in_data <= m_axis_tdata;
  blk_xfer_in_data_valid <= m_axis_tvalid;
  m_axis_tready <= blk_xfer_in_data_ready;
  blk_xfer_in_data_last <= m_axis_tlast;
   
end blk_ep_in_ctl;