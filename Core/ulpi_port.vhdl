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

--! ULPI PHY controller
entity ulpi_port is
  generic (
    HIGH_SPEED: boolean := true
  );
  port (
    rst            : in  std_logic;                     --! Global external asynchronous reset

    --! ULPI PHY signals
    ulpi_data_in   : in  std_logic_vector(7 downto 0);
    ulpi_data_out  : out std_logic_vector(7 downto 0);
    ulpi_dir       : in  std_logic;
    ulpi_nxt       : in  std_logic;
    ulpi_stp       : out std_logic;
    ulpi_reset     : out std_logic;
    ulpi_clk       : in  std_logic;

    --! RX AXI-Stream, first data is PID
    axis_rx_tvalid : out std_logic;
    axis_rx_tready : in  std_logic;
    axis_rx_tlast  : out std_logic;
    axis_rx_tdata  : out std_logic_vector(7 downto 0);

    --! TX AXI-Stream, first data should be PID (in 4 least significant bits)
    axis_tx_tvalid : in  std_logic;
    axis_tx_tready : out std_logic;
    axis_tx_tlast  : in  std_logic;
    axis_tx_tdata  : in  std_logic_vector(7 downto 0);

    usb_vbus_valid : out std_logic;                     --! VBUS has valid voltage
    usb_reset      : out std_logic;                     --! USB bus is in reset state
    usb_idle       : out std_logic;                     --! USB bus is in idle state
    usb_suspend    : out std_logic                      --! USB bus is in suspend state
  );
end ulpi_port;

architecture ulpi_port of ulpi_port is
  constant SUSPEND_TIME : integer := 190000;  -- = ~3 ms
  constant RESET_TIME   : integer := 190000;  -- = ~3 ms 
  constant CHIRP_K_TIME : integer := 66000;   -- = ~1 ms  
  constant CHIRP_KJ_TIME: integer := 120;     -- = ~2 us 
  constant SWITCH_TIME  : integer := 6000;    -- = ~100 us 

  type MACHINE is (S_Init, S_WriteReg_A, S_WriteReg_D, S_STP, S_Reset, S_Suspend,
                   S_Idle, S_TX, S_TX_Last, S_ChirpStart, S_ChirpStartK, S_ChirpK,
                   S_ChirpKJ, S_SwitchFSStart, S_SwitchFS);

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
  
  signal chirp_kj_counter : std_logic_vector(2 downto 0);
  signal hs_enabled       : std_logic := '0';
  
  signal usb_line_state   : std_logic_vector(1 downto 0);
  signal state_counter    : std_logic_vector(17 downto 0);
  
  signal packet           : std_logic := '0';
  signal packet_buf       : std_logic_vector(7 downto 0);
