#!/usr/bin/env python3
"""Summarise a sampling profile (build with ACMEFLAGS=-DPROF=1, run a test
with tests/run.py --memout mem.bin): 16-bit counters per 4-byte PC bucket at
$50000-$57FFF, attributed to the nearest preceding symbol of build/b65.sym.
usage: tools/prof.py mem.bin [top]"""
import os, sys, bisect
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
m = open(sys.argv[1], 'rb').read()
top = int(sys.argv[2]) if len(sys.argv) > 2 else 30
h = m[0x50000:0x58000]
syms = []
for ln in open(os.path.join(ROOT, 'build/b65.sym')):
    p = ln.split('=')
    if len(p) != 2:
        continue
    v = p[1].split(';')[0].strip()
    try:
        a = int(v.replace('$', ''), 16) if v.startswith('$') else int(v)
    except ValueError:
        continue
    if 0x2000 <= a < 0x10000 and not p[0].strip().isupper():
        syms.append((a, p[0].strip()))
syms.sort()
addrs = [a for a, _ in syms]
tot = {}
pcs = {}
n = 0
for i in range(0, len(h), 2):
    c = h[i] | h[i + 1] << 8
    if not c:
        continue
    pc = i * 2
    n += c
    k = bisect.bisect_right(addrs, pc) - 1
    name = syms[k][1] if k >= 0 else '?'
    tot[name] = tot.get(name, 0) + c
    pcs[pc] = c
print('samples', n)
for name, c in sorted(tot.items(), key=lambda x: -x[1])[:top]:
    print('%6d %5.1f%%  %s' % (c, 100.0 * c / n, name))
if '-pc' in sys.argv:
    # optional ACME report (acme -r FILE) for the source of each bucket
    src = {}
    if '-lst' in sys.argv:
        import re
        cur = ''
        for ln in open(sys.argv[sys.argv.index('-lst') + 1], errors='replace'):
            if ln.startswith('; ******** Source:'):
                cur = ln.split(':', 1)[1].strip().split('/')[-1]
            m = re.match(r'\s*(\d+)\s+([0-9a-f]{4})\s+[0-9a-f]+\s+(.*)', ln)
            if m:
                a = int(m.group(2), 16) & ~3
                src.setdefault(a, '%s:%s %s' % (cur, m.group(1), m.group(3).strip()[:60]))
    for pc, c in sorted(pcs.items(), key=lambda x: -x[1])[:top]:
        print('$%04x %6d  %s' % (pc, c, src.get(pc, '')))
