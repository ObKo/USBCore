--
-- USB Full-Speed/Hi-Speed Device Controller core - sync_fifo.vhdl
--
-- Copyright (c) 2015 Konstantin Oblaukhov
-- Copyright (c) 2015 daniel@deathbylogic.com
--   http://www.deathbylogic.com/2015/01/vhdl-first-word-fall-through-fifo/
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
use IEEE.NUMERIC_STD.all;

library work;
use work.USBCore.all;

entity sync_fifo is
  generic (
    constant FIFO_WIDTH     : positive := 8;
    constant FIFO_DEPTH     : positive := 256;
    constant PROG_FULL_VALUE: positive := 128
    );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tdata  : in  std_logic_vector(FIFO_WIDTH - 1 downto 0);
    s_axis_tlast  : in  std_logic;
    
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tdata  : out std_logic_vector(FIFO_WIDTH - 1 downto 0);
    m_axis_tlast  : out std_logic;
    
    prog_full     : out std_logic
    );
end sync_fifo;

architecture sync_fifo of sync_fifo is
  type FIFO_MEMORY is array (0 to FIFO_DEPTH - 1) of std_logic_vector (FIFO_WIDTH downto 0);
  signal memory : FIFO_MEMORY;
  
  subtype ADDRESS_TYPE is natural range 0 to FIFO_DEPTH - 1;
  
  signal rd_addr        : ADDRESS_TYPE;
  signal wr_addr        : ADDRESS_TYPE;
  
  signal mem_we         : std_logic;
  signal mem_in         : std_logic_vector(FIFO_WIDTH downto 0);
  signal mem_out        : std_logic_vector(FIFO_WIDTH downto 0);
  
  signal buf_we         : std_logic;
  signal buf            : std_logic_vector(FIFO_WIDTH downto 0);
  signal buf_valid      : std_logic;
  
  signal full           : std_logic;
  signal empty          : std_logic;
  signal empty_d        : std_logic;
  signal empty_dd       : std_logic;
  signal looped         : std_logic;
  
  signal count          : ADDRESS_TYPE;
  
  signal first          : std_logic;
begin
  -- That structure guaranteed that dual-port BRAM will be inferred.
  -- At least on Xilinx...
  mem_we <= '1' when s_axis_tvalid = '1' and full = '0' else
            '0';            
  mem_in <= s_axis_tlast & s_axis_tdata;
  
  MEM_PROC: process(clk) is
  begin
    if rising_edge(clk) then
      mem_out <= memory(rd_addr);
      if mem_we = '1' then
        memory(wr_addr) <= mem_in;
      end if;
    end if;
  end process;
  
  -- Sync empty signal with memory reading
  EMPTY_OUT: process(clk) is
  begin
    if rising_edge(clk) then
      empty_d <= empty;
      empty_dd <= empty_d;
    end if;
  end process;
  
  FWFT_BUF: process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        buf_valid <= '0';
      else
        if buf_we = '1' then
          buf <= mem_out;
          buf_valid <= '1';
        elsif buf_valid = '1' and m_axis_tready = '1' then
          buf_valid <= '0';
        end if;
      end if;
    end if;
  end process;
  
  
  
  FIFO_PROC: process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_addr <= 0;
        rd_addr <= 0;
        looped <= '0';
      else
        if mem_we = '1' then
          if wr_addr = FIFO_DEPTH - 1 then
            wr_addr <= 0;
            looped <= '1';
          else
            wr_addr <= wr_addr + 1;
          end if;
        end if;
        if (empty = '0' and m_axis_tready = '1') or first = '1' then
          if rd_addr = FIFO_DEPTH - 1 then
            rd_addr <= 0;
            looped <= '0';
          else
            rd_addr <= rd_addr + 1;
          end if;
        end if;
        if buf_valid = '1' then
          if count >= PROG_FULL_VALUE - 1 then
            prog_full <= '1';
          else
            prog_full <= '0';
          end if;
        else
          if count >= PROG_FULL_VALUE then
            prog_full <= '1';
          else
            prog_full <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
  
  count <= FIFO_DEPTH - rd_addr + wr_addr when looped = '1' else
           wr_addr - rd_addr;
  
  first <= '1' when empty_d = '0' and buf_valid = '0' and empty_dd = '1' else
           '0';
  
  buf_we <= '1' when first = '1' else
            '1' when empty_d = '0' and buf_valid = '0' and m_axis_tready = '0' else
            '0';
  
  full <= '1' when looped = '1' AND wr_addr = rd_addr else
          '0';
          
  empty <= '1' when looped = '0' AND wr_addr = rd_addr else
           '0';

  m_axis_tdata <= buf(FIFO_WIDTH - 1 downto 0) when buf_valid = '1' else
                  mem_out(FIFO_WIDTH - 1 downto 0);
  m_axis_tlast <= buf(FIFO_WIDTH) when buf_valid = '1' else
                  mem_out(FIFO_WIDTH);
  m_axis_tvalid <= (((NOT empty_dd) AND (NOT empty_d)) OR buf_valid);
  
  s_axis_tready <= NOT full;
end sync_fifo;
