#!/bin/bash
# Builds the verilator model of sim_top.v: the VHDL of ws.prj through ghdl --synth --out=verilog
# (ws_core, KG_CPU_S80 = 0), the Verilog of rtl/karabas it uses, sdram_model.v, sim_top.v and the
# harness sim_ws.cpp. Output in src/sim/build/ (obj/Vsim_top). Rebuilds only when a source is newer.
set -e
cd "$(dirname "$0")"
SRC=..
B=build
HERE=$PWD
mkdir -p $B/ghdl
VHDL=$(sed -n 's/^vhdl work "\(.*\)"/\1/p' $SRC/ws.prj)
OWN="rtl/karabas/ws_loader.v rtl/karabas/ws_sdram.v sim/sdram_model.v sim/sim_top.v"
GEN=$B/ws_core_ghdl.v
newer() { [ ! -e "$1" ] || [ -n "$(cd $SRC && find $2 -newer sim/$1 2>/dev/null)" ]; }

if newer $GEN "$VHDL sim/build.sh"; then
	echo "JOB-STAGE: ghdl"
	(cd $SRC && ghdl --synth --out=verilog --std=08 -frelaxed -fsynopsys -Wno-shared -Wno-hide -Wno-binding \
		--workdir=sim/$B/ghdl $VHDL -e ws_core 2> sim/$B/ghdl.log) > $GEN.tmp
	grep -q error $B/ghdl.log && { grep error $B/ghdl.log | head; exit 1; }
	mv $GEN.tmp $GEN
fi

EXE=$B/obj/Vsim_top
if newer $EXE "$OWN sim/$GEN sim/sim_ws.cpp sim/build.sh"; then
	echo "JOB-STAGE: verilator"
	(cd $SRC && verilator -O3 --x-assign fast --x-initial fast --default-language 1364-2005 \
		-Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT -Wno-WIDTH \
		-Wno-CASEINCOMPLETE --no-timing --top-module sim_top -Mdir sim/$B/obj --cc sim/$GEN $OWN \
		--exe $HERE/sim_ws.cpp -o Vsim_top > sim/$B/verilator.log 2>&1) || { grep -E '%Error' $B/verilator.log | head -20; exit 1; }
	echo "JOB-STAGE: c++"
	make -s -j8 -C $B/obj -f Vsim_top.mk OPT_FAST=-O2 > $B/make.log 2>&1 || { tail -30 $B/make.log; exit 1; }
fi
