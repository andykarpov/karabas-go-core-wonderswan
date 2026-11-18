-- Tang Nano 20K: compact WonderSwan sprite unit (replaces the MiSTer version, which kept the
-- 32 sprites of two lines in registers and compared all of them in parallel every pixel).
--
-- Every sprite loaded for the next line is rendered into a line buffer (ping-pong, 2 x 256
-- entries in one block RAM). An entry holds two candidates: the highest priority visible
-- sprite pixel (A) and the highest priority visible pixel of a sprite with the SCR2 priority
-- bit (B). Sprites arrive in index order, so the first pixel written wins, like the original
-- (lower index = higher priority). The buffer being built is cleared after clearNext (256
-- writes, the loads wait in a FIFO meanwhile).
-- The display side reads the buffer with the original output timing.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sprites is
   port
   (
      clk            : in  std_logic;
      ce             : in  std_logic;

      startLine      : in  std_logic;
      lineY          : in  std_logic_vector(7 downto 0);
      lineYNext      : in  std_logic_vector(7 downto 0);

      enable         : in  std_logic;
      depth2         : in  std_logic;
      packed         : in  std_logic;

      useWindow      : in  std_logic := '0';
      WinX0          : in  std_logic_vector(7 downto 0) := (others => '0');
      WinY0          : in  std_logic_vector(7 downto 0) := (others => '0');
      WinX1          : in  std_logic_vector(7 downto 0) := (others => '0');
      WinY1          : in  std_logic_vector(7 downto 0) := (others => '0');

      clearNext      : in  std_logic;
      loadNext       : in  std_logic;
      loadIndex      : in  integer range 0 to 31;
      loadData       : in  std_logic_vector(31 downto 0);
      loadColor      : in  std_logic_vector(31 downto 0);

      tileActive     : out std_logic := '0';
      tilePrio       : out std_logic := '0';
      tilePalette    : out std_logic_vector(3 downto 0) := (others => '0');
      tileColor      : out std_logic_vector(3 downto 0) := (others => '0');

      tileActive2    : out std_logic := '0';
      tilePalette2   : out std_logic_vector(3 downto 0) := (others => '0');
      tileColor2     : out std_logic_vector(3 downto 0) := (others => '0')
   );
end entity;

architecture arch of sprites is

   -- load FIFO entry: xPos(45:38) horFlip(37) Scr2Prio(36) windowClip(35) palette(34:32) color(31:0)
   type tfifo is array(0 to 31) of std_logic_vector(45 downto 0);
   signal fifo        : tfifo;
   signal fifo_wp     : unsigned(5 downto 0) := (others => '0');
   signal fifo_rp     : unsigned(5 downto 0) := (others => '0');
   signal fifo_head   : std_logic_vector(45 downto 0);

   -- line buffer: address {buffer, x};
   -- data: unused(17) Av(16) Ac(15:12) Ap(11:9) Aprio(8) Bv(7) Bc(6:3) Bp(2:0)
   signal lb_addr_a   : std_logic_vector(8 downto 0) := (others => '0');
   signal lb_q_a      : std_logic_vector(17 downto 0);
   signal lb_clken_a  : std_logic;
   signal lb_addr_b   : std_logic_vector(8 downto 0);
   signal lb_q_b      : std_logic_vector(17 downto 0);
   signal lb_wren_b   : std_logic;
   signal lb_data_b   : std_logic_vector(17 downto 0);

   signal wr_pend     : std_logic := '0';                    -- write registered, not yet done
   signal wr_addr     : std_logic_vector(8 downto 0) := (others => '0');
   signal wr_data     : std_logic_vector(17 downto 0) := (others => '0');

   signal build_sel   : std_logic := '0';
   signal clr_busy    : std_logic := '0';
   signal clr_addr    : unsigned(7 downto 0) := (others => '0');

   -- render: sprite being drawn and a 2-stage pixel pipeline (read address, RAM data)
   signal busy        : std_logic := '0';
   signal pix         : unsigned(2 downto 0) := (others => '0');
   signal spr         : std_logic_vector(45 downto 0) := (others => '0');
   signal s1_v, s2_v  : std_logic := '0';
   signal s1_vis, s2_vis : std_logic := '0';
   signal s1_x, s2_x  : unsigned(7 downto 0) := (others => '0');
   signal s1_col, s2_col : std_logic_vector(3 downto 0) := (others => '0');
   signal s1_pal, s2_pal : std_logic_vector(2 downto 0) := (others => '0');
   signal s1_pri, s2_pri : std_logic := '0';

   -- display
   signal posX        : unsigned(7 downto 0) := (others => '0');
   signal pixelCount  : integer range 0 to 255 := 255;
   signal disp_sel    : std_logic := '0';
   signal ce_1        : std_logic := '0';
   signal disp_q      : std_logic_vector(17 downto 0) := (others => '0');
   signal disp_valid  : std_logic := '0';

   function pick_color(c : std_logic_vector(31 downto 0); x3 : unsigned(2 downto 0);
                       d2 : std_logic; pk : std_logic) return std_logic_vector is
      variable i : integer;
   begin
      i := to_integer(x3);
      if pk = '0' then
         if d2 = '1' then
            return "00" & c(15 - i) & c(7 - i);
         else
            return c(31 - i) & c(23 - i) & c(15 - i) & c(7 - i);
         end if;
      else
         if d2 = '1' then
            case i is
               when 0 => return "00" & c( 7 downto  6);
               when 1 => return "00" & c( 5 downto  4);
               when 2 => return "00" & c( 3 downto  2);
               when 3 => return "00" & c( 1 downto  0);
               when 4 => return "00" & c(15 downto 14);
               when 5 => return "00" & c(13 downto 12);
               when 6 => return "00" & c(11 downto 10);
               when others => return "00" & c( 9 downto  8);
            end case;
         else
            case i is
               when 0 => return c( 7 downto  4);
               when 1 => return c( 3 downto  0);
               when 2 => return c(15 downto 12);
               when 3 => return c(11 downto  8);
               when 4 => return c(23 downto 20);
               when 5 => return c(19 downto 16);
               when 6 => return c(31 downto 28);
               when others => return c(27 downto 24);
            end case;
         end if;
      end if;
   end function;

