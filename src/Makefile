# WonderSwan core: the ISE 14.7 flow of the boards (as core-cpc) and the Ф0 fit checks.
#
#   make minig            a board: <board>-xst (.ngc), <board>-impl (.bin), <board>-core (.kg)
#   make minig-report     LUTs, slices, block RAMs and the timing result of the last build
#   make measure-mister   XST of the MiSTer SwanTop as is (rtl/ws, savestates included)
#   make measure-s80      XST of the hybrid SwanTop with the s80x86 CPU (KG_CPU_S80=1)
#   make measure-v30      XST of the hybrid SwanTop with the MiSTer V30MZ (KG_CPU_S80=0)
#   make measure-report   LUTs, FFs, block RAMs and the XST clock estimate of the three
#   make clean            the intermediate files (not the .bin / .kg files, they are in git)
#
# The source lists: tools/sv2v.sh core (ws.prj, karabas_<board>.prj), tools/sv2v.sh measure
# (measure/*.prj, measure/sv2v_s80/), all in git.
# The tops are measured with -iobuf NO: the logic they keep is what drives the SwanTop ports.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

PART = xc6slx25-ftg256-2
BOARDS = minig
KG = wonderswan.kg
JSON = core.json

# map / par options (cost table 2 by default, the rule of all the cores)
MAP_T_minig ?= 2
MAP = -logic_opt off -ol high -xe n -xt 3 -register_duplication off -r 4 -global_opt off -mt 2 -detail -ir off -pr b -lc auto -power off
PAR = -ol high -xe c -mt 4

INCLUDES = $(wildcard ../modules/rtl/mcu/*.vh)

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

MEASURES = mister s80 v30
PRJ_mister = measure/ws_mister.prj
PRJ_s80 = measure/ws_hybrid.prj
PRJ_v30 = measure/ws_hybrid.prj

.PHONY: all clean measure-report $(MEASURES:%=measure-%) \
	$(BOARDS) $(BOARDS:=-xst) $(BOARDS:=-impl) $(BOARDS:=-core) $(BOARDS:=-report)

all: $(BOARDS)

define board
SRC_$(1) := $$(call prj_src,karabas_$(1).prj)

karabas_$(1).ngc: karabas_$(1).prj karabas_$(1).xst $$(SRC_$(1)) $(INCLUDES)
	mkdir -p xst/projnav.tmp
	$(XIL) xst -intstyle ise -ifn karabas_$(1).xst -ofn karabas_$(1).syr

karabas_$(1).bin: karabas_$(1).ngc karabas_$(1).ucf karabas_$(1).ut
	$(XIL) ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc karabas_$(1).ucf -p $(PART) karabas_$(1).ngc karabas_$(1).ngd
	$(XIL) map -intstyle ise -p $(PART) -w $(MAP) -t $(MAP_T_$(1)) -o karabas_$(1)_map.ncd karabas_$(1).ngd karabas_$(1).pcf
	$(XIL) par -w -intstyle ise $(PAR) karabas_$(1)_map.ncd karabas_$(1).ncd karabas_$(1).pcf
	$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths -xml karabas_$(1).twx karabas_$(1).ncd -o karabas_$(1).twr karabas_$(1).pcf -ucf karabas_$(1).ucf
	$(XIL) bitgen -intstyle ise -f karabas_$(1).ut karabas_$(1).ncd

kg_$(1).stamp: karabas_$(1).bin $(JSON)
	python3 tools/check_osd.py $(JSON)
	python3 make_core.py $(JSON) $(KG) --boards $(1)
	touch $$@

$(1): kg_$(1).stamp
$(1)-xst: karabas_$(1).ngc
$(1)-impl: karabas_$(1).bin
$(1)-core: kg_$(1).stamp
$(1)-report:
	@grep -E "Number of (Slice LUTs|occupied Slices|RAMB16BWERs|RAMB8BWERs):" karabas_$(1)_map.mrp
	@grep -E "constraints? (was|were) met|constraints? not met|Timing Score" karabas_$(1).par | sort -u
endef

$(foreach b,$(BOARDS),$(eval $(call board,$(b))))

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
	rm -f kg_*.stamp
	rm -rf xst $(MEASURES:%=xst_%) _ngo _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach b,$(BOARDS),$(addprefix karabas_$(b),.ngc .ngd .ngr .syr .lso .bld .pcf .ncd _map.ncd \
		_map.ngm _map.map _map.mrp _map.xrpt .par .pad _pad.csv _pad.txt .twr .twx .unroutes .xpi .ptwx .bgn \
		.bit .drc _bitgen.xwbt _summary.xml _usage.xml _xst.xrpt _ngdbuild.xrpt _par.xrpt _guide.ncd))
	rm -f $(foreach m,$(MEASURES),$(addprefix ws_$(m),.ngc .ngr .syr .lso _xst.xrpt)) measure/xst_*.log
