#!/usr/bin/env python3
"""Build the V30MZ instruction timing ROM (rtl/cpu/v30mz_timing.hex, 1024 x 6 bit) from the
reference measurements in build/ref/*.txt (MiSTer V30MZ core, steady-state cycle counts).

ROM index (see rtl/cpu/cpu_s80.sv):
  0..511     {opcode, mem}                     plain opcodes (mem = ModR/M memory form)
  512..735   512 + group*16 + reg*2 + mem      ModR/M group opcodes (GROUPS below)
  768..799   768 + jcc index                   conditional jump / loop, branch taken
Cycle counts exclude prefixes (1 cycle each, added by the hardware).
"""
import collections, os, statistics

PREFIX = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)
GROUPS = [0x80, 0x81, 0x82, 0x83, 0xc0, 0xc1, 0xd0, 0xd1, 0xd2, 0xd3, 0xf6, 0xf7, 0xfe, 0xff]
JCC = list(range(0x70, 0x80)) + [0xe0, 0xe1, 0xe2, 0xe3]
MODRM = set(list(range(0x00, 0x40, 8)) + [x + k for x in range(0, 0x40, 8) for k in range(1, 4)]
            + [0x62, 0x63, 0x69, 0x6b, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
               0xc4, 0xc5, 0xc6, 0xc7] + GROUPS)
INSN_LEN_JCC = {**{o: 2 for o in JCC}}


def tests(fn):
    l = open(fn).read().split('\n')
    for i in range(len(l)):
        if l[i].startswith('T '):
            yield l[i:i + 7]


samples = collections.defaultdict(list)
for fn in sorted(os.listdir('build/ref')):
    for t in tests('build/ref/' + fn):
        ini = list(map(int, t[1].split()[1:]))
        fin = list(map(int, t[3].split()[1:]))
        m = list(map(int, t[2].split()[1:]))
        mem = dict(zip(m[1::2], m[2::2]))
        lin = ini[4] * 16 + ini[12]
        b = [mem.get((lin + k) & 0xFFFFF, 0x90) for k in range(8)]
        k = 0
        while b[k] in PREFIX:
            k += 1
        if any(x in (0xf2, 0xf3) for x in b[:k]):
            continue                      # REP timing is modelled separately
        op = b[k]
        c = int(t[6].split()[1])          # prefixes are free on the V30MZ
        # a control transfer to an odd address costs one cycle more (added by the hardware)
        reg_ = (b[k + 1] >> 3) & 7
        transfer = op in (0xe8, 0xe9, 0xea, 0xeb, 0x9a, 0xc2, 0xc3, 0xca, 0xcb, 0xcc, 0xcd, 0xcf) or                    (op == 0xff and reg_ in (2, 3, 4, 5))
        if op in JCC:
            transfer = fin[12] != ((ini[12] + k + 2) & 0xFFFF)
        if transfer and (fin[12] & 1):
            c -= 1
        memf = 1 if (op in MODRM and (b[k + 1] >> 6) != 3) else 0
        if op in GROUPS:
            reg = (b[k + 1] >> 3) & 7
            samples[512 + GROUPS.index(op) * 16 + reg * 2 + memf].append(c)
        elif op in JCC:
            taken = fin[12] != ((ini[12] + k + 2) & 0xFFFF)
            samples[768 + JCC.index(op) if taken else op * 2].append(c)
        else:
            samples[op * 2 + memf].append(c)

rom = [1] * 1024
for idx, v in samples.items():
    rom[idx] = max(1, min(63, int(statistics.median(v) + 0.5)))
# memory forms that never occurred in the data (e.g. opcodes without ModR/M): copy the reg value
for op in range(256):
    if not samples.get(op * 2 + 1):
        rom[op * 2 + 1] = rom[op * 2]
os.makedirs('rtl/cpu', exist_ok=True)
with open('rtl/cpu/v30mz_timing.hex', 'w', newline='\n') as f:
    for v in rom:
        f.write('%02x\n' % v)
print('timing ROM: %d measured entries' % len(samples))
for name, idx in [('NOP', 0x90 * 2), ('ADD r/m mem', 0x00 * 2 + 1), ('MOV r,r', 0x8b * 2), ('JMP short', 0xeb * 2),
                  ('JZ not taken', 0x74 * 2), ('JZ taken', 768 + JCC.index(0x74)), ('DIV r/m16', 512 + 11 * 16 + 6 * 2),
                  ('CALL near', 0xe8 * 2), ('RET', 0xc3 * 2), ('INT n', 0xcd * 2), ('IRET', 0xcf * 2)]:
    print('  %-14s %d' % (name, rom[idx]))
