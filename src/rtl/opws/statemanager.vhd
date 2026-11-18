-- Tang Nano 20K: savestate / rewind manager removed (outputs idle).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity statemanager is
   generic
   (
      Softmap_SaveState_ADDR   : integer;
      Softmap_Rewind_ADDR      : integer
   );
   port
   (
      clk                 : in    std_logic;
      ce                  : in    std_logic;
      reset               : in    std_logic;
      rewind_on           : in    std_logic;
      rewind_active       : in    std_logic;
      savestate_number    : in    integer range 0 to 3;
      save                : in    std_logic;
      load                : in    std_logic;
      sleep_rewind        : out   std_logic := '0';
      vsync               : in    std_logic;
      system_idle         : in    std_logic;
      request_savestate   : out   std_logic := '0';
      request_loadstate   : out   std_logic := '0';
      request_address     : out   integer;
      request_busy        : in    std_logic
   );
end entity;

architecture arch of statemanager is
begin
   sleep_rewind      <= '0';
   request_savestate <= '0';
   request_loadstate <= '0';
   request_address   <= 0;
end architecture;
