library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRegisterBus.all;  
use work.pReg_swan.all;

entity rtc is
   port 
   (
      clk                  : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      hasRTC               : in  std_logic;
      
      RTC_timestampNew     : in  std_logic;                     -- new current timestamp from system
      RTC_timestampIn      : in  std_logic_vector(31 downto 0); -- timestamp in seconds, current time
      RTC_timestampSaved   : in  std_logic_vector(31 downto 0); -- timestamp in seconds, saved time
      RTC_savedtimeIn      : in  std_logic_vector(41 downto 0); -- time structure, loaded
      RTC_saveLoaded       : in  std_logic;                     -- must be 0 when loading new game, should go and stay 1 when RTC was loaded and values are valid
      RTC_timestampOut     : out std_logic_vector(31 downto 0); -- timestamp to be saved
      RTC_savedtimeOut     : out std_logic_vector(41 downto 0); -- time structure to be saved

      sleep_savestate      : in  std_logic;

      RegBus_Din           : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr           : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren          : in  std_logic;
      RegBus_rden          : in  std_logic;
      RegBus_rst           : in  std_logic;
      RegBus_Dout          : out std_logic_vector(BUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of rtc is
-- Tang Nano 20K: removed to save logic (outputs idle)
begin
   RTC_timestampOut <= (others => '0');
   RTC_savedtimeOut <= (others => '0');
   RegBus_Dout      <= (others => '0');
end architecture;