begin

   -- port A: render reads (frozen in ce cycles so the data survives the pause)
   -- port B: display read in ce cycles, render writes otherwise
   lb_clken_a <= not ce;
   lb_addr_b  <= (disp_sel & std_logic_vector(posX)) when ce = '1' else
                 (build_sel & std_logic_vector(clr_addr)) when clr_busy = '1' else wr_addr;
   lb_wren_b  <= (wr_pend or clr_busy) and not ce;

   ilinebuf : entity work.dpram
   generic map ( addr_width => 9, data_width => 18 )
   port map
   (
      clock_a   => clk,
      clken_a   => lb_clken_a,
      address_a => lb_addr_a,
      data_a    => (others => '0'),
      wren_a    => '0',
      q_a       => lb_q_a,
      clock_b   => clk,
      clken_b   => '1',
      address_b => lb_addr_b,
      data_b    => lb_data_b,
      wren_b    => lb_wren_b,
      q_b       => lb_q_b
   );

   fifo_head <= fifo(to_integer(fifo_rp(4 downto 0)));
   lb_data_b <= (others => '0') when clr_busy = '1' else wr_data;

   process (clk)
      variable x3      : unsigned(2 downto 0);
      variable col     : std_logic_vector(3 downto 0);
      variable rx      : unsigned(7 downto 0);
      variable wy      : unsigned(7 downto 0);
      variable inside  : std_logic;
      variable outside : std_logic;
      variable vis     : std_logic;
      variable e       : std_logic_vector(17 downto 0);
      variable oldA    : std_logic;
      variable oldB    : std_logic;
   begin
      if rising_edge(clk) then

         -- ---------------------------------------------------------- loads
         if (loadNext = '1' and fifo_wp - fifo_rp /= 32) then
            fifo(to_integer(fifo_wp(4 downto 0))) <= loadData(31 downto 24) & loadData(14) & loadData(13) &
                                                     loadData(12) & loadData(11 downto 9) & loadColor;
            fifo_wp <= fifo_wp + 1;
         end if;

         if (clearNext = '1') then
            -- clear the buffer that is built next (the one not on display)
            clr_busy <= '1';
            clr_addr <= (others => '0');
            fifo_rp <= fifo_wp;
            if (loadNext = '1') then fifo_rp <= fifo_wp; end if;
            busy    <= '0';
            s1_v    <= '0';
            s2_v    <= '0';
            wr_pend <= '0';
         elsif (ce = '0' and clr_busy = '1') then
            -- ------------------------------------------------------ clear (one entry per cycle)
            clr_addr <= clr_addr + 1;
            if (clr_addr = 255) then
               clr_busy <= '0';
            end if;
         elsif (ce = '0') then
            -- ------------------------------------------------------ render (paused in ce cycles)
            if (wr_pend = '1') then
               wr_pend <= '0';                -- the write happens at this edge
            end if;

            -- stage 3: merge the RAM data of stage 2 and register the write
            if (s2_v = '1' and s2_vis = '1') then
               e := lb_q_a;
               oldA := e(16); oldB := e(7);
               if (oldA = '0') then
                  e(16)           := '1';
                  e(15 downto 12) := s2_col;
                  e(11 downto 9)  := s2_pal;
                  e(8)            := s2_pri;
               end if;
               if (oldB = '0') then
                  e(7)          := s2_pri;
                  e(6 downto 3) := s2_col;
                  e(2 downto 0) := s2_pal;
               end if;
               e(17)   := '0';
               wr_data <= e;
               wr_addr <= build_sel & std_logic_vector(s2_x);
               wr_pend <= '1';
            end if;

            -- stage 2: RAM data arrives
            s2_v   <= s1_v;
            s2_vis <= s1_vis;
            s2_x   <= s1_x;
            s2_col <= s1_col;
            s2_pal <= s1_pal;
            s2_pri <= s1_pri;

            -- stage 1: next pixel of the current sprite
            s1_v <= '0';
            if (busy = '0') then
               -- start the next sprite once the previous one is completely written
               if (fifo_rp /= fifo_wp and s1_v = '0' and s2_v = '0' and wr_pend = '0') then
                  spr     <= fifo_head;
                  fifo_rp <= fifo_rp + 1;
                  busy    <= '1';
                  pix     <= (others => '0');
               end if;
            else
               rx := unsigned(spr(45 downto 38)) + pix;
               if (spr(37) = '1') then x3 := 7 - pix; else x3 := pix; end if;
               col := pick_color(spr(31 downto 0), x3, depth2, packed);

               -- window (the line being built is lineYNext)
               wy := unsigned(lineYNext);
               inside := '0';
               if ((rx >= unsigned(WinX0) and rx <= unsigned(WinX1)) or (rx >= unsigned(WinX1) and rx <= unsigned(WinX0))) then
                  if ((wy >= unsigned(WinY0) and wy <= unsigned(WinY1)) or (wy >= unsigned(WinY1) and wy <= unsigned(WinY0))) then
                     inside := '1';
                  end if;
               end if;
               outside := '0';
               if (rx < unsigned(WinX0) or rx > unsigned(WinX1) or wy < unsigned(WinY0) or wy > unsigned(WinY1)) then
                  outside := '1';
               end if;

               vis := '0';
               if (col /= x"0" or (depth2 = '1' and spr(34) = '0')) then
                  if (useWindow = '0' or (inside = '0' and spr(35) = '1') or (outside = '0' and spr(35) = '0')) then
                     vis := '1';
                  end if;
               end if;

               lb_addr_a <= build_sel & std_logic_vector(rx);
               s1_v   <= '1';
               s1_vis <= vis;
               s1_x   <= rx;
               s1_col <= col;
               s1_pal <= spr(34 downto 32);
               s1_pri <= spr(36);
               if (pix = 7) then
                  busy <= '0';
               end if;
               pix <= pix + 1;
            end if;
         end if;

         -- ---------------------------------------------------------- display
         ce_1 <= ce;
         if (ce_1 = '1') then
            disp_q <= lb_q_b;              -- read issued in the ce cycle
         end if;

         if (ce = '1') then
            if (startLine = '1' and enable = '1') then
               pixelCount <= 0;
               posX       <= to_unsigned(0, 8) - 15;
               disp_sel   <= build_sel;
               build_sel  <= not build_sel;
               disp_valid <= '0';
            elsif (pixelCount < 250) then
               pixelCount <= pixelCount + 1;
               posX       <= posX + 1;
               disp_valid <= '1';
               if (disp_valid = '1') then
                  tileActive  <= disp_q(16);
                  tileActive2 <= disp_q(7);
               else
                  tileActive  <= '0';
                  tileActive2 <= '0';
               end if;
               tileColor    <= disp_q(15 downto 12);
               tilePalette  <= '1' & disp_q(11 downto 9);
               tilePrio     <= disp_q(8);
               tileColor2   <= disp_q(6 downto 3);
               tilePalette2 <= '1' & disp_q(2 downto 0);
            end if;
         end if;

      end if;
   end process;

end architecture;
