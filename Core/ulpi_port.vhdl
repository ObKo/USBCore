--
-- USB Full-Speed/Hi-Speed Device Controller core - ulpi_port.vhdl
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

entity ulpi_port is
  generic (
    HIGH_SPEED: boolean := true
  );
  port (
    rst            : in  std_logic;

    ulpi_data_in   : in  std_logic_vector(7 downto 0);
    ulpi_data_out  : out std_logic_vector(7 downto 0);
    ulpi_dir       : in  std_logic;
    ulpi_nxt       : in  std_logic;
    ulpi_stp       : out std_logic;
    ulpi_reset     : out std_logic;
    ulpi_clk       : in  std_logic;

    axis_rx_tvalid : out std_logic;
    axis_rx_tready : in  std_logic;
    axis_rx_tdata  : out std_logic_vector(7 downto 0);
    rx_eop         : out std_logic;

    -- tvalid de-assertion during tx means end of transaction
    axis_tx_tvalid : in  std_logic;
    axis_tx_tready : out std_logic;
    axis_tx_tlast  : in  std_logic;
    -- First data is always PID (in 4 least significant bits, 0 - NOPID packet)
    axis_tx_tdata  : in  std_logic_vector(7 downto 0);

    -- 00 - SE0
    -- 01 - J
    -- 10 - K
    -- 11 - SE1
    usb_line_state : out std_logic_vector(1 downto 0) := "00";
    usb_rx_active  : out std_logic                    := '0';
    usb_rx_error   : out std_logic                    := '0';
    usb_vbus_valid : out std_logic                    := '0';
    -- Reset signal from state controller = ~2.4 uS of SE0
    -- FIXME: Move state controller into ulpi_port?
    usb_reset      : in  std_logic
  );
end ulpi_port;

architecture ulpi_port of ulpi_port is
  type MACHINE is (S_Init, S_WriteReg_A, S_WriteReg_D, S_STP, S_SwitchToFS, S_WaitResetDone,
                   S_Idle, S_TX, S_TX_Last, S_ChirpStart, S_ChirpStartK, S_ChirpK,
                   S_ChirpKJ);

  signal state            : MACHINE;
  signal state_after      : MACHINE;
  signal dir_d            : std_logic;
  signal tx_pid           : std_logic_vector(3 downto 0);
  
  signal reg_data         : std_logic_vector(7 downto 0);

  signal buf_data         : std_logic_vector(7 downto 0);
  signal buf_last         : std_logic;
  signal buf_valid        : std_logic;

  signal tx_eop           : std_logic := '0';
  signal bus_tx_ready     : std_logic := '0';
  
  signal chirp_counter    : std_logic_vector(16 downto 0);
  signal chirp_kj_counter : std_logic_vector(2 downto 0);
  signal chirp_kj_prev    : std_logic;
  signal chirp_kj         : std_logic;
  
  signal chirp_k_done     : std_logic;
  signal is_hs            : std_logic := '0';
