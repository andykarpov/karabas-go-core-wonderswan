#!/bin/bash
# Post-synthesis check of ws_core: XST of ws_core alone (the options of the board build), netgen to a
# Verilog netlist (UNISIM primitives), iverilog with tb_post.v. Output in sim/post/ (not in git:
# xst/, *.ngc, ws_core_post.v, tb_post). Usage: sim/post/build.sh (from anywhere), then
# sim/post/tb_post +rom=FILE [+cycles=N].
set -e
cd "$(dirname "$0")/../.."
XIL=/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64
P=sim/post
if [ ! -e $P/ws_core.ngc ] || [ -n "$(find $(sed -n 's/^vhdl work "\(.*\)"/\1/p' ws.prj) -newer $P/ws_core.ngc)" ]; then
	echo "JOB-STAGE: xst"
	mkdir -p $P/xst/projnav.tmp
	$XIL/xst -intstyle silent -ifn $P/ws_core.xst -ofn $P/ws_core.syr
fi
if [ ! -e $P/ws_core_post.v ] || [ $P/ws_core.ngc -nt $P/ws_core_post.v ]; then
	echo "JOB-STAGE: netgen"
	$XIL/netgen -intstyle silent -w -sim -ofmt verilog $P/ws_core.ngc $P/ws_core_post.v > $P/netgen.log
fi
echo "JOB-STAGE: iverilog"
python3 $P/taps.py $P/ws_core_post.v $P/ws_core_taps.v
U=/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src
iverilog -g2005 -o $P/tb_post -s tb_post -s glbl -y $U/unisims -Wno-timescale -I $U \
	$P/ws_core_taps.v sim/sim_top.v rtl/karabas/ws_loader.v rtl/karabas/ws_sdram.v sim/sdram_model.v $P/tb_post.v
# the reference: the same testbench on the ghdl Verilog of sim/build.sh (sim/post/tb_ghdl)
if [ -e sim/build/ws_core_ghdl.v ]; then
	iverilog -g2005 -DGHDL -o $P/tb_ghdl -s tb_post sim/build/ws_core_ghdl.v sim/sim_top.v rtl/karabas/ws_loader.v \
		rtl/karabas/ws_sdram.v sim/sdram_model.v $P/tb_post.v
fi
