-- Portable replacement for the MiSTer altsyncram wrapper: true dual-port RAM,
-- registered address (synchronous read), write-first on each port.
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY dpram IS
   generic (
       addr_width : integer := 8;
       data_width : integer := 8
   );
   PORT
   (
      clock_a     : IN STD_LOGIC;
      clken_a     : IN STD_LOGIC := '1';
      address_a   : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      data_a      : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
      wren_a      : IN STD_LOGIC := '0';
      q_a         : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);

      clock_b     : IN STD_LOGIC;
      clken_b     : IN STD_LOGIC := '1';
      address_b   : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      data_b      : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
      wren_b      : IN STD_LOGIC := '0';
      q_b         : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0)
   );
END dpram;

ARCHITECTURE rtl OF dpram IS
   type t_mem is array(0 to 2**addr_width-1) of std_logic_vector(data_width-1 downto 0);
   shared variable mem : t_mem;
BEGIN
   process (clock_a)
   begin
      if rising_edge(clock_a) then
         if clken_a = '1' then
            if wren_a = '1' then
               mem(to_integer(unsigned(address_a))) := data_a;
            end if;
            q_a <= mem(to_integer(unsigned(address_a)));
         end if;
      end if;
   end process;

   process (clock_b)
   begin
      if rising_edge(clock_b) then
         if clken_b = '1' then
            if wren_b = '1' then
               mem(to_integer(unsigned(address_b))) := data_b;
            end if;
            q_b <= mem(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process;
END rtl;


-- Tang Nano 20K: 16-bit RAM with byte write enables on port A and a read port B
-- (used for the palette RAM; kept in LUT RAM).
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY dpram_be IS
   generic (
       addr_width : integer := 8
   );
   PORT
   (
      clk         : IN  STD_LOGIC;
      address_a   : IN  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      data_a      : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
      be_a        : IN  STD_LOGIC_VECTOR (1 DOWNTO 0);
      address_b   : IN  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
      q_b         : OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
   );
END dpram_be;

ARCHITECTURE rtl OF dpram_be IS
   type t_mem is array(0 to 2**addr_width-1) of std_logic_vector(7 downto 0);
   signal mem_lo, mem_hi : t_mem;
   signal q_async : std_logic_vector(15 downto 0);
BEGIN
   process (clk)
   begin
      if rising_edge(clk) then
         if be_a(0) = '1' then mem_lo(to_integer(unsigned(address_a))) <= data_a(7 downto 0); end if;
         if be_a(1) = '1' then mem_hi(to_integer(unsigned(address_a))) <= data_a(15 downto 8); end if;
         q_b <= q_async;    -- asynchronous read + register: maps to LUT RAM, same latency
      end if;
   end process;
   q_async <= mem_hi(to_integer(unsigned(address_b))) & mem_lo(to_integer(unsigned(address_b)));
END rtl;
