#!/usr/bin/env python3
"""Calibrate rtl/cpu/v30mz_timing.hex with the expected values of the timingtest ROM
(third_party/WonderSwan_MiSTer/testroms/timingtest), which were measured on real hardware.

Every test runs `fill_prefetch; <instr> [; <instr2>]; dec cx; jnz` 1000 times; the base loop is
54 ticks and one extra cycle per iteration adds 4 ticks. Each test instruction is assembled with
NASM to find its opcode / ModR/M form, and its cycle count replaces the table entry.
Run after tools/gen_timing.py."""
import os, re, subprocess, sys, tempfile

T = 'third_party/WonderSwan_MiSTer/testroms/timingtest'
NASM = os.environ.get('NASM', r'E:\tools\nasm-2.16.03\nasm.exe')
GROUPS = [0x80, 0x81, 0x82, 0x83, 0xc0, 0xc1, 0xd0, 0xd1, 0xd2, 0xd3, 0xf6, 0xf7, 0xfe, 0xff]
PREFIX = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)
MODRM = set(list(range(0x00, 0x40, 8)) + [x + k for x in range(0, 0x40, 8) for k in range(1, 4)]
            + [0x62, 0x63, 0x69, 0x6b, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
               0xc4, 0xc5, 0xc6, 0xc7] + GROUPS)
# cycles of the helper instructions used as the second instruction of dotest2
HELPER = {'add sp, 2': 1, 'sub sp, 2': 1, 'add sp, 16': 1, 'mov cx, ax': 1, 'mov sp, ax': 1,
          'mov bp, ax': 1, 'mov si, ax': 1, 'mov di, ax': 1}

expected = {}
for line in open(os.path.join(T, 'testcalls.asm')):
    m = re.match(r'\s*execute\s+\d+,\s*(\d+),\s*\w+\s*,\s*(\w+)', line)
    if m:
        expected[m.group(2)] = int(m.group(1))

# collect test bodies: test_xxx: ... dotest {a}, name | dotest2 a, {b}, name | macros
src = open(os.path.join(T, 'tests_op.asm')).read() + open(os.path.join(T, 'tests_special.asm')).read()
tests = {}
cur = None
for line in src.split('\n'):
    line = line.split(';')[0].rstrip()
    m = re.match(r'(test_\w+):', line)
    if m:
        cur = m.group(1)
        continue
    m = re.match(r'\s*(SIMPLETEST|LOADIMMIDIATE|PUSHTEST|POPTEST)\s+(.*)', line)
    if m:
        kind, args = m.group(1), [a.strip() for a in re.split(r',(?![^{]*})', m.group(2))]
        if kind == 'SIMPLETEST':
            tests['test_op' + args[-1]] = (args[0].strip('{}'), None)
        elif kind == 'LOADIMMIDIATE':
            tests['test_op' + args[2]] = ('mov %s, %s' % (args[0], args[1]), None)
        elif kind == 'PUSHTEST':
            tests['test_op' + args[1]] = ('push ' + args[0], 'add sp, 2')
        else:
            tests['test_op' + args[1]] = ('pop ' + args[0], 'sub sp, 2')
        continue
    m = re.match(r'\s*dotest2\s+(\{[^}]*\}|[^,]+),\s*(\{[^}]*\}|[^,]+),\s*\w+', line)
    if m and cur:
        tests[cur] = (m.group(1).strip('{} '), m.group(2).strip('{} '))
        continue
    m = re.match(r'\s*dotest\s+(\{[^}]*\}|[^,]+),\s*\w+', line)
    if m and cur:
        tests[cur] = (m.group(1).strip('{} '), None)


def assemble(instr):
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, 't.asm'), 'w').write(
            'BITS 16\nCPU 186\nworkbyte equ 0x100\nworkword equ 0x102\n' + instr + '\n')
        r = subprocess.run([NASM, '-f', 'bin', '-o', os.path.join(d, 't.bin'), os.path.join(d, 't.asm')],
                           capture_output=True, text=True)
        if r.returncode:
            return None
        return open(os.path.join(d, 't.bin'), 'rb').read()


rom = [int(x, 16) for x in open('rtl/cpu/v30mz_timing.hex').read().split()]
changed = 0
for name, (i1, i2) in sorted(tests.items()):
    exp = expected.get(name)
    if not exp or name in ('test_jumponly', 'test_jumponlyUnaligned'):
        continue
    if i2 is not None and i2 not in HELPER:
        continue
    b = assemble(i1)
    if not b:
        continue
    k = 0
    while k < len(b) and b[k] in PREFIX:
        k += 1
    if k >= len(b):
        continue
    op = b[k]
    if 0x70 <= op <= 0x7f or 0xe0 <= op <= 0xe3 or op in (0xe8, 0xe9, 0xea, 0xeb, 0x9a, 0xc2, 0xc3, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xf4, 0x9b):
        continue                                  # control transfers: keep the measured values
    cyc = round((exp - 54) / 4) - (HELPER[i2] if i2 else 0)
    if cyc < 1:
        cyc = 1
    memf = 1 if (op in MODRM and len(b) > k + 1 and (b[k + 1] >> 6) != 3) else 0
    if op in GROUPS:
        idx = 512 + GROUPS.index(op) * 16 + ((b[k + 1] >> 3) & 7) * 2 + memf
    else:
        idx = op * 2 + memf
    if rom[idx] != cyc:
        print('%-26s %-28s %02x%s  table %2d -> %2d' % (name, i1, op, ' mem' if memf else '    ', rom[idx], cyc))
        rom[idx] = cyc
        changed += 1
# tests the parser cannot read (raw db bytes / custom loops), from their expected values:
#   61 POPA: push cx + popa + sub sp,16 + pop cx = (101-54)/4 -> popa 9
#   6B IMUL r,[mem],imm8: (78-54)/4 = 6
rom[0x61 * 2] = rom[0x61 * 2 + 1] = 9
rom[0x6b * 2 + 1] = 6
# 0x82 is an undocumented alias of 0x80: same timing
for i in range(16):
    rom[512 + 2 * 16 + i] = rom[512 + 0 * 16 + i]
open('rtl/cpu/v30mz_timing.hex', 'w', newline='\n').write(''.join('%02x\n' % v for v in rom))
print('%d tests parsed, %d entries changed' % (len(tests), changed))
