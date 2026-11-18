#!/bin/bash
# The fast checks (~50 s). 1) ws_fb (iverilog, ~20 s): tb_fb.v, a pattern frame through the SRAM model
# to the 1024 x 768 output, pixel by pixel. 2) The machine (~30 s): builds the model (sim/build.sh) and runs the MiSTer timingtest
# ROM 8 frames: the open boot stub starts the cartridge from the SDRAM (ws_loader -> ws_sdram -> SwanTop),
# the CPU clears the RAM (frames 0-2), then the result table is drawn; frame 7 has a known checksum
# (the first 4 rows of the table, all "o" = pass). PPM of frame 7 in sim/build/tt_007.ppm.
set -e
cd "$(dirname "$0")"
echo "JOB-STAGE: tb_fb"
mkdir -p build
iverilog -g2005 -o build/tb_fb tb_fb.v ../rtl/karabas/ws_fb.v ../../modules/rtl/mem/kg_sdpram.v
vvp -n build/tb_fb > build/tb_fb.log
grep -E 'PASS|FAIL|pixel|line|checked' build/tb_fb.log
grep -q '^PASS' build/tb_fb.log || exit 1
./build.sh
echo "JOB-STAGE: timingtest"
# from src (the s80x86 reads its microcode ROM from rtl/s80x86/gen); S80=0: the V30MZ model
S80=${S80:-1}
if [ $S80 = 1 ]; then OBJ=obj; SUM=${SUM:-08d7ac19}; F=5; else F=7; OBJ=obj_v30; SUM=${SUM:-08d7ac19}; fi
cd ..
sim/build/$OBJ/Vsim_top --rom ../upstream/mister/testroms/timingtest/timingtest.ws --frames 8 \
	--ppm sim/build/tt --ppm-every 7 --expect-sum $F,$SUM
