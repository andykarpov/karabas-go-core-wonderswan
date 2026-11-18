#!/usr/bin/env python3
"""VHDL-2008 -> VHDL-93 fixes for XST (ISE 14.7), applied in place to the imported
WonderSwan sources (MiSTer rtl/ws and the open-pocket-ws copies in rtl/opws).

  tools/vhdl93.py FILE...         apply the fixes; prints what it changed

Fixes (each change is marked "-- karabas"):
  * process (all): replaced by an explicit sensitivity list = every signal / port of the
    file that the process body mentions;
  * boolean conditions on std_logic (the CONDITIONS table);
  * reads of 'out' ports (VHDL-2008 only): the port is driven from a new internal signal
    <port>_i, and every use of the port in the architecture body uses <port>_i.
The script is idempotent: a file already fixed is left as it is.
"""
import re
import sys

ID = re.compile(r'\b[A-Za-z_][A-Za-z0-9_]*\b')


def strip_comments(s):
    return re.sub(r'--[^\n]*', '', s)


def entity_ports(txt):
    """{name: (mode, type text, default)} of the first entity."""
    m = re.search(r'\bentity\s+\w+\s+is(.*?)\bend\b', txt, re.S | re.I)
    ports = {}
    if not m:
        return ports
    body = strip_comments(m.group(1))
    pm = re.search(r'\bport\s*\((.*)\)\s*;', body, re.S | re.I)
    if not pm:
        return ports
    for decl in pm.group(1).split(';'):
        d = re.match(r'\s*([\w\s,]+?)\s*:\s*(in|out|inout|buffer)\s+(.*)', decl, re.S | re.I)
        if not d:
            continue
        typ = ' '.join(d.group(3).split())
        default = None
        if ':=' in typ:
            typ, default = [x.strip() for x in typ.split(':=', 1)]
        for n in d.group(1).split(','):
            ports[n.strip()] = (d.group(2).lower(), typ, default)
    return ports


def signals(txt):
    names = set()
    for m in re.finditer(r'^\s*signal\s+([\w\s,]+?)\s*:', strip_comments(txt), re.M | re.I):
        names.update(n.strip() for n in m.group(1).split(','))
    return names


def fix_process_all(txt, known, outs=()):
    # out ports cannot be in a sensitivity list (VHDL-93)
    out, changed = [], 0
    pos = 0
    for m in re.finditer(r'\bprocess\s*\(\s*all\s*\)', txt, re.I):
        end = re.search(r'\bend\s+process\b', txt[m.end():], re.I)
        body = strip_comments(txt[m.end():m.end() + end.start()])
        used = []
        for w in ID.findall(body):
            if w in known and w not in used and w not in outs:
                used.append(w)
        out.append(txt[pos:m.start()])
        out.append('process (%s) -- karabas: was process (all), VHDL-93 (XST)' % ', '.join(used))
        pos = m.end()
        changed += 1
    out.append(txt[pos:])
    return ''.join(out), changed


def out_ports_read(arch, ports):
    """'out' ports that the architecture body reads (anything but the target of <=)."""
    code = strip_comments(arch)
    read = []
    for name, (mode, _, _) in ports.items():
        if mode != 'out':
            continue
        for m in re.finditer(r'\b%s\b' % re.escape(name), code):
            after = code[m.end():m.end() + 40]
            # target of an assignment: "name <=" or "name(...) <="
            if re.match(r'\s*(\([^;]*?\))?\s*<=', after):
                continue
            # formal of a port map association "name =>"
            if re.match(r'\s*=>', after):
                continue
            # an attribute (name'length, name'range): legal on an out port
            if after.startswith("'"):
                continue
            # a bare actual of a port map, named ("x => name,") or positional ("(.., name, ..)"):
            # an out port connected to an output of an instance is legal VHDL-93
            before = code[max(0, m.start() - 40):m.start()]
            if re.search(r'(=>|[(,])\s*$', before) and re.match(r'\s*(\([^()]*\))?\s*[,)]', after):
                continue
            read.append(name)
            break
    return read


def fix_out_reads(txt, ports):
    am = re.search(r'\barchitecture\s+\w+\s+of\s+\w+\s+is', txt, re.I)
    if not am:
        return txt, []
    head, arch = txt[:am.end()], txt[am.end():]
    names = [n for n in out_ports_read(arch, ports) if n + '_i' not in arch]
    if not names:
        return txt, []
    for n in names:
        arch = re.sub(r"\b%s\b(?!\s*=>|')" % re.escape(n), n + '_i', arch)  # not the formals
    decl = ['', '   -- karabas: XST (VHDL-93) cannot read out ports: internal copies']
    for n in names:
        _, typ, default = ports[n]
        decl.append('   signal %s_i : %s%s;' % (n, typ, (' := ' + default) if default else ''))
    # the declarative part ends at the first "begin" of the architecture on its own line
    bm = re.search(r'^\s*begin\b', arch, re.M | re.I)
    drive = ['', '   -- karabas: the out ports from their internal copies']
    drive += ['   %s <= %s_i;' % (n, n) for n in names]
    arch = arch[:bm.start()] + '\n'.join(decl) + '\n' + arch[bm.start():bm.end()] + \
        '\n' + '\n'.join(drive) + '\n' + arch[bm.end():]
    return head + arch, names


# VHDL-2008 boolean conditions on std_logic (file name, exact text, replacement)
CONDITIONS = [
    ('cpu.vhd', "if (irqExtern) then", "if (irqExtern = '1') then -- karabas: VHDL-93 (XST)"),
    ('cpu.vhd', "if (regs.FlagDir) then", "if (regs.FlagDir = '1') then -- karabas: VHDL-93 (XST)"),
    ('memorymux.vhd', "if (isColor) then", "if (isColor = '1') then -- karabas: VHDL-93 (XST)"),
    ('swanTop.vhd', "when (isColor or regIsMapped) else x\"90\";",
     "when (isColor = '1' or regIsMapped = '1') else x\"90\"; -- karabas: VHDL-93 (XST)"),
]


def fix_conditions(path, txt):
    n = 0
    for name, old, new in CONDITIONS:
        if path.endswith('/' + name) and old in txt:
            n += txt.count(old)
            txt = txt.replace(old, new)
    return txt, n


def units(txt):
    """The file cut before each entity declaration (library / use lines go with it)."""
    starts = [m.start() for m in re.finditer(r'^(?:\s*(?:library|use)\b[^\n]*\n)*\s*entity\s+\w+\s+is\b',
                                             txt, re.M | re.I)]
    if not starts or starts[0] != 0:
        starts = [0] + starts
    return [txt[a:b] for a, b in zip(starts, starts[1:] + [len(txt)])]


def main():
    for path in sys.argv[1:]:
        txt = open(path).read()
        out, report = [], []
        for u in units(txt):
            ports = entity_ports(u)
            known = set(ports) | signals(u)
            u, n_all = fix_process_all(u, known, [n for n, p in ports.items() if p[0] == 'out'])
            u, outs = fix_out_reads(u, ports)
            u, n_cond = fix_conditions(path, u)
            out.append(u)
            if n_all or outs or n_cond:
                report.append('process(all) x%d, conditions x%d, out ports read: %s'
                              % (n_all, n_cond, ' '.join(outs) or '-'))
        txt2 = ''.join(out)
        if txt2 != txt:
            open(path, 'w').write(txt2)
            print('%s: %s' % (path, '; '.join(report)))


if __name__ == '__main__':
    main()
