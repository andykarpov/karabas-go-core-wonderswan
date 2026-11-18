-- ws_core.vhd
--
-- The WonderSwan machine for the Karabas boards: SwanTop of rtl/opws (the hybrid: MiSTer rtl/ws +
-- the open-pocket-ws parts, the MiSTer V30MZ with KG_CPU_S80 = 0) with only the ports the board uses
-- and plain vectors for the Verilog top (pixel_out_addr is an integer in SwanTop). Savestates,
-- rewind, the serial link and the RTC are tied off (Ф1); after open-pocket-ws ws_core.vhd.
-- Ф2: the port of the cartridge EEPROM (eeprom_*, clk_ram) for the .sav file (ws_bk.v), the time
-- of the cartridge RTC (MiSTer rtc.vhd) from the RTC of the firmware: RTC_savedtimeIn (BCD) is taken
-- when RTC_saveLoaded rises; the timestamps stay 0 (no catch-up, the time is the current one).

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ws_core is
   generic
   (
      KG_CPU_S80 : integer := 0
   );
   port
   (
      clk                : in  std_logic;   -- 36.864 MHz
      clk_ram            : in  std_logic;   -- 110.592 MHz (3 x clk)
      reset_in           : in  std_logic;
      pause_in           : in  std_logic;

      EXTRAM_doRefresh   : out std_logic;
      EXTRAM_read        : out std_logic;
      EXTRAM_write       : out std_logic;
      EXTRAM_be          : out std_logic_vector(1 downto 0);
      EXTRAM_addr        : out std_logic_vector(24 downto 0);
      EXTRAM_datawrite   : out std_logic_vector(15 downto 0);
      EXTRAM_dataread    : in  std_logic_vector(15 downto 0);
      EXTRAM_ready       : in  std_logic;

      eepromWrite        : out std_logic;
      eeprom_addr        : in  std_logic_vector(9 downto 0);
      eeprom_din         : in  std_logic_vector(15 downto 0);
      eeprom_dout        : out std_logic_vector(15 downto 0);
      eeprom_req         : in  std_logic;
      eeprom_rnw         : in  std_logic;

      RTC_savedtimeIn    : in  std_logic_vector(41 downto 0);
      RTC_saveLoaded     : in  std_logic;

      maskAddr           : in  std_logic_vector(23 downto 0);
      romtype            : in  std_logic_vector(7 downto 0);
      ramtype            : in  std_logic_vector(7 downto 0);
      hasRTC             : in  std_logic;

      vertical           : out std_logic;
      pixel_out_addr     : out std_logic_vector(14 downto 0);
      pixel_out_data     : out std_logic_vector(11 downto 0);
      pixel_out_we       : out std_logic;

      audio_l            : out std_logic_vector(15 downto 0);
      audio_r            : out std_logic_vector(15 downto 0);

      isColor            : in  std_logic;
      keys               : in  std_logic_vector(10 downto 0)  -- Start B A Y4 Y3 Y2 Y1 X4 X3 X2 X1 (ws_kbd.v)
   );
end entity;

architecture arch of ws_core is
   signal pix_addr : integer range 0 to 32255;
begin
   pixel_out_addr <= std_logic_vector(to_unsigned(pix_addr, 15));

   iSwanTop : entity work.SwanTop
   generic map
   (
      is_simu    => '0',
      KG_CPU_S80 => KG_CPU_S80
   )
   port map
   (
      clk                => clk,
      clk_ram            => clk_ram,
      reset_in           => reset_in,
      pause_in           => pause_in,

      EXTRAM_doRefresh   => EXTRAM_doRefresh,
      EXTRAM_read        => EXTRAM_read,
      EXTRAM_write       => EXTRAM_write,
      EXTRAM_be          => EXTRAM_be,
      EXTRAM_addr        => EXTRAM_addr,
      EXTRAM_datawrite   => EXTRAM_datawrite,
      EXTRAM_dataread    => EXTRAM_dataread,
      EXTRAM_ready       => EXTRAM_ready,

      eepromWrite        => eepromWrite,
      eeprom_addr        => eeprom_addr,
      eeprom_din         => eeprom_din,
      eeprom_dout        => eeprom_dout,
      eeprom_req         => eeprom_req,
      eeprom_rnw         => eeprom_rnw,

      maskAddr           => maskAddr,
      romtype            => romtype,
      ramtype            => ramtype,
      hasRTC             => hasRTC,

      bios_wraddr        => (others => '0'),   -- the open boot stub of rtl/opws/swanbios*.vhd
      bios_wrdata        => (others => '0'),
      bios_wr            => '0',
      bios_wrcolor       => '0',

      vertical           => vertical,
      pixel_out_addr     => pix_addr,
      pixel_out_data     => pixel_out_data,
      pixel_out_we       => pixel_out_we,

      audio_l            => audio_l,
      audio_r            => audio_r,

      isColor            => isColor,
      fastforward        => '0',
      turbo              => '0',

      KeyY1              => keys(4),
      KeyY2              => keys(5),
      KeyY3              => keys(6),
      KeyY4              => keys(7),
      KeyX1              => keys(0),
      KeyX2              => keys(1),
      KeyX3              => keys(2),
      KeyX4              => keys(3),
      KeyStart           => keys(10),
      KeyA               => keys(8),
      KeyB               => keys(9),

      link_enabled       => '0',
      serial_rx          => '1',
      serial_tx          => open,

      RTC_timestampNew   => '0',
      RTC_timestampIn    => (others => '0'),
      RTC_timestampSaved => (others => '0'),
      RTC_savedtimeIn    => RTC_savedtimeIn,
      RTC_saveLoaded     => RTC_saveLoaded,
      RTC_timestampOut   => open,
      RTC_savedtimeOut   => open,

      increaseSSHeaderCount => '0',
      save_state         => '0',
      load_state         => '0',
      savestate_number   => 0,
      state_loaded       => open,

      SAVE_out_Din       => open,
      SAVE_out_Dout      => (others => '0'),
      SAVE_out_Adr       => open,
      SAVE_out_rnw       => open,
      SAVE_out_ena       => open,
      SAVE_out_be        => open,
      SAVE_out_done      => '1',

      rewind_on          => '0',
      rewind_active      => '0'
   );
end architecture;