begin
  OUTER : process(ulpi_clk) is
  begin
    if rising_edge(ulpi_clk) then
      axis_rx_tdata <= ulpi_data_in;
      if dir_d = ulpi_dir and ulpi_dir = '1' and ulpi_nxt = '1' then
        axis_rx_tvalid <= '1';
      else
        axis_rx_tvalid <= '0';
      end if;
    end if;
  end process;
        
  chirp_kj <= '1' when ulpi_data_in(1 downto 0) = "10" else
              '0';

  FSM : process(ulpi_clk) is
  begin
    if rising_edge(ulpi_clk) then
      dir_d <= ulpi_dir;
      
      if dir_d = ulpi_dir then
        if ulpi_dir = '1' and ulpi_nxt = '0' then
          usb_line_state <= ulpi_data_in(1 downto 0);

          if ulpi_data_in(5 downto 4) = "01" then
            usb_rx_active <= '1';
            usb_rx_error  <= '0';
          elsif ulpi_data_in(5 downto 4) = "11" then
            usb_rx_active <= '1';
            usb_rx_error  <= '1';
          else
            usb_rx_active <= '0';
            usb_rx_error  <= '0';
          end if;

          if ulpi_data_in(3 downto 2) = "11" then
            usb_vbus_valid <= '1';
          else
            usb_vbus_valid <= '0';
          end if;
                    
          if state = S_ChirpKJ then
            if chirp_kj /= chirp_kj_prev then
              chirp_counter <= (others => '0');
              if chirp_kj = '0' then
                chirp_kj_counter <= chirp_kj_counter + 1;
              end if;
              chirp_kj_prev <= chirp_kj;
            else
              chirp_counter <= chirp_counter + 1;
            end if;
          end if;

        elsif ulpi_dir = '0' then
          usb_rx_active <= '0';

          case state is
            when S_Init =>
              ulpi_data_out <= X"8A";
              reg_data      <= X"00";
              state         <= S_WriteReg_A;
              state_after   <= S_SwitchToFS;

            when S_WriteReg_A =>
              if ulpi_nxt = '1' then
                ulpi_data_out <= reg_data;
                state         <= S_WriteReg_D;
              end if;

            when S_WriteReg_D =>
              if ulpi_nxt = '1' then
                ulpi_data_out <= X"00";
                state         <= S_STP;
              end if;
              
            when S_SwitchToFS =>
              reg_data      <= b"0_1_0_00_1_01";
              ulpi_data_out <= X"84";
              state         <= S_WriteReg_A;
              is_hs         <= '0';
              state_after   <= S_WaitResetDone;
              
            when S_WaitResetDone =>
              if usb_reset = '0' then
                state <= S_Idle;
              end if;

            when S_STP =>
              state <= state_after;

            when S_Idle =>
              if usb_reset = '1' then
                if is_hs = '0' and HIGH_SPEED then
                  state <= S_ChirpStart;
                else
                  state <= S_SwitchToFS;
                end if;
              elsif bus_tx_ready = '1' and axis_tx_tvalid = '1' then
                ulpi_data_out <= "0100" & axis_tx_tdata(3 downto 0);
                buf_valid     <= '0';
                if axis_tx_tlast = '1' then
                  state <= S_TX_Last;
                else
                  state <= S_TX;
                end if;
              end if;

            when S_TX =>
              if ulpi_nxt = '1' then
                if axis_tx_tvalid = '1' and buf_valid = '0' then
                  ulpi_data_out <= axis_tx_tdata;
                  if axis_tx_tlast = '1' then
                    state <= S_TX_Last;
                  end if;
                elsif buf_valid = '1' then
                  ulpi_data_out <= buf_data;
                  buf_valid     <= '0';
                  if buf_last = '1' then
                    state <= S_TX_Last;
                  end if;
                else
                  ulpi_data_out <= X"00";
                end if;
              else
                if axis_tx_tvalid = '1' and buf_valid = '0' then
                  buf_data  <= axis_tx_tdata;
                  buf_last  <= axis_tx_tlast;
                  buf_valid <= '1';
                end if;
              end if;

            when S_TX_Last =>
              if ulpi_nxt = '1' then
                ulpi_data_out <= X"00";
                state_after   <= S_Idle;
                state         <= S_STP;
              end if;
              
            when S_ChirpStart =>
              reg_data      <= b"0_1_0_10_1_00";
              ulpi_data_out <= X"84";
              state         <= S_WriteReg_A;
              state_after   <= S_ChirpStartK;
              
            when S_ChirpStartK =>
              if ulpi_nxt = '1' then
                ulpi_data_out <= X"00";
                state <= S_ChirpK;
                chirp_counter <= (others => '0');
              else
                ulpi_data_out <= X"40";
              end if;
            
            when S_ChirpK =>
              if chirp_counter > 66000 then
                ulpi_data_out <= X"00";
                state         <= S_STP;
                state_after   <= S_ChirpKJ;
                chirp_kj_prev <= '0';
                chirp_kj_counter <= (others => '0');
              else
                chirp_counter <= chirp_counter + 1;
              end if;
              
            when S_ChirpKJ =>
              if chirp_kj_counter > 3 AND chirp_counter > 2000 then
                reg_data      <= b"0_1_0_00_0_00";
                ulpi_data_out <= X"84";
                state         <= S_WriteReg_A;
                state_after   <= S_Idle;
                is_hs         <= '1';
              end if;
              chirp_counter <= chirp_counter + 1;

          end case;
        end if;
      else
        usb_rx_active <= '0';
      end if;
    end if;
  end process;

  ulpi_stp <= '1' when ulpi_dir = '1' and axis_rx_tready = '0' else
              '1' when state = S_STP else
              '0';

  ulpi_reset   <= '0';

  bus_tx_ready <= '1' when ulpi_dir = '0' and ulpi_dir = dir_d else
                  '0';

  axis_tx_tready <= '1' when bus_tx_ready = '1' and state = S_Idle else
                    '1' when bus_tx_ready = '1' and state = S_TX and buf_valid = '0' else
                    '0';
end ulpi_port;
