#!/usr/bin/env python3
# taps.py NETLIST OUT: copies the netgen netlist and adds tap_* wires inside module ws_core: the Q net
# of a flip-flop instance found by its XST name (the names have dots, which iverilog does not take in
# hierarchical references from the testbench).
import re, sys
src, out = sys.argv[1], sys.argv[2]
text = open(src).read()
C = 'iSwanTop/gcpu_v30.icpu/'
def q(inst):
    m = re.search(r'\\' + re.escape(inst) + r'  \((.*?)\n  \);', text, re.S)
    if not m:
        sys.exit('taps.py: no instance ' + inst)
    return re.search(r'\.Q\((.*?)\),?\s*(?:\n|$)', m.group(1)).group(1)
def bus(name, n):
    return '{ ' + ', '.join(q(f'{C}{name}_{i}') for i in range(n - 1, -1, -1)) + ' }'
taps = [
    f'wire [19:0] tap_cpu_addr = {bus("bus_addr", 20)};',
    f'wire tap_cpu_rd = {q(C + "bus_read_i")};',
    f'wire tap_cpu_wr = {q(C + "bus_write_i")};',
    f'wire [15:0] tap_ip = {bus("regs_reg_ip", 16)};',
    f'wire [15:0] tap_cs = {bus("regs_reg_cs", 16)};',
    f'wire [4:0] tap_opcode = {bus("opcode", 5)};',
    f'wire [4:0] tap_delay = {bus("delay", 5)};',
    f'wire [3:0] tap_pfcount = {bus("prefetchCount", 4)};',
    f'wire tap_halt = {q(C + "halt")};',
    'wire [19:1] tap_stage = { ' + ', '.join(q(f'{C}cpustage_FSM_FFd{i}') for i in range(19, 0, -1)) + ' };',
    'wire [2:1] tap_opstep = { ' + ', '.join(q(f'{C}opstep_FSM_FFd{i}') for i in range(2, 0, -1)) + ' };',
]
lines = text.split('\n')
end = lines.index('endmodule')
lines[end:end] = taps
open(out, 'w').write('\n'.join(lines))
