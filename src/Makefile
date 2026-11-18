# WonderSwan core: the Ф0 fit checks (the board flow comes in Ф1).
#
#   make measure-mister   XST of the MiSTer SwanTop as is (rtl/ws, savestates included)
#   make measure-s80      XST of the hybrid SwanTop with the s80x86 CPU (KG_CPU_S80=1)
#   make measure-v30      XST of the hybrid SwanTop with the MiSTer V30MZ (KG_CPU_S80=0)
#   make measure-report   LUTs, FFs, block RAMs and the XST clock estimate of the three
#   make clean            the intermediate files
#
# The source lists: tools/sv2v.sh measure (measure/*.prj, measure/sv2v_s80/, in git).
# The tops are measured with -iobuf NO: the logic they keep is what drives the SwanTop ports.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

MEASURES = mister s80 v30
PRJ_mister = measure/ws_mister.prj
PRJ_s80 = measure/ws_hybrid.prj
PRJ_v30 = measure/ws_hybrid.prj

.PHONY: clean measure-report $(MEASURES:%=measure-%)

define measure
ws_$(1).ngc: measure/ws_$(1).xst $(PRJ_$(1)) $$(call prj_src,$(PRJ_$(1))) rtl/s80x86/gen/microcode.bin rtl/cpu/v30mz_timing.hex
	mkdir -p xst_$(1)/projnav.tmp
	$(XIL) xst -intstyle ise -ifn measure/ws_$(1).xst -ofn ws_$(1).syr > measure/xst_$(1).log
measure-$(1): ws_$(1).ngc
endef
$(foreach m,$(MEASURES),$(eval $(call measure,$(m))))

measure-report:
	@for m in $(MEASURES); do f=ws_$$m.syr; [ -f $$f ] || continue; echo "== $$m"; \
	sed -n '/Device utilization summary/,/Partition Resource Summary/p' $$f \
		| grep -E "Number of (Slice Registers|Slice LUTs|used as Memory|Block RAM/FIFO|DSP48)"; \
	grep -E "Minimum period" $$f | sort -u | head -3; done

clean:
	rm -rf $(MEASURES:%=xst_%) _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach m,$(MEASURES),$(addprefix ws_$(m),.ngc .ngr .syr .lso _xst.xrpt)) measure/xst_*.log
