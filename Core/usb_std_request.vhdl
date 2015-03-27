--
-- USB Full-Speed/Hi-Speed Device Controller core - usb_std_request.vhdl
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

entity usb_std_request is
  generic (
    VENDOR_ID    : std_logic_vector(15 downto 0) := X"DEAD";
    PRODUCT_ID   : std_logic_vector(15 downto 0) := X"BEEF";
    MANUFACTURER : string                        := "";
    PRODUCT      : string                        := "";
    SERIAL       : string                        := ""
    );
  port (
    rst                     : in  std_logic;
    clk                     : in  std_logic;

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

    current_configuration   : out std_logic_vector(7 downto 0);
    configured              : out std_logic := '0';

    reset_data_bit_toggling : out std_logic
    );
end usb_std_request;

architecture usb_std_request of usb_std_request is
  type BYTE_ARRAY is array(natural range <>) of std_logic_vector(7 downto 0);

  function indexOrZero(s : in string; i : in std_logic_vector)
    return std_logic_vector is
  begin
    if s = "" then
      return X"00";
    else
      return i;
    end if;
  end function;

  function string2descriptor(s : in string)
    return BYTE_ARRAY is
    variable a : BYTE_ARRAY(0 to 2 + 2 * s'length - 1);
  begin
    a(0) := std_logic_vector(to_unsigned(2 + 2 * s'length, 8));
    a(1) := X"03";
    if s'length > 0 then
      for i in s'range loop
        a(2 * (i - s'low) + 2) := std_logic_vector(to_unsigned(character'pos(s(i)), 8));
        a(2 * (i - s'low) + 3) := (others => '0');
      end loop;
    end if;
    return a;
  end function;

  function selectInt(cond : in boolean; a : in integer; b : integer)
    return integer is
  begin
    if cond then
      return a;
    else
      return b;
    end if;
  end function;

  function selectArray(cond : in boolean; a : in BYTE_ARRAY; b : BYTE_ARRAY)
    return BYTE_ARRAY is
  begin
    if cond then
      return a;
    else
      return b;
    end if;
  end function;

  constant DEVICE_DESC : BYTE_ARRAY(0 to 17) := (
    X"12",                              -- bLength = 18
    X"01",                              -- bDescriptionType = Device Descriptor
    X"01", X"10",                       -- bcdUSB = USB 2.0
    X"FF",                              -- bDeviceClass = None
    X"00",                              -- bDeviceSubClass
    X"00",                              -- bDeviceProtocol
    X"40",                              -- bMaxPacketSize = 64
    VENDOR_ID(7 downto 0), VENDOR_ID(15 downto 8),    -- idVendor
    PRODUCT_ID(7 downto 0), PRODUCT_ID(15 downto 8),  -- idProduct
    X"00", X"00",                       -- bcdDevice
    indexOrZero(MANUFACTURER, X"01"),   -- iManufacturer
    indexOrZero(PRODUCT, X"02"),        -- iProduct
    indexOrZero(SERIAL, X"03"),         -- iSerialNumber
    X"01"                               -- bNumConfigurations = 1
    );

  constant CONFIG_DESC : BYTE_ARRAY(0 to 8) := (
    X"09",                              -- bLength = 9
    X"02",                              -- bDescriptionType = Configuration Descriptor
    X"20", X"00",                       -- wTotalLength = 32
    X"01",                              -- bNumInterfaces = 1
    X"01",                              -- bConfigurationValue
    X"00",                              -- iConfiguration
    X"C0",                              -- bmAttributes = Self-powered
    X"32"                               -- bMaxPower = 100 mA
    );

  constant INTERFACE_DESC : BYTE_ARRAY(0 to 8) := (
    X"09",                              -- bLength = 9
    X"04",                              -- bDescriptorType = Interface Descriptor
    X"00",                              -- bInterfaceNumber = 0
    X"00",                              -- bAlternateSetting
    X"02",                              -- bNumEndpoints = 2
    X"00",                              -- bInterfaceClass
    X"00",                              -- bInterfaceSubClass
    X"00",                              -- bInterfaceProtocol
    X"00"                               -- iInterface
    );

  constant EP1_IN_DESC : BYTE_ARRAY(0 to 6) := (
    X"07",                              -- bLength = 7
    X"05",                              -- bDescriptorType = Endpoint Descriptor
    X"81",                              -- bEndpointAddress = IN1
    B"00_00_00_10",                     -- bmAttributes = Bulk
    X"40", X"00",                       -- wMaxPacketSize = 64 bytes
    X"00"                               -- bInterval
    );

  constant EP1_OUT_DESC : BYTE_ARRAY(0 to 6) := (
    X"07",                              -- bLength = 7
    X"05",                              -- bDescriptorType = Endpoint Descriptor
    X"01",                              -- bEndpointAddress = OUT1
    B"00_00_00_10",                     -- bmAttributes = Bulk
    X"40", X"00",                       -- wMaxPacketSize = 64 bytes
    X"00"                               -- bInterval
    );

  constant STR_DESC : BYTE_ARRAY(0 to 3) := (
    X"04",                              -- bLength = 4
    X"03",                              -- bDescriptorType = String Descriptor
    X"09", X"04"
    );
  constant MANUFACTURER_STR_DESC : BYTE_ARRAY(0 to 2 + 2 * MANUFACTURER'length - 1) := string2descriptor(MANUFACTURER);
  constant PRODUCT_STR_DESC      : BYTE_ARRAY(0 to 2 + 2 * PRODUCT'length - 1)      := string2descriptor(PRODUCT);
  constant SERIAL_STR_DESC       : BYTE_ARRAY(0 to 2 + 2 * SERIAL'length - 1)       := string2descriptor(SERIAL);

  constant DESC_SIZE_STR         : integer := DEVICE_DESC'length + CONFIG_DESC'length + INTERFACE_DESC'length +
                                      EP1_IN_DESC'length + EP1_OUT_DESC'length + STR_DESC'length +
                                      MANUFACTURER_STR_DESC'length + PRODUCT_STR_DESC'length + SERIAL_STR_DESC'length;
  constant DESC_SIZE_NOSTR       : integer := DEVICE_DESC'length + CONFIG_DESC'length + INTERFACE_DESC'length +
                                        EP1_IN_DESC'length + EP1_OUT_DESC'length;

  constant DESC_HAS_STRINGS      : boolean := (MANUFACTURER'length > 0) or (PRODUCT'length > 0) or (SERIAL'length > 0);

  constant DESC_SIZE             : integer := selectInt(DESC_HAS_STRINGS, DESC_SIZE_STR, DESC_SIZE_NOSTR);

  constant USB_DESC              : BYTE_ARRAY(0 to DESC_SIZE - 1) := selectArray(DESC_HAS_STRINGS,
                                                                    DEVICE_DESC & CONFIG_DESC & INTERFACE_DESC
                                                                    & EP1_IN_DESC & EP1_OUT_DESC
                                                                    & STR_DESC & MANUFACTURER_STR_DESC & PRODUCT_STR_DESC & SERIAL_STR_DESC,
                                                                    DEVICE_DESC & CONFIG_DESC & INTERFACE_DESC
                                                                    & EP1_IN_DESC & EP1_OUT_DESC);

  constant DESC_CONFIG_START     : integer := DEVICE_DESC'length;
  constant DESC_STRING_START     : integer := DEVICE_DESC'length + CONFIG_DESC'length + INTERFACE_DESC'length +
                                              EP1_IN_DESC'length + EP1_OUT_DESC'length;

  type MACHINE is (S_Idle, S_GetDescriptor, S_SetConfiguration, S_SetAddress);

  signal state        : MACHINE := S_Idle;

  signal mem_addr     : std_logic_vector(7 downto 0);
  signal max_mem_addr : std_logic_vector(7 downto 0);

  -- 000 - None
  -- 001 - Get device descriptor
  -- 010 - Set address
  -- 011 - Get configuration descriptor
  -- 100 - Set configuration
  -- 101 - Get string descriptor
  signal req_type     : std_logic_vector(2 downto 0);

begin
  MEM_ADDRESSER : process(clk) is
  begin
    if rising_edge(clk) then
      if state = S_Idle then
        if ctl_xfer = '1' then
          if req_type = "011" then
            mem_addr       <= std_logic_vector(to_unsigned(DESC_CONFIG_START, mem_addr'length));
            max_mem_addr   <= std_logic_vector(to_unsigned(DESC_STRING_START - 1, mem_addr'length));
          elsif DESC_HAS_STRINGS and req_type = "101" then
            if ctl_xfer_value(7 downto 0) = X"00" then
              mem_addr     <= std_logic_vector(to_unsigned(DESC_STRING_START, mem_addr'length));
              max_mem_addr <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length - 1, mem_addr'length));
            elsif ctl_xfer_value(7 downto 0) = X"01" then
              mem_addr     <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length, mem_addr'length));
              max_mem_addr <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length + MANUFACTURER_STR_DESC'length - 1, mem_addr'length));
            elsif ctl_xfer_value(7 downto 0) = X"02" then
              mem_addr     <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length + MANUFACTURER_STR_DESC'length, mem_addr'length));
              max_mem_addr <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length + MANUFACTURER_STR_DESC'length +
                                                           PRODUCT_STR_DESC'length - 1, mem_addr'length));
            elsif ctl_xfer_value(7 downto 0) = X"03" then
              mem_addr     <= std_logic_vector(to_unsigned(DESC_STRING_START + STR_DESC'length + MANUFACTURER_STR_DESC'length +
                                                       PRODUCT_STR_DESC'length, mem_addr'length));
              max_mem_addr <= std_logic_vector(to_unsigned(DESC_SIZE - 1, mem_addr'length));
            end if;
          else
            mem_addr       <= (others => '0');
            max_mem_addr   <= std_logic_vector(to_unsigned(DESC_CONFIG_START - 1, mem_addr'length));
          end if;
        else
          mem_addr <= (others => '0');
        end if;
      elsif state = S_GetDescriptor and ctl_xfer_data_in_ready = '1' then
        if mem_addr /= max_mem_addr then
          mem_addr <= mem_addr + 1;
        end if;
      end if;
    end if;
  end process;

  FSM : process(clk) is
  begin
    if rst = '1' then
      state <= S_Idle;
    elsif rising_edge(clk) then
      case state is
        when S_Idle =>
          reset_data_bit_toggling <= '0';
          if ctl_xfer = '1' then
            if req_type = "001" or req_type = "011" or req_type = "101" then
              state <= S_GetDescriptor;
            elsif req_type = "010" then
              state <= S_SetAddress;
            elsif req_type = "100" then
              current_configuration <= ctl_xfer_value(7 downto 0);
              state                 <= S_SetConfiguration;
            end if;
          end if;

        when S_SetAddress =>
          if ctl_xfer = '0' then
            state <= S_Idle;
          end if;

        when S_GetDescriptor =>
          if ctl_xfer = '0' then
            state <= S_Idle;
          end if;

        when S_SetConfiguration =>
          if ctl_xfer = '0' then
            reset_data_bit_toggling <= '1';
            configured              <= '1';
            state                   <= S_Idle;
          end if;

      end case;
    end if;
  end process;

  req_type <= "001" when ctl_xfer_type = X"80" and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"01" else
              "010" when ctl_xfer_type = X"00" and ctl_xfer_request = X"05" else
              "011" when ctl_xfer_type = X"80" and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"02" else
              "100" when ctl_xfer_type = X"00" and ctl_xfer_request = X"09" else
              "101" when ctl_xfer_type = X"80" and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"03" else
              "000";

  ctl_xfer_data_in_valid <= '1' when state = S_GetDescriptor else
                            '0';

  ctl_xfer_data_in <= USB_DESC(conv_integer(mem_addr));

  ctl_xfer_data_in_last <= '1' when state = S_GetDescriptor and mem_addr = max_mem_addr else
                           '0';

  ctl_xfer_done <= '1';

  ctl_xfer_accept <= '0' when req_type = "000" else
                     '1';

end usb_std_request;
