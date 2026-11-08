#!/usr/bin/env python3
"""Pack the overlay images of build/b65.prg with LZH (tools/lzh.py).

ACME assembles the overlay images uncompressed after the resident code
(code_end .. ovl_images_end, see src/b65.a). This tool replaces them with
the shared literal code-length table and one LZH stream per overlay, points
lzhtabp and the ovltab source words at them, and checks that the PRG ends
below $CF00 (it is loaded into bank 0 below the I/O area). OVINIT unpacks
the streams into bank 4 at start-up."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lzh
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRG = os.path.join(ROOT, 'build/b65.prg')
syms = {}
for ln in open(os.path.join(ROOT, 'build/b65.sym')):
    p = ln.split('=')
    if len(p) == 2:
        v = p[1].split(';')[0].strip()
        if v.startswith('$'):
            syms[p[0].strip()] = int(v[1:], 16)
prg = bytearray(open(PRG, 'rb').read())
load = prg[0] | prg[1] << 8
mem = lambda a: a - load + 2
code_end = syms['code_end']
ovltab = syms['ovltab']
names = ['asm', 'gfx', 'xtra', 'fat', 'xc']
blobs = []
for n in names:
    img = syms['ovl_%s_img' % n]
    blobs.append(bytes(prg[mem(img):mem(img) + syms['ovl_%s_end' % n] - 0xe000]))
table, streams = lzh.pack(blobs)
L = [table[k // 2] >> (4 * (1 - k % 2)) & 15 for k in range(256)]
assert all(L.count(n) < 256 for n in range(1, 16))     # LZCNT is 8 bits
out = bytearray(prg[:mem(code_end)])
t = mem(syms['lzhtabp'])
out[t] = code_end & 255
out[t + 1] = code_end >> 8
out += table
addr = code_end + len(table)
for i, (b, s) in enumerate(zip(blobs, streams)):
    assert lzh.unpack(table, s) == b
    t = mem(ovltab + 4 * i)
    out[t] = addr & 255
    out[t + 1] = addr >> 8
    out += s
    addr += len(s)
if addr > 0xcf00:
    sys.exit('packovl: PRG too large: ends at $%04x (limit $cf00)' % addr)
open(PRG, 'wb').write(out)
print('packovl: overlays %d -> %d bytes, PRG ends at $%04x ($%x free)' % (
    syms['ovl_images_end'] - code_end, addr - code_end, addr, 0xcf00 - addr))
