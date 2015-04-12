--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_packet.vhdl
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

entity usb_packet is
  port (
    rst                 : in  std_logic;
    clk                 : in  std_logic;

    axis_rx_tvalid      : in  std_logic;
    axis_rx_tready      : out std_logic;
    axis_rx_tlast       : in  std_logic;
    axis_rx_tdata       : in  std_logic_vector(7 downto 0);

    axis_tx_tvalid      : out std_logic;
    axis_tx_tready      : in  std_logic;
    axis_tx_tlast       : out std_logic;
    axis_tx_tdata       : out std_logic_vector(7 downto 0);

    trn_type            : out std_logic_vector(1 downto 0);
    trn_address         : out std_logic_vector(6 downto 0);
    trn_endpoint        : out std_logic_vector(3 downto 0);
    trn_start           : out std_logic;

    -- DATA0/1/2 MDATA
    rx_trn_data_type    : out std_logic_vector(1 downto 0);
    rx_trn_end          : out std_logic;
    rx_trn_data         : out std_logic_vector(7 downto 0);
    rx_trn_valid        : out std_logic;

    rx_trn_hsk_type     : out std_logic_vector(1 downto 0);
    rx_trn_hsk_received : out std_logic;

    -- 00 - ACK, 10 - NAK, 11 - STALL, 01 - NYET
    tx_trn_hsk_type     : in  std_logic_vector(1 downto 0);
    tx_trn_send_hsk     : in  std_logic;
    tx_trn_hsk_sended   : out std_logic;

    -- DATA0/1/2 MDATA
    tx_trn_data_type    : in  std_logic_vector(1 downto 0);
    -- Set tx_trn_data_last to '1' when start for zero packet
    tx_trn_data_start   : in  std_logic;

    tx_trn_data         : in  std_logic_vector(7 downto 0);
    tx_trn_data_valid   : in  std_logic;
    tx_trn_data_ready   : out std_logic;
    tx_trn_data_last    : in  std_logic;

    start_of_frame      : out std_logic;
    crc_error           : out std_logic;
    device_address      : in  std_logic_vector(6 downto 0)
    );
end usb_packet;

architecture usb_packet of usb_packet is
  type RX_MACHINE is (S_Idle, S_SOF, S_SOFCRC, S_Token, S_TokenCRC, S_Data, S_DataCRC);
  type TX_MACHINE is (S_Idle, S_HSK, S_HSK_Wait, S_DataPID, S_Data, S_DataCRC1, S_DataCRC2);

  function crc5(data : std_logic_vector) return std_logic_vector is
    variable crc : std_logic_vector(4 downto 0);
  begin
    crc(4) := not ('1' xor data(10) xor data(7) xor data(5) xor data(4) xor data(1) xor data(0));
    crc(3) := not ('1' xor data(9) xor data(6) xor data(4) xor data(3) xor data(0));
    crc(2) := not ('1' xor data(10) xor data(8) xor data(7) xor data(4) xor data(3) xor data(2) xor data(1) xor data(0));
    crc(1) := not ('0' xor data(9) xor data(7) xor data(6) xor data(3) xor data(2) xor data(1) xor data(0));
    crc(0) := not ('1' xor data(8) xor data(6) xor data(5) xor data(2) xor data(1) xor data(0));
    return crc;
  end;

  function crc16(d : std_logic_vector; c : std_logic_vector) return std_logic_vector is
    variable crc : std_logic_vector(15 downto 0);
  begin
    crc(0)  := d(0) xor d(1) xor d(2) xor d(3) xor d(4) xor d(5) xor d(6) xor d(7) xor c(8) xor c(9) xor c(10) xor c(11) xor c(12) xor c(13) xor c(14) xor c(15);
    crc(1)  := d(0) xor d(1) xor d(2) xor d(3) xor d(4) xor d(5) xor d(6) xor c(9) xor c(10) xor c(11) xor c(12) xor c(13) xor c(14) xor c(15);
    crc(2)  := d(6) xor d(7) xor c(8) xor c(9);
    crc(3)  := d(5) xor d(6) xor c(9) xor c(10);
    crc(4)  := d(4) xor d(5) xor c(10) xor c(11);
    crc(5)  := d(3) xor d(4) xor c(11) xor c(12);
    crc(6)  := d(2) xor d(3) xor c(12) xor c(13);
    crc(7)  := d(1) xor d(2) xor c(13) xor c(14);
    crc(8)  := d(0) xor d(1) xor c(0) xor c(14) xor c(15);
    crc(9)  := d(0) xor c(1) xor c(15);
    crc(10) := c(2);
    crc(11) := c(3);
    crc(12) := c(4);
    crc(13) := c(5);
    crc(14) := c(6);
    crc(15) := d(0) xor d(1) xor d(2) xor d(3) xor d(4) xor d(5) xor d(6) xor d(7) xor c(7) xor c(8) xor c(9) xor c(10) xor c(11) xor c(12) xor c(13) xor c(14) xor c(15);
    return crc;
  end;

  signal rx_state       : RX_MACHINE := S_Idle;
  signal tx_state       : TX_MACHINE := S_Idle;

  signal rx_crc5        : std_logic_vector(4 downto 0);

  signal rx_pid         : std_logic_vector(3 downto 0);
  signal rx_counter     : std_logic_vector(10 downto 0);

  signal token_data     : std_logic_vector(10 downto 0);
  signal token_crc5     : std_logic_vector(4 downto 0);

  signal rx_crc16       : std_logic_vector(15 downto 0);
  signal rx_data_crc    : std_logic_vector(15 downto 0);

  signal tx_crc16       : std_logic_vector(15 downto 0);
  signal tx_crc16_r     : std_logic_vector(15 downto 0);

  signal rx_buf1        : std_logic_vector(7 downto 0);
  signal rx_buf2        : std_logic_vector(7 downto 0);

  signal tx_zero_packet : std_logic;

