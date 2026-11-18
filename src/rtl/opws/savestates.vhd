-- Tang Nano 20K: savestates removed. Keeps only the reset behaviour of the MiSTer
-- module (reset_in -> reset_out / RegBus_rst / BUS_rst one clock later).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.pBus_savestates.all;

entity savestates is
   port
   (
      clk                     : in     std_logic;
      ce                      : in     std_logic;
      reset_in                : in     std_logic;
      reset_out               : out    std_logic := '0';
      RegBus_rst              : out    std_logic := '0';
      ramtype                 : in     std_logic_vector(7 downto 0);
      load_done               : out    std_logic := '0';
      increaseSSHeaderCount   : in     std_logic;
      save                    : in     std_logic;
      load                    : in     std_logic;
      savestate_address       : in     integer;
      savestate_busy          : out    std_logic;
      system_idle             : in     std_logic;
      savestate_slow          : out    std_logic := '0';
      BUS_Din                 : out    std_logic_vector(SSBUS_buswidth-1 downto 0) := (others => '0');
      BUS_Adr                 : buffer std_logic_vector(SSBUS_busadr-1 downto 0) := (others => '0');
      BUS_wren                : out    std_logic := '0';
      BUS_rst                 : out    std_logic := '0';
      BUS_Dout                : in     std_logic_vector(SSBUS_buswidth-1 downto 0) := (others => '0');
      loading_savestate       : out    std_logic := '0';
      saving_savestate        : out    std_logic := '0';
      sleep_savestate         : out    std_logic := '0';
      Save_busy               : in     std_logic;
      Save_RAMAddr            : buffer std_logic_vector(18 downto 0) := (others => '0');
      Save_RAMRdEn            : out    std_logic_vector( 2 downto 0) := (others => '0');
      Save_RAMWrEn            : out    std_logic_vector( 2 downto 0) := (others => '0');
      Save_RAMWriteData       : out    std_logic_vector(15 downto 0) := (others => '0');
      Save_RAMReadData_REG    : in     std_logic_vector( 7 downto 0);
      Save_RAMReadData_RAM    : in     std_logic_vector(15 downto 0);
      Save_RAMReadData_SRAM   : in     std_logic_vector(15 downto 0);
      bus_out_Din             : out    std_logic_vector(63 downto 0) := (others => '0');
      bus_out_Dout            : in     std_logic_vector(63 downto 0);
      bus_out_Adr             : buffer std_logic_vector(25 downto 0) := (others => '0');
      bus_out_rnw             : out    std_logic := '0';
      bus_out_ena             : out    std_logic := '0';
      bus_out_be              : out    std_logic_vector(7 downto 0) := (others => '0');
      bus_out_done            : in     std_logic
   );
end entity;

architecture arch of savestates is
begin
   savestate_busy    <= '0';
   load_done         <= '0';
   savestate_slow    <= '0';
   BUS_Din           <= (others => '0');
   BUS_Adr           <= (others => '0');
   BUS_wren          <= '0';
   loading_savestate <= '0';
   saving_savestate  <= '0';
   sleep_savestate   <= '0';
   Save_RAMAddr      <= (others => '0');
   Save_RAMRdEn      <= (others => '0');
   Save_RAMWrEn      <= (others => '0');
   Save_RAMWriteData <= (others => '0');
   bus_out_Din       <= (others => '0');
   bus_out_Adr       <= (others => '0');
   bus_out_rnw       <= '0';
   bus_out_ena       <= '0';
   bus_out_be        <= (others => '0');
   process (clk)
   begin
      if rising_edge(clk) then
         reset_out  <= reset_in;
         RegBus_rst <= reset_in;
         BUS_rst    <= reset_in;
      end if;
   end process;
end architecture;
