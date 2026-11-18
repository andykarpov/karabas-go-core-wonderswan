-- Tang Nano 20K wrapper around the MiSTer SwanTop: only the ports the board uses,
-- savestates / rewind / link / RTC tied off. This is the GHDL synthesis top.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ws_core is
   port
   (
      clk                : in  std_logic;
      reset_in           : in  std_logic;
      pause_in           : in  std_logic;

      EXTRAM_read        : out std_logic;
      EXTRAM_write       : out std_logic;
      EXTRAM_be          : out std_logic_vector(1 downto 0);
      EXTRAM_addr        : out std_logic_vector(24 downto 0);
      EXTRAM_datawrite   : out std_logic_vector(15 downto 0);
      EXTRAM_dataread    : in  std_logic_vector(15 downto 0);
      EXTRAM_ready       : in  std_logic;   -- read data valid / write done (CPU waits for it)

      maskAddr           : in  std_logic_vector(23 downto 0);
      romtype            : in  std_logic_vector(7 downto 0);
      ramtype            : in  std_logic_vector(7 downto 0);
      hasRTC             : in  std_logic;

      bios_wraddr        : in  std_logic_vector(12 downto 0);
      bios_wrdata        : in  std_logic_vector(15 downto 0);
      bios_wr            : in  std_logic;
      bios_wrcolor       : in  std_logic;

      vertical           : out std_logic;
      pixel_out_addr     : out std_logic_vector(14 downto 0);
      pixel_out_data     : out std_logic_vector(11 downto 0);
      pixel_out_we       : out std_logic;

      audio_l            : out std_logic_vector(15 downto 0);
      audio_r            : out std_logic_vector(15 downto 0);

      isColor            : in  std_logic;
      keys               : in  std_logic_vector(10 downto 0)  -- Y1..Y4 X1..X4 Start A B
   );
end entity;

architecture arch of ws_core is
   signal pix_addr : integer range 0 to 32255;
begin
   pixel_out_addr <= std_logic_vector(to_unsigned(pix_addr, 15));

   iSwanTop : entity work.SwanTop
   port map
   (
      clk                => clk,
      clk_ram            => clk,
      reset_in           => reset_in,
      pause_in           => pause_in,

      EXTRAM_doRefresh   => open,
      EXTRAM_read        => EXTRAM_read,
      EXTRAM_write       => EXTRAM_write,
      EXTRAM_be          => EXTRAM_be,
      EXTRAM_addr        => EXTRAM_addr,
      EXTRAM_datawrite   => EXTRAM_datawrite,
      EXTRAM_dataread    => EXTRAM_dataread,
      EXTRAM_ready       => EXTRAM_ready,

      eepromWrite        => open,
      eeprom_addr        => (others => '0'),
      eeprom_din         => (others => '0'),
      eeprom_dout        => open,
      eeprom_req         => '0',
      eeprom_rnw         => '1',

      maskAddr           => maskAddr,
      romtype            => romtype,
      ramtype            => ramtype,
      hasRTC             => hasRTC,

      bios_wraddr        => bios_wraddr,
      bios_wrdata        => bios_wrdata,
      bios_wr            => bios_wr,
      bios_wrcolor       => bios_wrcolor,

      vertical           => vertical,
      pixel_out_addr     => pix_addr,
      pixel_out_data     => pixel_out_data,
      pixel_out_we       => pixel_out_we,

      audio_l            => audio_l,
      audio_r            => audio_r,

      isColor            => isColor,
      fastforward        => '0',
      turbo              => '0',

      KeyY1              => keys(10),
      KeyY2              => keys(9),
      KeyY3              => keys(8),
      KeyY4              => keys(7),
      KeyX1              => keys(6),
      KeyX2              => keys(5),
      KeyX3              => keys(4),
      KeyX4              => keys(3),
      KeyStart           => keys(2),
      KeyA               => keys(1),
      KeyB               => keys(0),

      link_enabled       => '0',
      serial_rx          => '1',
      serial_tx          => open,

      RTC_timestampNew   => '0',
      RTC_timestampIn    => (others => '0'),
      RTC_timestampSaved => (others => '0'),
      RTC_savedtimeIn    => (others => '0'),
      RTC_saveLoaded     => '0',
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
