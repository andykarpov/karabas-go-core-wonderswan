#!/bin/bash
# Ф0: the source lists of the XST fit measurements (src/measure/) and the Verilog-2001
# copy of the s80x86-based CPU (SystemVerilog, open-pocket-ws) made with sv2v (/opt/sv2v/sv2v).
#   tools/sv2v.sh measure   -> measure/sv2v_s80/ (one file per module),
#                              measure/ws_mister.prj (MiSTer rtl/ws as is, portable dpram),
#                              measure/ws_hybrid.prj (MiSTer rtl/ws + the open-pocket-ws copies
#                              of rtl/opws + both CPUs; the SwanTop generic KG_CPU_S80 picks one)
# The VHDL goes to XST as is, after tools/vhdl93.py (VHDL-2008 -> VHDL-93, done once, in git).
set -e
cd "$(dirname "$0")/.."
SV2V=${SV2V:-/opt/sv2v/sv2v}
case "$1" in
measure)
	OUT=measure/sv2v_s80
	rm -rf $OUT && mkdir $OUT
	$SV2V -I rtl/s80x86/gen -DSYNTHESIS --top=cpu_s80 $(cat rtl/s80x86/files.f) rtl/cpu/cpu_s80.sv -w $OUT 2>&1 \
		| grep -v -E '^\s*$|Warning: Number literal' || true
	# packages first; rtl/ws/dpram.vhd is the Altera altsyncram wrapper: the portable one of rtl/opws
	PKG="registerpackage reg_swan bus_savestates reg_savestates export"
	OV="dpram eeprom gpu memorymux rtc savestates serial sprites statemanager swanbios swanbioscolor swanTop"
	{ for p in $PKG; do echo "vhdl work \"rtl/ws/$p.vhd\""; done
	  echo 'vhdl work "rtl/opws/dpram.vhd"'
	  for f in rtl/ws/*.vhd; do b=$(basename $f .vhd)
		case " $PKG dpram " in *" $b "*) continue;; esac; echo "vhdl work \"$f\""; done
	} > measure/ws_mister.prj
	{ for p in $PKG; do echo "vhdl work \"rtl/ws/$p.vhd\""; done
	  for f in rtl/ws/*.vhd; do b=$(basename $f .vhd)
		case " $PKG $OV " in *" $b "*) continue;; esac; echo "vhdl work \"$f\""; done
	  for b in $OV; do [ $b = swanTop ] || echo "vhdl work \"rtl/opws/$b.vhd\""; done
	  for f in $OUT/*.v; do echo "verilog work \"$f\""; done
	  echo 'vhdl work "rtl/opws/swanTop.vhd"'
	} > measure/ws_hybrid.prj
	ls $OUT | wc -l ;;
*) echo "usage: $0 measure"; exit 1 ;;
esac