begin
  OUTER : process(ulpi_clk) is
  begin
    if rising_edge(ulpi_clk) then
      if dir_d = ulpi_dir and ulpi_dir = '1' and ulpi_nxt = '1' then
        packet_buf <= ulpi_data_in;
        if packet = '0' then
          axis_rx_tvalid <= '0';
          packet <= '1';
        else
          axis_rx_tdata <= packet_buf;
          axis_rx_tvalid <= '1';          
        end if;
        axis_rx_tlast <= '0';
      elsif packet = '1' and dir_d = ulpi_dir and 
          ((ulpi_dir = '1' and ulpi_data_in(4) = '0') or (ulpi_dir = '0')) then
        axis_rx_tdata <= packet_buf;
        axis_rx_tvalid <= '1';
        axis_rx_tlast <= '1';
        packet <= '0';        
      else
        axis_rx_tvalid <= '0';
        axis_rx_tlast <= '0';
      end if;
    end if;
  end process;
              
  STATE_COUNT: process(ulpi_clk) is
  begin
    if rising_edge(ulpi_clk) then
      if dir_d = ulpi_dir and ulpi_dir = '1' and ulpi_nxt = '0' AND ulpi_data_in(1 downto 0) /= usb_line_state then
        if state = S_ChirpKJ then 
          if ulpi_data_in(1 downto 0) = "01" then
            chirp_kj_counter <= chirp_kj_counter + 1;
          end if;
        else
          chirp_kj_counter <= (others => '0');
        end if;
        usb_line_state <= ulpi_data_in(1 downto 0);
        state_counter <= (others => '0');
      elsif state = S_ChirpStartK then
        state_counter <= (others => '0');
      elsif state = S_SwitchFSStart then
        state_counter <= (others => '0');        
      else
        state_counter <= state_counter + 1;
      end if;
    end if;
  end process;

  FSM : process(ulpi_clk) is
  begin
    if rising_edge(ulpi_clk) then
      dir_d <= ulpi_dir;
      
      if dir_d = ulpi_dir then
        if ulpi_dir = '1' and ulpi_nxt = '0' then
          if ulpi_data_in(3 downto 2) = "11" then
            usb_vbus_valid <= '1';
          else
            usb_vbus_valid <= '0';
          end if;
        elsif ulpi_dir = '0' then
          case state is
            when S_Init =>
              ulpi_data_out <= X"8A";
              reg_data      <= X"00";
              state         <= S_WriteReg_A;
              state_after   <= S_SwitchFSStart;
              
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
              
            when S_Reset =>
              usb_reset <= '1';
              if hs_enabled = '0' and HIGH_SPEED then
                state <= S_ChirpStart;
              elsif HIGH_SPEED then
                state <= S_SwitchFSStart;
              else
                if usb_line_state /= "00" then
                  state <= S_Idle;
                end if;
              end if;
              
            when S_Suspend =>
              -- Should be J state for 20 ms, but I'm too lazy
              -- FIXME: Need valid resume sequence for HS
              if usb_line_state /= "01" then
                state <= S_Idle;
              end if;

            when S_STP =>
              state <= state_after;

            when S_Idle =>
              usb_reset <= '0';
              if usb_line_state = "00" and state_counter > RESET_TIME then
                state <= S_Reset;
              elsif hs_enabled = '0' and usb_line_state = "01" and state_counter > SUSPEND_TIME then
                state <= S_Suspend;
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
              else
                ulpi_data_out <= X"40";
              end if;
            
            when S_ChirpK =>
              if state_counter > CHIRP_K_TIME then
                ulpi_data_out <= X"00";
                state         <= S_STP;
                state_after   <= S_ChirpKJ;
              end if;
              
            when S_ChirpKJ =>
              if chirp_kj_counter > 3 AND state_counter > CHIRP_KJ_TIME then
                reg_data      <= b"0_1_0_00_0_00";
                ulpi_data_out <= X"84";
                state         <= S_WriteReg_A;
                state_after   <= S_Idle;
                hs_enabled    <= '1';
              end if;
              
            when S_SwitchFSStart =>
              reg_data      <= b"0_1_0_00_1_01";
              ulpi_data_out <= X"84";
              state         <= S_WriteReg_A;
              hs_enabled    <= '0';
              state_after   <= S_SwitchFS;
              
            when S_SwitchFS =>
              if state_counter > SWITCH_TIME then
                if usb_line_state = "00" AND HIGH_SPEED then
                  state <= S_ChirpStart;
                else
                  state <= S_Idle;
                end if;
              end if;

          end case;
        end if;
      end if;
    end if;
  end process;

  ulpi_stp <= '1' when ulpi_dir = '1' and axis_rx_tready = '0' else
              '1' when state = S_STP else
              '0';

  ulpi_reset   <= rst;

  bus_tx_ready <= '1' when ulpi_dir = '0' and ulpi_dir = dir_d else
                  '0';

  axis_tx_tready <= '1' when bus_tx_ready = '1' and state = S_Idle else
                    '1' when bus_tx_ready = '1' and state = S_TX and buf_valid = '0' else
                    '0';
                    
  usb_idle <= '1' when state = S_Idle else
              '0';
  usb_suspend <= '1' when state = S_Suspend else
                 '0';
end ulpi_port;
