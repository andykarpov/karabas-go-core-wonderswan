# Hardware

The board connections are the same as in [Open Pocket GBC](https://github.com/LakoMoor/open-pocket-gbc/blob/main/docs/hardware.md): HDMI on board, DualShock 2 on pins 17–20 through the Sipeed adapter, and buttons from header pins to GND with internal pull-ups. There is no SPI LCD in the WonderSwan build; there was no room left for its 13 block RAMs.

| Button | Pin | WonderSwan |
|---|---|---|
| Up / Down / Left / Right | 25 / 26 / 27 / 28 | X1 / X3 / X4 / X2 |
| A | 29 | A |
| B | 30 | B |
| Select | 31 | (menu with Start) |
| Start | 77 | Start |

The Y pad maps to the DualShock 2 buttons △ (Y1), R (Y2), L (Y3) and □ (Y4).

| Board | Function |
|---|---|
| S1 | open / close the menu |
| S2 | reset the game |
| LED0 | lit while loading |
| LED1 | lit while the menu is open |
| USB-C UART | remote control, 115200 8N1 (`tools/remote.py`, protocol in the GBC docs) |

## Memory map

**SDRAM** (8 MB, byte addresses):

| Address | Content |
|---|---|
| `0x000000` | cartridge ROM (up to 6 MB) |
| `0x600000` | cartridge save RAM |
| `0x700000` | three framebuffers of 224×144 × 16 bit |

**SPI flash:**

| Address | Content |
|---|---|
| `0x000000` | bitstream |
| `0x200000` | game directory and ROMs (`tools/make_games.py`) |
