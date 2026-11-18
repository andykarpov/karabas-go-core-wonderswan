# Building and flashing

Same toolchain as [Open Pocket GBC](https://github.com/LakoMoor/open-pocket-gbc/blob/main/docs/build.md):

- OSS CAD Suite: yosys + yosys-slang, nextpnr-himbaechel, Apicula, openFPGALoader, Verilator;
- GHDL 6;
- Python 3;
- ffmpeg for the capture tools;
- on Windows, the WinUSB driver on "20K's FRIEND (Interface 0)" (Zadig).

## Build

```sh
./tools/gen_vhdl.sh     # only after changing rtl/ws/*.vhd: GHDL -> rtl/gen/ws_core.v
./tools/gen_cpu.sh      # only after changing the microcode: rtl/s80x86/gen/*
./build.sh              # -> build/ws_top/ws_top.fs
```

`build.sh` runs:

1. `read_slang --single-unit` for the CPU (`rtl/s80x86`, `rtl/cpu`).
2. `read_slang` for the rest, with a black-box stub of the core.
3. `read_verilog -overwrite rtl/gen/ws_core.v` (the GHDL netlist).
4. `synth_gowin`.
5. nextpnr and gowin_pack.

The memories get yosys attributes:

- `no_rw_check` on every `mem`: without it the dual-port RAMs are duplicated.
- `ram_style = "distributed"` on the palette RAM.

`tools/gen_cpu.sh` needs Python packages `textx<3`, `pystache`, `pyyaml` and `setuptools<70` (for example in `.venv`). It also needs `cpp` from MinGW or GCC.

## Flash

```sh
./flash.sh sram         # load into the FPGA (until power-off)
./flash.sh flash        # write to the SPI flash
python tools/make_games.py build/games.bin game1.wsc=Name1 game2.ws=Name2 ...   # up to 15
./flash.sh games        # write the game image at 0x200000
```

The ROM size, save type, RTC flag and colour flag are read from the last 16 bytes of the ROM (the cartridge footer) while it is loaded. The first game starts after power-up.

## Simulation and tests

All test benches are built with Verilator: `verilator_bin` with `VERILATOR_ROOT`, plus MinGW `make`.

| Bench | What it does |
|---|---|
| `tools/build_tb.sh` → `build/vcpu/VCore.exe tests.txt` | single-instruction tests for the CPU |
| `tools/v20conv.py` | converts the SingleStepTests JSON files |
| `sim/ref/cpu_ref.vhd` + `sim/ref_tb.cpp` | runs the MiSTer CPU to produce V30MZ reference results |
| `sim/ws_tb.cpp` | the whole core with a ROM file: writes `build/wsframe*.ppm`; `LAT=n` gives random SDRAM latency, `PAGES=1` steps through timingtest |
| `sim/spr/tb_sprites.vhd` (GHDL) | the new sprite unit against the original |