begin
  RX_COUNT : process(clk) is
  begin
    if rising_edge(clk) then
      if rx_state = S_Idle then
        rx_counter <= (others => '0');
      elsif axis_rx_tvalid = '1' then
        rx_counter <= rx_counter + 1;
      end if;
    end if;
  end process;

  DATA_CRC_CALC : process(clk) is
  begin
    if rising_edge(clk) then
      if rx_state = S_Idle then
        rx_crc16 <= (others => '1');
      elsif rx_state = S_Data and axis_rx_tvalid = '1' and rx_counter > 1 then
        rx_crc16 <= crc16(rx_buf1, rx_crc16);
      end if;
    end if;
  end process;

  TX_DATA_CRC_CALC : process(clk) is
  begin
    if rising_edge(clk) then
      if tx_state = S_Idle then
        tx_crc16 <= (others => '1');
      elsif tx_state = S_Data and axis_tx_tready = '1' and tx_trn_data_valid = '1' then
        tx_crc16 <= crc16(tx_trn_data, tx_crc16);
      end if;
    end if;
  end process;

  rx_trn_data  <= rx_buf1;
  rx_trn_valid <= '1' when rx_state = S_Data and axis_rx_tvalid = '1' and rx_counter > 1 else
                  '0';

  rx_crc5      <= crc5(token_data);
  rx_data_crc  <= rx_buf2 & rx_buf1;

  trn_address  <= token_data(6 downto 0);
  trn_endpoint <= token_data(10 downto 7);

  RX_FSM : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        start_of_frame      <= '0';
        crc_error           <= '0';
        trn_start           <= '0';
        rx_trn_end          <= '0';
        rx_trn_hsk_received <= '0';
        rx_state            <= S_Idle;
      else
        case rx_state is
          when S_Idle =>
            start_of_frame      <= '0';
            crc_error           <= '0';
            trn_start           <= '0';
            rx_trn_end          <= '0';
            rx_trn_hsk_received <= '0';

            if axis_rx_tvalid = '1' and rx_pid = (not axis_rx_tdata(7 downto 4)) then
              if rx_pid = "0101" then
                rx_state <= S_SOF;
              elsif rx_pid(1 downto 0) = "01" then
                trn_type <= rx_pid(3 downto 2);
                rx_state <= S_Token;
              elsif rx_pid(1 downto 0) = "11" then
                rx_trn_data_type <= rx_pid(3 downto 2);
                rx_state         <= S_Data;
              elsif rx_pid(1 downto 0) = "10" then
                rx_trn_hsk_type     <= rx_pid(3 downto 2);
                rx_trn_hsk_received <= '1';
              end if;
            end if;

          when S_SOF =>
            if axis_rx_tvalid = '1' then
              if rx_counter = 0 then
                token_data(7 downto 0) <= axis_rx_tdata;
              elsif rx_counter = 1 then
                token_data(10 downto 8) <= axis_rx_tdata(2 downto 0);
                token_crc5              <= axis_rx_tdata(7 downto 3);
              end if;
              if axis_rx_tlast = '1' then
                rx_state <= S_SOFCRC;
              end if;
            end if;
            
          when S_SOFCRC =>
            if token_crc5 /= rx_crc5 then
              crc_error <= '1';
            else
              start_of_frame <= '1';
            end if;
            rx_state <= S_Idle;

          when S_Token =>
            if axis_rx_tvalid = '1' then
              if rx_counter = 0 then
                token_data(7 downto 0) <= axis_rx_tdata;
              elsif rx_counter = 1 then
                token_data(10 downto 8) <= axis_rx_tdata(2 downto 0);
                token_crc5              <= axis_rx_tdata(7 downto 3);
              end if;
              if axis_rx_tlast = '1' then
                rx_state <= S_TokenCRC;
              end if;
            end if;
            
          when S_TokenCRC =>
            if device_address = token_data(6 downto 0) then
              if token_crc5 = rx_crc5 then
                trn_start <= '1';
              else
                crc_error <= '1';
              end if;
            end if;
            rx_state <= S_Idle;

          when S_Data =>
            if axis_rx_tvalid = '1' then
              if rx_counter = 0 then
                rx_buf1 <= axis_rx_tdata;
              elsif rx_counter = 1 then
                rx_buf2 <= axis_rx_tdata;
              else
                rx_buf1 <= rx_buf2;
                rx_buf2 <= axis_rx_tdata;
              end if;
              if axis_rx_tlast = '1' then
                rx_state <= S_DataCRC;
              end if;
            end if;
              
          when S_DataCRC =>
            rx_trn_end <= '1';
            if rx_data_crc /= rx_crc16 then
              crc_error <= '1';
            end if;
            rx_state <= S_Idle;

        end case;
      end if;
    end if;
  end process;

  TX_FSM : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tx_state <= S_Idle;
      else
        case tx_state is
          when S_Idle =>
            if tx_trn_send_hsk = '1' then
              tx_state <= S_HSK;
            elsif tx_trn_data_start = '1' then
              if tx_trn_data_last = '1' and tx_trn_data_valid = '0' then
                tx_zero_packet <= '1';
              else
                tx_zero_packet <= '0';
              end if;
              tx_state       <= S_DataPID;
            end if;

          when S_HSK =>
            if axis_tx_tready = '1' then
              tx_state <= S_HSK_Wait;
            end if;

          when S_HSK_Wait =>
            if tx_trn_send_hsk = '0' then
              tx_state <= S_Idle;
            end if;

          when S_DataPID =>
            if axis_tx_tready = '1' then
              if tx_zero_packet = '1' then
                tx_state <= S_DataCRC1;
              else
                tx_state <= S_Data;
              end if;
            end if;

          when S_Data =>
            if axis_tx_tready = '1' and tx_trn_data_valid = '1' then
              if tx_trn_data_last = '1' then
                tx_state <= S_DataCRC1;
              end if;
            elsif tx_trn_data_valid = '0' then
              tx_state <= S_DataCRC2;
            end if;

          when S_DataCRC1 =>
            if axis_tx_tready = '1' then
              tx_state <= S_DataCRC2;
            end if;

          when S_DataCRC2 =>
            if axis_tx_tready = '1' then
              tx_state <= S_Idle;
            end if;

        end case;
      end if;
    end if;
  end process;

  axis_tx_tdata <= (not (tx_trn_data_type & "11")) & tx_trn_data_type & "11" when tx_state = S_DataPID else
                   (not (tx_trn_hsk_type & "10")) & tx_trn_hsk_type & "10" when tx_state = S_HSK else
                   tx_crc16_r(7 downto 0)                                  when tx_state = S_DataCRC1 or (tx_state = S_Data and tx_trn_data_valid = '0') else
                   tx_crc16_r(15 downto 8)                                 when tx_state = S_DataCRC2 else
                   tx_trn_data;

  axis_tx_tvalid <= '1' when tx_state = S_DataPID or tx_state = S_HSK or tx_state = S_DataCRC1 or tx_state = S_DataCRC2 else
                    '1' when tx_state = S_Data else
                    '0';

  axis_tx_tlast <= '1' when tx_state = S_HSK else
                   '1' when tx_state = S_DataCRC2 else
                   '0';

  tx_trn_data_ready <= axis_tx_tready when tx_state = S_Data else
                       '0';

  tx_trn_hsk_sended <= '1' when tx_state = S_HSK_Wait else
                       '0';

  tx_crc16_r <= (not (tx_crc16(0) & tx_crc16(1) & tx_crc16(2) & tx_crc16(3) &
                      tx_crc16(4) & tx_crc16(5) & tx_crc16(6) & tx_crc16(7) &
                      tx_crc16(8) & tx_crc16(9) & tx_crc16(10) & tx_crc16(11) &
                      tx_crc16(12) & tx_crc16(13) & tx_crc16(14) & tx_crc16(15)));

  rx_pid         <= axis_rx_tdata(3 downto 0);

  axis_rx_tready <= '1';
end usb_packet;
