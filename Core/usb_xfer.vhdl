--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_xfer.vhdl
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

entity usb_xfer is
  generic (
    HIGH_SPEED:  boolean := true
  );
  port (
    rst                     : in  std_logic;
    clk                     : in  std_logic;

    trn_type                : in  std_logic_vector(1 downto 0);
    trn_address             : in  std_logic_vector(6 downto 0);
    trn_endpoint            : in  std_logic_vector(3 downto 0);
    trn_start               : in  std_logic;

    -- DATA0/1/2 MDATA
    rx_trn_data_type        : in  std_logic_vector(1 downto 0);
    rx_trn_end              : in  std_logic;
    rx_trn_data             : in  std_logic_vector(7 downto 0);
    rx_trn_valid            : in  std_logic;

    rx_trn_hsk_type         : in  std_logic_vector(1 downto 0);
    rx_trn_hsk_received     : in  std_logic;

    -- 00 - ACK, 10 - NAK, 11 - STALL, 01 - NYET
    tx_trn_hsk_type         : out std_logic_vector(1 downto 0);
    tx_trn_send_hsk         : out std_logic;
    tx_trn_hsk_sended       : in  std_logic;

    tx_trn_data_type        : out std_logic_vector(1 downto 0);
    tx_trn_data_start       : out std_logic;

    tx_trn_data             : out std_logic_vector(7 downto 0);
    tx_trn_data_valid       : out std_logic;
    tx_trn_data_ready       : in  std_logic;
    tx_trn_data_last        : out std_logic;

    crc_error               : in  std_logic;

    ctl_xfer_endpoint       : out std_logic_vector(3 downto 0);
    ctl_xfer_type           : out std_logic_vector(7 downto 0);
    ctl_xfer_request        : out std_logic_vector(7 downto 0);
    ctl_xfer_value          : out std_logic_vector(15 downto 0);
    ctl_xfer_index          : out std_logic_vector(15 downto 0);
    ctl_xfer_length         : out std_logic_vector(15 downto 0);
    ctl_xfer_accept         : in  std_logic;
    -- '1' when processing control transfer
    ctl_xfer                : out std_logic;
    -- '1' when control request completed
    ctl_xfer_done           : in  std_logic;

    ctl_xfer_data_out       : out std_logic_vector(7 downto 0);
    ctl_xfer_data_out_valid : out std_logic;

    ctl_xfer_data_in        : in  std_logic_vector(7 downto 0);
    ctl_xfer_data_in_valid  : in  std_logic;
    ctl_xfer_data_in_last   : in  std_logic;
    ctl_xfer_data_in_ready  : out std_logic;

    blk_xfer_endpoint       : out std_logic_vector(3 downto 0);
    blk_in_xfer             : out std_logic;
    blk_out_xfer            : out std_logic;

    -- Has complete packet
    blk_xfer_in_has_data    : in  std_logic;
    blk_xfer_in_data        : in  std_logic_vector(7 downto 0);
    blk_xfer_in_data_valid  : in  std_logic;
    blk_xfer_in_data_ready  : out std_logic;
    blk_xfer_in_data_last   : in  std_logic;

    -- Can accept full packet
    blk_xfer_out_ready_read : in  std_logic;
    blk_xfer_out_data       : out std_logic_vector(7 downto 0);
    blk_xfer_out_data_valid : out std_logic
    );
end usb_xfer;

