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

library work;
use work.USBCore.all;

entity usb_std_request is
  generic (
    VENDOR_ID    : std_logic_vector(15 downto 0) := X"DEAD";
    PRODUCT_ID   : std_logic_vector(15 downto 0) := X"BEEF";
    MANUFACTURER : string                        := "";
    PRODUCT      : string                        := "";
    SERIAL       : string                        := "";
    CONFIG_DESC  : BYTE_ARRAY                    := (
      -- Configuration descriptor
      X"09",        -- bLength = 9
      X"02",        -- bDescriptionType = Configuration Descriptor
      X"12", X"00", -- wTotalLength = 18
      X"01",        -- bNumInterfaces = 1
      X"01",        -- bConfigurationValue
      X"00",        -- iConfiguration
      X"C0",        -- bmAttributes = Self-powered
      X"32",        -- bMaxPower = 100 mA
      -- Interface descriptor
      X"09",        -- bLength = 9
      X"04",        -- bDescriptorType = Interface Descriptor
      X"00",        -- bInterfaceNumber = 0
      X"00",        -- bAlternateSetting
      X"00",        -- bNumEndpoints = 0
      X"00",        -- bInterfaceClass
      X"00",        -- bInterfaceSubClass
      X"00",        -- bInterfaceProtocol
      X"00"         -- iInterface
      );
    HIGH_SPEED: boolean := true
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
    
    device_address          : out std_logic_vector(6 downto 0);
    current_configuration   : out std_logic_vector(7 downto 0);
    configured              : out std_logic := '0';
    
    standart_request        : out std_logic
    );
end usb_std_request;

architecture usb_std_request of usb_std_request is
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

  constant DEVICE_DESC_FS : BYTE_ARRAY(0 to 17) := (
    X"12",                              -- bLength = 18
    X"01",                              -- bDescriptionType = Device Descriptor
    X"10", X"01",                       -- bcdUSB = USB 1.1
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
    
  constant DEVICE_DESC_HS : BYTE_ARRAY(0 to 17) := (
    X"12",                              -- bLength = 18
    X"01",                              -- bDescriptionType = Device Descriptor
    X"00", X"02",                       -- bcdUSB = USB 2.0
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
    
  constant DEVICE_DESC : BYTE_ARRAY(0 to 17) := selectArray(HIGH_SPEED, DEVICE_DESC_HS, DEVICE_DESC_FS);

  constant STR_DESC : BYTE_ARRAY(0 to 3) := (
    X"04",                              -- bLength = 4
    X"03",                              -- bDescriptorType = String Descriptor
    X"09", X"04"
    );
  constant MANUFACTURER_STR_DESC : BYTE_ARRAY(0 to 2 + 2 * MANUFACTURER'length - 1) := string2descriptor(MANUFACTURER);
  constant PRODUCT_STR_DESC      : BYTE_ARRAY(0 to 2 + 2 * PRODUCT'length - 1)      := string2descriptor(PRODUCT);
  constant SERIAL_STR_DESC       : BYTE_ARRAY(0 to 2 + 2 * SERIAL'length - 1)       := string2descriptor(SERIAL);

  constant DESC_SIZE_STR         : integer := DEVICE_DESC'length + CONFIG_DESC'length + STR_DESC'length +
                                      MANUFACTURER_STR_DESC'length + PRODUCT_STR_DESC'length + SERIAL_STR_DESC'length;
  constant DESC_SIZE_NOSTR       : integer := DEVICE_DESC'length + CONFIG_DESC'length;

  constant DESC_HAS_STRINGS      : boolean := (MANUFACTURER'length > 0) or (PRODUCT'length > 0) or (SERIAL'length > 0);

  constant DESC_SIZE             : integer := selectInt(DESC_HAS_STRINGS, DESC_SIZE_STR, DESC_SIZE_NOSTR);

  constant USB_DESC              : BYTE_ARRAY(0 to DESC_SIZE - 1) := selectArray(DESC_HAS_STRINGS,
                                                                       DEVICE_DESC & CONFIG_DESC & STR_DESC 
                                                                         & MANUFACTURER_STR_DESC & PRODUCT_STR_DESC & SERIAL_STR_DESC,
                                                                       DEVICE_DESC & CONFIG_DESC);

  constant DESC_CONFIG_START     : integer := DEVICE_DESC'length;
  constant DESC_STRING_START     : integer := DEVICE_DESC'length + CONFIG_DESC'length;

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
  
  signal is_std_req   : std_logic;
  signal is_dev_req   : std_logic;
  signal handle_req   : std_logic;

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
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_Idle;
        device_address <= (others => '0');
      else
        case state is
          when S_Idle =>
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
              device_address <= ctl_xfer_value(6 downto 0);
            end if;

          when S_GetDescriptor =>
            if ctl_xfer = '0' then
              state <= S_Idle;
            end if;

          when S_SetConfiguration =>
            if ctl_xfer = '0' then
              configured              <= '1';
              state                   <= S_Idle;
            end if;

        end case;
      end if;
    end if;
  end process;

  req_type <= "001" when handle_req = '1' and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"01" else
              "010" when handle_req = '1' and ctl_xfer_request = X"05" else
              "011" when handle_req = '1' and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"02" else
              "100" when handle_req = '1' and ctl_xfer_request = X"09" else
              "101" when handle_req = '1' and ctl_xfer_request = X"06" and ctl_xfer_value(15 downto 8) = X"03" else
              "000";
              
  is_std_req <= '1' when ctl_xfer_endpoint = X"0" and ctl_xfer_type(6 downto 5) = "00" else
                '0';
                
  is_dev_req <= '1' when ctl_xfer_type(4 downto 0) = "00000" else
                '0';
                
  handle_req <= is_std_req AND is_dev_req;
              
  standart_request <= is_std_req;

  ctl_xfer_data_in_valid <= '1' when state = S_GetDescriptor else
                            '0';

  ctl_xfer_data_in <= USB_DESC(conv_integer(mem_addr));

  ctl_xfer_data_in_last <= '1' when state = S_GetDescriptor and mem_addr = max_mem_addr else
                           '0';

  ctl_xfer_done <= '1';

  ctl_xfer_accept <= '0' when req_type = "000" else
                     '1';

end usb_std_request;
