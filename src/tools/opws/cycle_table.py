#!/usr/bin/env python3
"""Derive V30MZ instruction cycle counts from the reference bench output (build/ref/*.txt).
C = clock-enable ticks from reset release to the end of the instruction; the constant start-up
part is measured with NOP and subtracted.
Prints per opcode (and per memory/register form for ModR/M opcodes) the median cycle count."""
import collections, os, statistics, sys

PREFIX = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)
HAS_MODRM = set(list(range(0x00, 0x40, 8)) + [x + k for x in range(0, 0x40, 8) for k in range(1, 4)]
                + [0x62, 0x63, 0x69, 0x6b] + list(range(0x80, 0x90)) + [0xc0, 0xc1, 0xc4, 0xc5, 0xc6, 0xc7]
                + list(range(0xd0, 0xd4)) + list(range(0xd8, 0xe0)) + [0xf6, 0xf7, 0xfe, 0xff])

def tests(fn):
    l = open(fn).read().split('\n')
    for i in range(len(l)):
        if l[i].startswith('T '):
            yield l[i:i + 7]

data = collections.defaultdict(list)
for fn in sorted(os.listdir('build/ref')):
    for t in tests('build/ref/' + fn):
        ini = list(map(int, t[1].split()[1:]))
        m = list(map(int, t[2].split()[1:]))
        mem = dict(zip(m[1::2], m[2::2]))
        lin = ini[4] * 16 + ini[12]
        b = [mem.get((lin + k) & 0xFFFFF, 0x90) for k in range(8)]
        k = 0
        while b[k] in PREFIX:
            k += 1
        op = b[k]
        form = ''
        if op in HAS_MODRM:
            form = 'm' if (b[k + 1] >> 6) != 3 else 'r'
        rep = any(x in (0xf2, 0xf3) for x in b[:k])
        c = int(t[6].split()[1])
        data[(fn[:-4], form, k, rep)].append((c, ini[2]))

base = 1   # C is measured after a NOP lead-in: it is the instruction's own cycle count
for key in sorted(data):
    vals = [c for c, _ in data[key]]
    if key[3]:
        continue
    print('%-6s %s pre=%d n=%4d cycles=%g (min %d max %d)' % (key[0], key[1] or '-', key[2], len(vals),
          statistics.median(vals), min(vals), max(vals)))