architecture usb_xfer of usb_xfer is
  type MACHINE is (S_Idle, S_ControlSetup, S_ControlSetupACK, S_ControlWaitDataIN,
                   S_ControlDataIN, S_ControlDataIN_Z, S_ControlDataIN_ACK, S_ControlWaitDataOUT,
                   S_ControlDataOUT, S_ControlDataOUT_MyACK, S_ControlStatusOUT, S_ControlStatusOUT_D,
                   S_ControlStatusOUT_ACK, S_ControlStatusIN, S_ControlStatusIN_MyACK, S_ControlStatusIN_D,
                   S_ControlStatusIN_ACK, S_BulkIN, S_BulkIN_MyACK, S_BulkIN_ACK, S_BulkOUT,
                   S_BulkOUT_ACK);
                                      
  signal state               : MACHINE := S_Idle;

  signal rx_counter          : std_logic_vector(10 downto 0);
  signal tx_counter          : std_logic_vector(15 downto 0);

  signal ctl_xfer_length_int : std_logic_vector(15 downto 0);
  signal ctl_xfer_type_int   : std_logic_vector(7 downto 0);

  signal data_types          : std_logic_vector(15 downto 0);
  signal current_endpoint    : std_logic_vector(3 downto 0);

  signal ctl_status          : std_logic_vector(1 downto 0);
  signal ctl_xfer_eop        : std_logic;
  
  signal tx_counter_over     : std_logic;
  
