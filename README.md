# WonderSwan core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Bandai WonderSwan and WonderSwan Color for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). A port of the [MiSTer WonderSwan core](https://github.com/MiSTer-devel/WonderSwan_MiSTer) by Robert Peip, with parts of [Open Pocket WS](https://github.com/LakoMoor/open-pocket-ws) by LakoMoor: the compact sprite unit, the open boot stub and the CPU, a V30MZ made from [s80x86](https://github.com/jamieiles/80x86). The MiSTer V30MZ is kept in the sources as an option, but it does not fit the board together with HDMI audio.

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `wonderswan.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `wonderswan.kg` | HDMI | HDMI, analog output (sigma-delta) |
| Karabas Mini G | `wonderswan.kg` | HDMI | HDMI, I2S DAC |

The core file is in `src/`. The Bandai boot ROMs are not needed: an open boot stub starts the cartridge, so there is no boot logo and no owner-name screen. Game images are not included: put your own `.ws` / `.wsc` files on the SD card in `/wonderswan`. Free homebrew games to try the core with: the SwanSong games of [Open Pocket WS](https://github.com/LakoMoor/open-pocket-ws/tree/main/games/swansong) (MIT licence). `mote_sound_terminal.wsc` among them is a good sound test.

Status: checked on Mini G. The Go and Mini builds have not been run on a board yet.

## Features

- **Machines:** WonderSwan (mono) and WonderSwan Color. The cartridge header selects the model, or the OSD forces one.
- **Video:** the 224 x 144 picture scaled 4 x 4 into 1024 x 768 at 60 Hz. The machine runs at its own 75.47 Hz: a frame buffer in the SRAM shows the last complete frame, so frames are never torn. Vertical games can be turned (Vert / Vert180, scaled 3 x 3). Flickerblend mixes the last 2 or 3 frames, for games that flicker sprites.
- **Sound:** stereo over HDMI and on the DAC / analog output.
- **Saves:** the SRAM (8 KB to 512 KB) or the EEPROM (128 bytes to 2 KB) of a cartridge is kept in `/wonderswan/saves/<game>.sav` on the SD card. The file is a raw dump, as MiSTer and the emulators keep it, written a second after the game changes it.
- **Clock:** the cartridge RTC starts with the time of the board clock. A time set in a game is not kept.

Not done: the internal EEPROM of the console (owner name, settings) is not saved; the link cable, save states and fast forward.

## Getting started

1. Copy `wonderswan.kg` (one file for Go, Mini and Mini G) to the root of the SD card.
2. Put your games in `/wonderswan` on the SD card.
3. Choose WonderSwan in the core menu, open the file browser (**Menu+Esc**) and choose a game. Next time the core starts the last game again.

"Menu" is the Windows key of the keyboard.

## OSD menu

| Item | Values | Hotkey |
|---|---|---|
| System | Auto (the header) / Color / Mono | Menu+S |
| Orientation | Auto (turned when the game says it is vertical) / Horz / Vert / Vert180 | Menu+R |
| Flickerblend | Off / 2 frames / 3 frames | |
| Reset | resets the machine | F12 |

## Controls

The WonderSwan has two crosses: X (the d-pad of horizontal games) and Y (the d-pad of vertical games), plus A, B and Start.

| WonderSwan | Keyboard | USB pad |
|---|---|---|
| X pad (up, right, down, left) | arrows | d-pad |
| Y pad: Y1 up, Y2 right, Y3 down, Y4 left | W, D, S, A | X, C, Y, Z |
| A | X | A |
| B | Z | B |
| Start | Enter | Start |

The keyboard and both pads drive the one machine.

## Building

Clone with `--recursive` (the `modules` submodule). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The Mini and Go tops (and the timing part of their ucf) are made from the Mini G top by `src/tools/mktops.py`. The VHDL-2008 of the MiSTer core is converted for XST by `src/tools/vhdl93.py`, and s80x86 to Verilog by `src/tools/sv2v.sh core` (into `src/rtl/s80v`).

Checks: `src/sim/run_checks.sh` (about 1.5 min). It runs the frame buffer (`tb_fb`, pixel by pixel), the save memory bridge (`tb_bk`), and the whole machine in Verilator running the MiSTer timing test ROM. `src/sim/post` compares the XST netlist of the machine with the ghdl model. Save test ROMs (nasm): `src/tests`. The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## Licence

GPL-3.0 (see [LICENSE](LICENSE)). The MiSTer core is GPL-2.0-or-later, s80x86 and Open Pocket WS are GPL-3.0.

WonderSwan is a trademark of Bandai. This project is not affiliated with Bandai.
