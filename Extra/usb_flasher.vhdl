--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_flasher.vhdl
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
use work.USBExtra.all;

entity usb_flasher is
  port (
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
end usb_flasher;

architecture usb_flasher of usb_flasher is
  type FLASH_MACHINE is (S_Idle, S_WriteCommand, S_ReadResponse, S_CtlResponse, S_CtlStartReceive,
                         S_CtlReceive, S_WriteData, S_Wait, S_ReadResponseLast, S_PageProg, 
                         S_PageRead, S_PageReadLast);
  type SPI_MACHINE is (S_Idle, S_Xfer);

  signal spi_state            : SPI_MACHINE;
  signal flash_state          : FLASH_MACHINE;

  signal flash_clk            : std_logic := '0';
  signal flash_clk180         : std_logic;

  signal clk_en               : std_logic;

  signal out_data             : std_logic_vector(7 downto 0);
  signal in_data              : std_logic_vector(7 downto 0);
  signal in_data_valid        : std_logic;

  signal recieve_data         : std_logic;
  signal recieve_data_d       : std_logic;

  signal out_reg              : std_logic_vector(7 downto 0);
  signal in_reg               : std_logic_vector(7 downto 0);
  signal in_latch             : std_logic;

  signal is_edge              : std_logic;

  signal xfer_count           : std_logic_vector(2 downto 0);
  signal xfer_last            : std_logic;
  signal xfer_valid           : std_logic;

  signal flash_cmd            : std_logic_vector(7 downto 0);
  signal flash_resp_size      : std_logic_vector(2 downto 0);

  signal flash_xfer_count     : std_logic_vector(7 downto 0);
  signal flash_xfer_max_count : std_logic_vector(7 downto 0);

  signal data_dir             : std_logic;
  signal page_prog            : std_logic;
  signal page_read            : std_logic;

  signal ctl_wr_addr          : std_logic_vector(1 downto 0);
  signal ctl_rd_addr          : std_logic_vector(1 downto 0);
  signal ctl_buf              : BYTE_ARRAY(0 to 3);
  
  signal blk_out_tvalid       : std_logic;
  signal blk_out_tready       : std_logic;
  signal blk_out_tdata        : std_logic_vector(7 downto 0);
  signal blk_out_tlast        : std_logic;
  
  signal blk_in_tvalid        : std_logic;
  signal blk_in_tready        : std_logic;
  signal blk_in_tdata         : std_logic_vector(7 downto 0);
  signal blk_in_tlast         : std_logic;

begin
  OUT_ENDPOINT: blk_ep_out_ctl
  generic map (
    USE_ASYNC_FIFO => false
  )
  port map (
    rst => rst,
    usb_clk => clk,
    axis_clk => clk,
    
    blk_out_xfer => blk_out_xfer,

    blk_xfer_out_ready_read => blk_xfer_out_ready_read,
    blk_xfer_out_data => blk_xfer_out_data,
    blk_xfer_out_data_valid => blk_xfer_out_data_valid,
    
    axis_tdata => blk_out_tdata,
    axis_tvalid => blk_out_tvalid,
    axis_tready => blk_out_tready,
    axis_tlast => blk_out_tlast
  );
  
  IN_ENDPOINT: blk_ep_in_ctl
  generic map (
    USE_ASYNC_FIFO => false
  )
  port map (
    rst => rst,
    usb_clk => clk,
    axis_clk => clk,

    blk_in_xfer => blk_in_xfer,
    
    blk_xfer_in_has_data => blk_xfer_in_has_data,
    blk_xfer_in_data => blk_xfer_in_data,
    blk_xfer_in_data_valid => blk_xfer_in_data_valid,
    blk_xfer_in_data_ready => blk_xfer_in_data_ready,
    blk_xfer_in_data_last => blk_xfer_in_data_last,
    
    axis_tdata => blk_in_tdata,
    axis_tvalid => blk_in_tvalid,
    axis_tready => blk_in_tready,
    axis_tlast => blk_in_tlast
  );

  flash_clk180 <= not flash_clk;

  CLK_GEN : process(clk) is
  begin
    if rising_edge(clk) then
      if spi_state = S_Xfer then
        flash_clk <= not flash_clk;
      else
        flash_clk <= '0';
      end if;
    end if;
  end process;

  is_edge <= flash_clk;

  SPI_OUT : process(clk) is
  begin
    if rising_edge(clk) then
      if (spi_state = S_Idle and xfer_valid = '1') or
        (spi_state = S_Xfer and xfer_count = "000" and xfer_valid = '1' and is_edge = '1') then
        out_reg <= out_data;
      elsif is_edge = '1' and spi_state = S_Xfer then
        out_reg(7) <= out_reg(6);
        out_reg(6) <= out_reg(5);
        out_reg(5) <= out_reg(4);
        out_reg(4) <= out_reg(3);
        out_reg(3) <= out_reg(2);
        out_reg(2) <= out_reg(1);
        out_reg(1) <= out_reg(0);
      end if;
    end if;
  end process;

  SPI_IN : process(clk) is
  begin
    if rising_edge(clk) then
      --if (spi_state = S_Idle AND xfer_valid = '1') OR 
      --   (spi_state = S_Xfer AND xfer_count = "000" AND xfer_valid = '1' AND is_edge = '1') then
      --   out_reg <= out_data;
      if is_edge = '1' and spi_state = S_Xfer then
        in_reg(7) <= in_reg(6);
        in_reg(6) <= in_reg(5);
        in_reg(5) <= in_reg(4);
        in_reg(4) <= in_reg(3);
        in_reg(3) <= in_reg(2);
        in_reg(2) <= in_reg(1);
        in_reg(1) <= in_reg(0);
        in_reg(0) <= spi_miso;
      end if;

      recieve_data_d <= recieve_data;

      if is_edge = '1' and spi_state = S_Xfer and xfer_count = "000" and recieve_data_d = '1' then
        in_latch <= '1';
      else
        in_latch <= '0';
      end if;

      if in_latch = '1' then
        in_data       <= in_reg;
        in_data_valid <= '1';
      else
        in_data_valid <= '0';
      end if;

    end if;
  end process;

  SPI_FSM : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        spi_state <= S_Idle;
      else
        case spi_state is
          when S_Idle =>
            if xfer_valid = '1' then
              spi_state  <= S_Xfer;
              xfer_count <= (others => '0');
            end if;

          when S_Xfer =>
            if is_edge = '0' then
              xfer_count <= xfer_count + 1;
            else
              if xfer_count = "000" then
                if xfer_valid = '0' then
                  spi_state <= S_Idle;
                end if;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  CTL_BUFFER : process(clk) is
  begin
    if rising_edge(clk) then
      if flash_state = S_Idle then
        ctl_wr_addr <= (others => '0');
        ctl_rd_addr <= (others => '0');
      elsif flash_state = S_ReadResponse or flash_state = S_ReadResponseLast then
        if in_data_valid = '1' then
          ctl_buf(to_integer(unsigned(ctl_wr_addr))) <= in_data;
          ctl_wr_addr                                <= ctl_wr_addr + 1;
        end if;
      elsif flash_state = S_CtlResponse then
        if ctl_xfer_data_in_ready = '1' then
          ctl_rd_addr <= ctl_rd_addr + 1;
        end if;
      elsif flash_state = S_CtlReceive then
        if ctl_xfer_data_out_valid = '1' then
          ctl_buf(to_integer(unsigned(ctl_wr_addr))) <= ctl_xfer_data_out;
          ctl_wr_addr                                <= ctl_wr_addr + 1;
        end if;
      elsif flash_state = S_WriteData then
        if xfer_last = '1' then
          ctl_rd_addr <= ctl_rd_addr + 1;
        end if;
      end if;
    end if;
  end process;

  FLASH_FSM : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        flash_state <= S_Idle;
      else
        case flash_state is
          when S_Idle =>
            if ctl_xfer = '1' then
              data_dir <= ctl_xfer_type(7);
              if ctl_xfer_request(7 downto 2) = "000001" then
                flash_cmd       <= ctl_xfer_value(7 downto 0);
                flash_resp_size <= ctl_xfer_length(2 downto 0);

                if ctl_xfer_type(7) = '1' then
                  flash_state <= S_WriteCommand;
                else
                  flash_state <= S_CtlStartReceive;
                end if;
                
                if ctl_xfer_request(0) = '1' then
                  page_prog <= '1';
                else
                  page_prog <= '0';
                end if;
                
                if ctl_xfer_request(1) = '1' then
                  page_read <= '1';
                else
                  page_read <= '0';
                end if;

                ctl_xfer_accept <= '1';
                ctl_xfer_done   <= '0';
              else
                ctl_xfer_accept <= '0';
                ctl_xfer_done   <= '1';
              end if;
            else
              ctl_xfer_accept <= '0';
              ctl_xfer_done   <= '1';
            end if;

          when S_WriteCommand =>
            if xfer_last = '1' then
              if flash_resp_size = 0 then
                flash_state <= S_Wait;
              else
                flash_xfer_count <= flash_xfer_max_count;
                if data_dir = '1' then
                  flash_state <= S_ReadResponse;
                else
                  flash_state <= S_WriteData;
                end if;
              end if;
            end if;

          when S_ReadResponse =>
            if xfer_last = '1' then
              if flash_xfer_count = 0 then
                flash_state <= S_ReadResponseLast;
              else
                flash_xfer_count <= flash_xfer_count - 1;
              end if;
            end if;

          when S_ReadResponseLast =>
            if in_data_valid = '1' then
              flash_xfer_count <= flash_xfer_max_count;
              ctl_xfer_done    <= '1';
              flash_state      <= S_CtlResponse;
            end if;

          when S_CtlResponse =>
            if ctl_xfer_data_in_ready = '1' then
              if flash_xfer_count = 0 then
                flash_state <= S_Wait;
              else
                flash_xfer_count <= flash_xfer_count - 1;
              end if;
            end if;

          when S_CtlStartReceive =>
            if flash_resp_size > 0 then
              flash_xfer_count <= flash_xfer_max_count;
              flash_state      <= S_CtlReceive;
            else
              flash_state <= S_WriteCommand;
            end if;

          when S_CtlReceive =>
            if ctl_xfer_data_out_valid = '1' then
              if flash_xfer_count = 0 then
                flash_state <= S_WriteCommand;
              else
                flash_xfer_count <= flash_xfer_count - 1;
              end if;
            end if;

          when S_WriteData =>
            if xfer_last = '1' then
              if flash_xfer_count = 0 then
                if page_prog = '0' and page_read = '0' then
                  flash_state <= S_Wait;
                elsif page_prog = '1' and blk_out_tvalid = '0' then
                  flash_state <= S_Wait;
                elsif page_prog = '1' then
                  flash_state <= S_PageProg;
                elsif page_read = '1' then
                  flash_xfer_count <= (others => '1');
                  flash_state <= S_PageRead;
                end if;
              else
                flash_xfer_count <= flash_xfer_count - 1;
              end if;
            end if;

          when S_Wait =>
            ctl_xfer_done <= '1';
            if ctl_xfer = '0' then
              flash_state <= S_Idle;
            end if;
            
          when S_PageProg =>
            if xfer_last = '1' then
              if blk_out_tvalid = '0' then
                flash_state <= S_Wait;
              end if;
            end if;
            
          when S_PageRead =>
            if xfer_last = '1' then
              if flash_xfer_count = 0 then
                flash_state <= S_PageReadLast;
              else
                flash_xfer_count <= flash_xfer_count - 1;
              end if;
            end if;
            
          when S_PageReadLast =>
            if in_data_valid = '1' then
              flash_state <= S_Wait;
            end if;

        end case;
      end if;
    end if;
  end process;

  flash_xfer_max_count <= "00000" & (flash_resp_size - 1);  --when flash_state = S_ReadResponseLast OR flash_state = S_WriteCommand

  out_data <= ctl_buf(to_integer(unsigned(ctl_rd_addr))) when flash_state = S_WriteData else
              blk_out_tdata when flash_state = S_PageProg else
              flash_cmd;

  xfer_valid <= '1' when flash_state = S_WriteCommand or flash_state = S_ReadResponse or 
                         flash_state = S_WriteData or flash_state = S_PageProg or
                         flash_state = S_PageRead else
                '0';

  recieve_data <= '1' when flash_state = S_ReadResponse or flash_state = S_PageRead else
                  '0';

  xfer_last <= '1' when xfer_count = "111" and is_edge = '0' else
               '0';

  ctl_xfer_data_in <= ctl_buf(to_integer(unsigned(ctl_rd_addr)));
  ctl_xfer_data_in_valid <= '1' when flash_state = S_CtlResponse else
                            '0';
  ctl_xfer_data_in_last <= '1' when flash_state = S_CtlResponse and flash_xfer_count = 0 else
                           '0';
                           
  blk_out_tready <= '1' when flash_state = S_PageProg and xfer_count = "000" and is_edge = '1' else
                    '0';
                    
  blk_in_tlast <= '1' when flash_state = S_PageReadLast else
                  '0';
  blk_in_tdata <= in_data;
  blk_in_tvalid <= in_data_valid when flash_state = S_PageRead or flash_state = S_PageReadLast else
                   '0';

  spi_mosi <= out_reg(7);
  spi_sck  <= flash_clk;
  spi_cs   <= '0' when spi_state = S_Xfer else
            '1';

end usb_flasher;
