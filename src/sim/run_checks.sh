#!/bin/bash
# The fast checks (~90 s). 0) ws_bk (iverilog, ~10 s): tb_bk.v, the .sav memory port on the SRAM in
# the SDRAM and on the EEPROM. 1) ws_fb (iverilog, ~40 s): tb_fb.v, three pattern frames through the SRAM
# model to the 1024 x 768 output, pixel by pixel, Vert180 + flickerblend 3 (other modes: -DROT / -DBLEND). 2) The machine (~30 s): builds the model (sim/build.sh) and runs the MiSTer timingtest
# ROM 8 frames: the open boot stub starts the cartridge from the SDRAM (ws_loader -> ws_sdram -> SwanTop),
# the CPU clears the RAM (frames 0-2), then the result table is drawn; frame 7 has a known checksum
# (the first 4 rows of the table, all "o" = pass). PPM of frame 7 in sim/build/tt_007.ppm.
set -e
cd "$(dirname "$0")"
echo "JOB-STAGE: tb_fb"
mkdir -p build
# the hardest mode: turned (Vert180) and the mean of three frames; pixels every 6 clocks (faster)
iverilog -g2005 -DROT=2 -DBLEND=2 -DGAP=4 -o build/tb_fb tb_fb.v ../rtl/karabas/ws_fb.v ../../modules/rtl/mem/kg_sdpram.v
vvp -n build/tb_fb > build/tb_fb.log
grep -E 'PASS|FAIL|pixel|line|checked' build/tb_fb.log
grep -q '^PASS' build/tb_fb.log || exit 1
echo "JOB-STAGE: tb_bk"
iverilog -g2005 -o build/tb_bk tb_bk.v ../rtl/karabas/ws_bk.v ../rtl/karabas/ws_sdram.v sdram_model.v
vvp -n build/tb_bk > build/tb_bk.log
grep -E 'ERROR|tb_bk:' build/tb_bk.log
grep -q 'tb_bk: 0 errors' build/tb_bk.log || exit 1
./build.sh
echo "JOB-STAGE: timingtest"
# from src (the s80x86 reads its microcode ROM from rtl/s80x86/gen); S80=0: the V30MZ model
S80=${S80:-1}
if [ $S80 = 1 ]; then OBJ=obj; SUM=${SUM:-08d7ac19}; F=5; else F=7; OBJ=obj_v30; SUM=${SUM:-08d7ac19}; fi
cd ..
sim/build/$OBJ/Vsim_top --rom ../upstream/mister/testroms/timingtest/timingtest.ws --frames 8 \
	--ppm sim/build/tt --ppm-every 7 --expect-sum $F,$SUM
