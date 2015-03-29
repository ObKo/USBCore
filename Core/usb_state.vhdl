--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_state.vhdl
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

entity usb_state is
  port (
    rst            : in  std_logic;
    clk            : in  std_logic;

    usb_line_state : in  std_logic_vector(1 downto 0);

    reset          : out std_logic;
    idle           : out std_logic;
    suspend        : out std_logic
    );
end usb_state;

architecture usb_state of usb_state is
  constant SUSPEND_TIME : integer := 180000;  -- = 3 ms
  constant RESET_TIME   : integer := 240;     -- = 4 us 

  type MACHINE is (S_Idle, S_Reset, S_Suspend);
  signal state          : MACHINE := S_Idle;

  signal j_counter      : std_logic_vector(17 downto 0);
  signal se0_counter    : std_logic_vector(7 downto 0);

begin
  COUNTER : process(clk) is
  begin
    if rising_edge(clk) then
      if usb_line_state = "00" then -- SE0
        se0_counter <= se0_counter + 1;
      else
        se0_counter <= (others => '0');
      end if;
      if usb_line_state = "01" then -- J
        j_counter <= j_counter + 1;
      else
        j_counter <= (others => '0');
      end if;
    end if;
  end process;

  FSM : process(clk) is
  begin
    if rising_edge(clk) then
      case state is
        when S_Idle =>
          if se0_counter >= RESET_TIME then
            state <= S_Reset;
          elsif j_counter >= SUSPEND_TIME then
            state <= S_Suspend;
          end if;

        when S_Reset =>
          if usb_line_state /= "00" then
            state <= S_Idle;
          end if;

        when S_Suspend =>
          -- Should be J state for 20 ms, but I'm too lazy
          if usb_line_state /= "01" then
            state <= S_Idle;
          end if;

      end case;
    end if;
  end process;

  reset <= '1' when state = S_Reset else
           '0';

  suspend <= '1' when state = S_Suspend else
             '0';

  idle <= '1' when state = S_Idle else
          '0';

end usb_state;