begin
  RX_DATA_COUNT : process(clk) is
  begin
    if rising_edge(clk) then
      if state = S_Idle or state = S_ControlSetupACK then
        rx_counter <= (others => '0');
      elsif rx_trn_valid = '1' then
        rx_counter <= rx_counter + 1;
      end if;
    end if;
  end process;

  BIT_TOGGLING : process(clk) is
    variable i : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        data_types <= (others => '0');
      else
        i := to_integer(unsigned(current_endpoint));
        if state = S_ControlSetupACK then
          data_types(i) <= '1';
        elsif state = S_ControlDataIN_ACK then
          if rx_trn_hsk_received = '1' and rx_trn_hsk_type = "00" then
            data_types(i) <= not data_types(i);
          end if;
        elsif state = S_ControlStatusIN_ACK then
          if rx_trn_hsk_received = '1' and rx_trn_hsk_type = "00" then
            data_types(i) <= not data_types(i);
          end if;
        elsif state = S_BulkIN_ACK then
          if rx_trn_hsk_received = '1' and rx_trn_hsk_type = "00" then
            data_types(i) <= not data_types(i);
          end if;
        elsif state = S_BulkOUT_ACK then
          if tx_trn_hsk_sended = '1' and ctl_status = "00" then
            data_types(i) <= not data_types(i);
          end if;
        end if;
      end if;
    end if;
  end process;

  FSM : process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_Idle;
        ctl_xfer <= '0';
      else
        case state is
          when S_Idle =>
            ctl_xfer     <= '0';
            blk_in_xfer  <= '0';
            blk_out_xfer <= '0';

            if trn_start = '1' then
              if trn_type = "11" then
                state            <= S_ControlSetup;
                current_endpoint <= trn_endpoint;
              elsif trn_type = "10" then
                current_endpoint <= trn_endpoint;
                if blk_xfer_in_has_data = '1' then
                  blk_in_xfer       <= '1';
                  tx_trn_data_start <= '1';
                  tx_counter        <= (others => '0');
                  state             <= S_BulkIN;
                else
                  ctl_status <= "11";
                  state      <= S_BulkIN_MyACK;
                end if;
              elsif trn_type = "00" then
                blk_out_xfer     <= '1';
                current_endpoint <= trn_endpoint;
                if blk_xfer_out_ready_read = '1' then
                  ctl_status <= "00";
                else
                  ctl_status <= "11";
                end if;
                state <= S_BulkOUT;
              end if;
            end if;

          when S_ControlSetup =>
            if rx_trn_valid = '1' then
              if rx_counter = 0 then
                ctl_xfer_type_int <= rx_trn_data;
              elsif rx_counter = 1 then
                ctl_xfer_request <= rx_trn_data;
              elsif rx_counter = 2 then
                ctl_xfer_value(7 downto 0) <= rx_trn_data;
              elsif rx_counter = 3 then
                ctl_xfer_value(15 downto 8) <= rx_trn_data;
              elsif rx_counter = 4 then
                ctl_xfer_index(7 downto 0) <= rx_trn_data;
              elsif rx_counter = 5 then
                ctl_xfer_index(15 downto 8) <= rx_trn_data;
              elsif rx_counter = 6 then
                ctl_xfer_length_int(7 downto 0) <= rx_trn_data;
              elsif rx_counter = 7 then
                ctl_xfer_length_int(15 downto 8) <= rx_trn_data;
                state                            <= S_ControlSetupACK;
                ctl_xfer                         <= '1';
              end if;
            end if;

          when S_ControlSetupACK =>
            if tx_trn_hsk_sended = '1' then
              if ctl_xfer_length_int = 0 then
                if ctl_xfer_type_int(7) = '1' then
                  state <= S_ControlStatusOUT;
                else
                  state <= S_ControlStatusIN;
                end if;
              elsif ctl_xfer_type_int(7) = '1' then
                state      <= S_ControlWaitDataIN;
                tx_counter <= (others => '0');
              elsif ctl_xfer_type_int(7) = '0' then
                state      <= S_ControlWaitDataOUT;
              end if;
            end if;

          when S_ControlWaitDataIN =>
            -- IN Token
            if trn_start = '1' and trn_type = "10" then
              if ctl_xfer_accept = '1' then
                state <= S_ControlDataIN;
              else
                state <= S_ControlDataIN_Z;
              end if;
              tx_trn_data_start <= '1';
            end if;
            
          when S_ControlWaitDataOUT =>
            -- OUT Token
            if trn_start = '1' and trn_type = "00" then
              if ctl_xfer_accept = '1' then
                ctl_status <= "00";
              else
                ctl_status <= "10";
              end if;
              state <= S_ControlDataOUT;
            end if;
            
          when S_ControlDataOUT =>
            if rx_trn_valid = '1' or rx_trn_end = '1' then
              if rx_counter(5 downto 0) = 63 or rx_counter = ctl_xfer_length_int - 1 or rx_trn_end = '1' then
                state <= S_ControlDataOUT_MyACK;
              end if;
            end if;
            
          when S_ControlDataOUT_MyACK =>
            if tx_trn_hsk_sended = '1' then
              if rx_counter = ctl_xfer_length_int then
                state <= S_ControlStatusIN;
              else
                state <= S_ControlWaitDataOUT;
              end if;
            end if;

          when S_ControlDataIN =>
            if ctl_xfer_data_in_valid = '1' and tx_trn_data_ready = '1' then
              if tx_counter(5 downto 0) = 63 or tx_counter = ctl_xfer_length_int - 1 or
                ctl_xfer_data_in_last = '1' then
                tx_trn_data_start <= '0';
                state             <= S_ControlDataIN_ACK;
                if ctl_xfer_data_in_last = '1' then
                  ctl_xfer_eop <= '1';
                end if;
              end if;
              tx_counter <= tx_counter + 1;
            end if;

          when S_ControlDataIN_Z =>
            tx_trn_data_start <= '0';
            ctl_xfer_eop      <= '1';
            state             <= S_ControlDataIN_ACK;

          when S_ControlDataIN_ACK =>
            if rx_trn_hsk_received = '1' then
              if rx_trn_hsk_type = "00" then
                if tx_counter = ctl_xfer_length_int or ctl_xfer_eop = '1' then
                  ctl_xfer_eop <= '0';
                  state        <= S_ControlStatusOUT;
                else
                  state <= S_ControlWaitDataIN;
                end if;
              else
                state <= S_Idle;
              end if;
            end if;

          when S_ControlStatusOUT =>
            -- OUT Token
            if trn_start = '1' and trn_type = "00" then
              state <= S_ControlStatusOUT_D;
            end if;

          when S_ControlStatusOUT_D =>
            if rx_trn_end = '1' then
              state <= S_ControlStatusOUT_ACK;
              if ctl_xfer_done = '1' then
                ctl_status <= "00";
              else
                ctl_status <= "10";
              end if;
            end if;

          when S_ControlStatusOUT_ACK =>
            if tx_trn_hsk_sended = '1' then
              if ctl_status = "10" then
                state <= S_ControlStatusOUT;
              else
                state <= S_Idle;
              end if;
            end if;

          when S_ControlStatusIN =>
            -- IN Token
            if trn_start = '1' and trn_type = "10" then
              if ctl_xfer_done = '1' then
                tx_trn_data_start <= '1';
                state             <= S_ControlStatusIN_D;
              else
                ctl_status <= "10";
                state      <= S_ControlStatusIN_MyACK;
              end if;
            end if;

          when S_ControlStatusIN_MyACK =>
            if tx_trn_hsk_sended = '1' then
              state <= S_ControlStatusIN;
            end if;

          when S_ControlStatusIN_D =>
            tx_trn_data_start <= '0';
            state             <= S_ControlStatusIN_ACK;

          when S_ControlStatusIN_ACK =>
            if rx_trn_hsk_received = '1' then
              state <= S_Idle;
            end if;

          when S_BulkIN =>
            if blk_xfer_in_data_valid = '1' and tx_trn_data_ready = '1' then
              if tx_counter_over = '1' or blk_xfer_in_data_last = '1' then
                tx_trn_data_start <= '0';
                state             <= S_BulkIN_ACK;
              end if;
              tx_counter <= tx_counter + 1;
            elsif blk_xfer_in_data_valid = '0' then
              tx_trn_data_start <= '0';
              state             <= S_BulkIN_ACK;
            end if;

          when S_BulkIN_ACK =>
            if rx_trn_hsk_received = '1' then
              state <= S_Idle;
            end if;

          when S_BulkIN_MyACK =>
            if tx_trn_hsk_sended = '1' then
              state <= S_Idle;
            end if;

          when S_BulkOUT =>
            if rx_trn_end = '1' then
              state <= S_BulkOUT_ACK;
            end if;

          when S_BulkOUT_ACK =>
            if tx_trn_hsk_sended = '1' then
              state <= S_Idle;
            end if;

        end case;
      end if;
    end if;
  end process;

  ctl_xfer_endpoint <= current_endpoint;
  blk_xfer_endpoint <= current_endpoint;

  tx_trn_hsk_type   <= "00" when state = S_ControlSetupACK else
                     ctl_status;

  tx_trn_send_hsk <= '1' when state = S_ControlSetupACK else
                     '1' when state = S_ControlStatusOUT_ACK else
                     '1' when state = S_ControlStatusIN_MyACK else
                     '1' when state = S_BulkIN_MyACK else
                     '1' when state = S_BulkOUT_ACK else
                     '1' when state = S_ControlDataOUT_MyACK else
                     '0';

  ctl_xfer_length        <= ctl_xfer_length_int;
  ctl_xfer_type          <= ctl_xfer_type_int;

  ctl_xfer_data_in_ready <= tx_trn_data_ready when state = S_ControlDataIN else
                            '0';

  blk_xfer_in_data_ready <= tx_trn_data_ready when state = S_BulkIN else
                            '0';

  tx_trn_data_type <= data_types(to_integer(unsigned(current_endpoint))) & '0';

  tx_trn_data      <= ctl_xfer_data_in when state = S_ControlDataIN else
                 blk_xfer_in_data;
  tx_trn_data_valid <= ctl_xfer_data_in_valid when state = S_ControlDataIN else
                       blk_xfer_in_data_valid when state = S_BulkIN else
                       '0';
                       
  tx_counter_over <= '1' when tx_counter(5 downto 0) = 63 AND HIGH_SPEED = false else
                     '1' when tx_counter(8 downto 0) = 511 AND HIGH_SPEED = true else
                     '0';

  tx_trn_data_last <= '1' when state = S_ControlDataIN and (tx_counter(5 downto 0) = 63 or tx_counter = ctl_xfer_length_int - 1) else
                      '1'                   when state = S_BulkIN and (tx_counter_over = '1' or blk_xfer_in_data_last = '1') else
                      '1'                   when state = S_ControlStatusIN_D else
                      '1'                   when state = S_ControlDataIN_Z else
                      ctl_xfer_data_in_last when state = S_ControlDataIN else
                      '0';

  blk_xfer_out_data       <= rx_trn_data;
  blk_xfer_out_data_valid <= rx_trn_valid when state = S_BulkOUT else
                             '0';
                             
  ctl_xfer_data_out <= rx_trn_data;
  ctl_xfer_data_out_valid <= rx_trn_valid;

end usb_xfer;
