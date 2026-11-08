#!/usr/bin/env python3
"""Pack the overlay images of build/b65.prg with LZB (tools/lzb.py).

ACME assembles the overlay images uncompressed after the resident code
(code_end .. ovl_images_end, see src/b65.a). This tool replaces them with
LZB streams (each ending in a match token with distance 0), points the
ovltab source words at the streams, and checks that the PRG ends below
$CF00 (it is loaded into bank 0 below the I/O area). OVINIT unpacks the
streams into bank 4 at start-up."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lzb
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
names = ['asm', 'gfx', 'xtra', 'fat'] + (['xc'] if 'ovl_xc_img' in syms else [])
out = bytearray(prg[:mem(code_end)])
addr = code_end
for i, n in enumerate(names):
    img = syms['ovl_%s_img' % n]
    ln = syms['ovl_%s_end' % n] - 0xe000
    data = bytes(prg[mem(img):mem(img) + ln])
    c = lzb.compress(data) + bytes([0x80, 0, 0])
    assert lzb.decompress(c, len(data)) == data
    t = mem(ovltab + 4 * i)
    out[t] = addr & 255
    out[t + 1] = addr >> 8
    out += c
    addr += len(c)
if addr > 0xcf00:
    sys.exit('packovl: PRG too large: ends at $%04x (limit $cf00)' % addr)
open(PRG, 'wb').write(out)
print('packovl: overlays %d -> %d bytes, PRG ends at $%04x ($%x free)' % (
    syms['ovl_images_end'] - code_end, addr - code_end, addr, 0xcf00 - addr))
