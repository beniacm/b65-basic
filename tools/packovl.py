#!/usr/bin/env python3
"""Pack build/b65.prg with LZH (tools/lzh.py).

ACME assembles src/boot.a ($2001 .. res_start), the resident interpreter
(res_start .. code_end) and the overlay images (code_end .. ovl_images_end,
see src/b65.a). This tool keeps the boot code and replaces the rest with
one blob: the shared literal code-length table, the interpreter stream and
one stream per overlay; it sets restab, ovltab and blen in the boot code and
checks that the PRG ends below $D000 (it is loaded into bank 0 below the I/O
area). BOOT copies the blob to bank 5 and unpacks it at start-up."""
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
res_start = syms['res_start']
if syms.get('XCODE', 0) > 0xf800:
    sys.exit('packovl: overlay 4 code too large (XCODE $%04x > $f800)' % syms['XCODE'])
names = ['asm', 'gfx', 'xtra', 'fat', 'xc']
blobs = [bytes(prg[mem(res_start):mem(code_end)])]
for n in names:
    img = syms['ovl_%s_img' % n]
    blobs.append(bytes(prg[mem(img):mem(img) + syms['ovl_%s_end' % n] - 0xe000]))
table, streams = lzh.pack(blobs)
L = [table[k // 2] >> (4 * (1 - k % 2)) & 15 for k in range(256)]
assert all(L.count(n) < 256 for n in range(1, 16))     # LZCNT is 8 bits
# PRG: the boot code (unpacked), then the blob: table, interpreter, overlays
out = bytearray(prg[:mem(res_start)])
blob = bytearray(table)
offs = []
for b, st in zip(blobs, streams):
    assert lzh.unpack(table, st) == b
    offs.append(len(blob))
    blob += st
def put16(a, v):
    out[mem(a)] = v & 255
    out[mem(a) + 1] = v >> 8
put16(syms['restab'], offs[0])
for i in range(len(names)):
    put16(syms['ovltab'] + 4 * i, offs[i + 1])
put16(syms['blen'], len(blob))
assert len(blob) < 0x10000
out += blob
addr = res_start + len(blob)
# up to the I/O area (the blob is copied to bank 5 before anything else runs)
limit = 0xd000
if addr > limit:
    sys.exit('packovl: PRG too large: ends at $%04x (limit $%04x)' % (addr, limit))
open(PRG, 'wb').write(out)
print('packovl: interpreter %d -> %d, overlays %d -> %d bytes, PRG ends at $%04x ($%x free)' % (
    code_end - res_start, offs[1] - offs[0],
    syms['ovl_images_end'] - code_end, len(blob) - offs[1], addr, limit - addr))
