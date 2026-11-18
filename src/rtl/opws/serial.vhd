library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.pRegisterBus.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all;

-- WonderSwan EXT-port UART.
--
-- The external signals use inverted UART polarity: the line is low while
-- idle, a start bit is high, data bits are inverted, and the stop bit is low.
-- The core clock enable is the native 3.072 MHz WonderSwan clock, giving
-- exact divisors of 320 clocks/bit at 9600 baud, 80 clocks/bit at 38400,
-- and 16 clocks/bit in the SoC's 192000-baud UART test mode.
entity ws_serial is
   port
   (
      clk               : in  std_logic;
      ce                : in  std_logic;
      reset             : in  std_logic;

      serial_rx         : in  std_logic;
      serial_tx         : out std_logic;
      active            : out std_logic;

      IRQ_SerialSend    : out std_logic;
      IRQ_SerialReceive : out std_logic;

      RegBus_Din        : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr        : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren       : in  std_logic;
      RegBus_rden       : in  std_logic;
      RegBus_word       : in  std_logic;
      RegBus_Dout       : out std_logic_vector(BUS_buswidth-1 downto 0);

      SSBUS_Din         : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr         : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren        : in  std_logic;
      SSBUS_rst         : in  std_logic;
      SSBUS_Dout        : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of ws_serial is
-- Tang Nano 20K: removed to save logic (outputs idle)
begin
   serial_tx         <= '1';
   active            <= '0';
   IRQ_SerialSend    <= '0';
   IRQ_SerialReceive <= '0';
   RegBus_Dout       <= (others => '0');
   SSBUS_Dout        <= (others => '0');
end architecture;
