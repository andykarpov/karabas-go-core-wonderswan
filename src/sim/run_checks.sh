#!/bin/bash
# The fast check of the machine (~30 s): builds the model (sim/build.sh) and runs the MiSTer timingtest
# ROM 8 frames: the open boot stub starts the cartridge from the SDRAM (ws_loader -> ws_sdram -> SwanTop),
# the CPU clears the RAM (frames 0-2), then the result table is drawn; frame 7 has a known checksum
# (the first 4 rows of the table, all "o" = pass). PPM of frame 7 in sim/build/tt_007.ppm.
set -e
cd "$(dirname "$0")"
./build.sh
echo "JOB-STAGE: timingtest"
build/obj/Vsim_top --rom ../../upstream/mister/testroms/timingtest/timingtest.ws --frames 8 \
	--ppm build/tt --ppm-every 7 --expect-sum 7,08d7ac19
