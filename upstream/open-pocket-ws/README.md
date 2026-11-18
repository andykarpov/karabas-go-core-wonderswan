# Open Pocket WS

**WonderSwan / WonderSwan Color on the Sipeed Tang Nano 20K: HDMI, a Pocket-style menu, a new compact V30MZ CPU, built only with open-source tools.**

**Website:** https://lakomoor.github.io/open-pocket-ws/ · [Русская версия](docs/README.ru.md) · Sister project: [Open Pocket GBC](https://github.com/LakoMoor/open-pocket-gbc)

![One Last Lap running on the Tang Nano 20K](docs/img/lap.gif)

The MiSTer WonderSwan core alone needs about 22k LUTs, more than the whole 20.7k-LUT GW2AR-18 FPGA on the board. To make it fit:

- **CPU.** The MiSTer V30MZ CPU (~12k LUTs) is replaced by a microcoded 80186 derived from [s80x86](https://github.com/jamieiles/80x86), about 5k LUTs.
  - It was checked against ~62,000 single-instruction tests: the hardware-generated NEC V20 suite and the MiSTer V30MZ core run in lock-step.
  - V30MZ behaviour was added where s80x86 differed, and several s80x86 bugs were fixed.
  - Instructions are padded to the V30MZ cycle counts, calibrated on real-hardware timing tests.
- **Sprites.** The sprite unit is rewritten around a line buffer: 4.7k → 0.5k LUTs. In simulation it is pixel-identical to the original.
- **Fit.** The whole system uses 75% of the LUTs and 45 of the 46 block RAMs, and meets timing at 37.125 MHz.

| Games (all captured from the board over HDMI) | timingtest: CPU timing on hardware |
|---|---|
| ![games](docs/img/games.png) | ![timingtest](docs/img/timingtest.png) |

## Features

- **WonderSwan Color and mono:** colour or mono is chosen from the cartridge header, or forced in the menu. Up to 15 games live in the SPI flash.
- **HDMI:** 720×480p with audio. The 224×144 picture is scaled 3× to 672×432, with LCD-grid or scanline display modes.
- **Menu:** Resume, Reset, Load game, Display, System (Auto / Color / Mono). The game pauses while the menu is open.
- **Controls:**
  - DualShock 2 on the Sipeed adapter;
  - 8 GPIO buttons;
  - a **USB remote**: play from the PC keyboard or script button presses (`tools/remote.py`).
- **Open boot stub:** the copyrighted Bandai IPL is not needed. A 42-byte stub unlocks the cartridge and jumps to it.
- **Included games:** the [SwanSong Originals](https://github.com/RegionallyFamous/SwanSong-Originals) (MIT, redistribution authorised) and the MiSTer test ROMs.

## Demo

| Loading a game from the menu | Rotate Dungeon | Harpoon Moon | Orbital Courier |
|---|---|---|---|
| ![menu](docs/img/menu.gif) | ![rotate](docs/img/rotate.gif) | ![harpoon](docs/img/harpoon.gif) | ![courier](docs/img/courier.gif) |

The button presses in every GIF were sent over USB by `tools/record.py`.

## Quick start

```sh
./build.sh                         # GHDL netlist + yosys/slang -> nextpnr -> gowin_pack (~10 min)
./flash.sh flash                   # bitstream to the SPI flash (./flash.sh sram = temporary)
python tools/make_games.py build/games.bin games/swansong/one_last_lap.wsc="One Last Lap" ...
./flash.sh games                   # game image at 0x200000
```

More: [docs/build.md](docs/build.md) · [docs/hardware.md](docs/hardware.md) · [docs/cpu.md](docs/cpu.md) (the CPU and how it was verified) · [docs/architecture.md](docs/architecture.md)

## Controls

| WonderSwan | DualShock 2 | GPIO pins | PC remote |
|---|---|---|---|
| X1–X4 (d-pad) | d-pad | 25–28 | arrows |
| A / B | ○ / ✕ | 29 / 30 | x / z |
| Start | Start | 77 | Enter |
| Y1 / Y2 / Y3 / Y4 | △ / R / L / □ | | |
| menu | Select + Start | Select (31) + Start | m (or board button S1) |
| reset | | | r (or board button S2) |

## Resources

| | Used | Available |
|---|---|---|
| LUT4 | 15 685 (75%) | 20 736 |
| Block RAM | 45 | 46 (32 of them hold the 64 KB WonderSwan Color RAM) |
| clk_sys | Fmax ≈ 65 MHz | runs at 37.125 MHz (0.7% faster than a real WonderSwan) |

## Status and limitations

- **Verified on hardware:**
  - the 10 SwanSong games;
  - the MiSTer test ROMs: every opcode page of `timingtest` passes except POPA, which runs 2 cycles slow.
- **Not supported:**
  - RTC (cartridge clock);
  - the serial link port;
  - the internal EEPROM, which keeps only 64 words.
- **Saves are lost on power-off:** cartridge SRAM/EEPROM saves are not written to flash yet.
- **No rotation:** vertical games are shown rotated by 90°, as the WonderSwan sends them.
- **Known CPU differences:**
  - undefined flags after multi-bit shifts;
  - a few MiSTer quirks that look like bugs are not copied: JL/JGE with ZF, opcode 82 flags, ENTER levels.

  Details: [docs/cpu.md](docs/cpu.md).

## Credits and licenses

**GPL-3.0** (see [LICENSE](LICENSE)). Built from:

- [MiSTer WonderSwan core](https://github.com/MiSTer-devel/WonderSwan_MiSTer) by Robert Peip, GPL-2.0-or-later: `rtl/ws/` (modified)
- [s80x86](https://github.com/jamieiles/80x86) by Jamie Iles, GPL-3.0: `rtl/s80x86/` (modified for V30MZ)
- The infrastructure of [Open Pocket GBC](https://github.com/LakoMoor/open-pocket-gbc): HDMI ([hdl-util/hdmi](https://github.com/hdl-util/hdmi)), SDRAM, menu, loader, USB remote
- Test data: [SingleStepTests/v20](https://github.com/SingleStepTests/v20) (MIT, not included in the repository)
- Games: [SwanSong Originals](https://github.com/RegionallyFamous/SwanSong-Originals) © Regionally Famous, MIT; test ROMs from the MiSTer core repository

WonderSwan is a trademark of Bandai. This project is not affiliated with Bandai or Analogue.
