#!/usr/bin/env python3
"""Data packs for examples/ghz.bas (docs/GHZ.md).

  tools/mkghz.py           build/B65GHZG.BBC: an ORIGINAL generated tileset,
                           band/map data, palette and sine tables (shipped)
  tools/mkghz.py --text    build/B65GHZS.BBC: act 2's overlay (font + the
                           source of examples/ghz.bas as 40-column token lines)
  tools/mkghz.py --local   local/ghz_assets/B65GHZ.BBC from the local asset
                           pack (SCROLLTEST's data: never committed or shipped)

Pack layout (23700 bytes): palette R[256] G[256] B[256] (VIC-IV nibble
format), waterfall R[8] G[8] B[8] (entries 25..28), sine1[256], sine2[256],
band 1 (5 x 50), band 2 (3 x 49), bands 3-7 (5 x 42), front map (13 x 145),
then glyphs $160..$296 (NCM, 64 bytes each)."""
import math, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(ROOT, 'local', 'ghz_assets')
NG = 0x297 - 0x160               # glyphs $160..$296

def nib(v):                       # 0..255 -> VIC-IV palette byte (nibbles swapped)
    return ((v & 15) << 4) | (v >> 4)

def local_pack():
    d = open(os.path.join(LOCAL, 'SCROLLTEST.prg'), 'rb').read()
    m = d[2:]
    a = lambda x, n: m[x - 0x2001:x - 0x2001 + n]
    pal = open(os.path.join(LOCAL, 'palette_rgb.bin'), 'rb').read()
    wf = open(os.path.join(LOCAL, 'waterfall_2D00.bin'), 'rb').read()
    out = pal + wf + a(0x2DEB, 256) + a(0x2EEB, 256) + a(0x3300, 250) + a(0x33FA, 147) + \
        a(0x348D, 210) + a(0x355F, 13 * 145) + open(os.path.join(LOCAL, 'glyphs_160_297.bin'), 'rb').read()
    return out

# ---------------- the generated (original) pack ----------------
class Glyphs:
    def __init__(self):
        self.g = bytearray(NG * 64)

    def tile(self, n, pix):
        """pix: 16 x 16 colour indices (0..15) -> glyphs n (top) and n+1 (bottom)"""
        for half in range(2):
            base = (n + half - 0x160) * 64
            for y in range(8):
                row = pix[half * 8 + y]
                for x in range(8):
                    self.g[base + y * 8 + x] = (row[2 * x] & 15) | (row[2 * x + 1] & 15) << 4

    def tall(self, n, pix):
        """pix: 24 rows x 16 -> glyphs n, n+1, n+2 (a ring frame)"""
        for third in range(3):
            base = (n + third - 0x160) * 64
            for y in range(8):
                row = pix[third * 8 + y]
                for x in range(8):
                    self.g[base + y * 8 + x] = (row[2 * x] & 15) | (row[2 * x + 1] & 15) << 4

def grid(f):
    return [[f(x, y) for x in range(16)] for y in range(16)]

def gen_pack():
    R = [0] * 256; G = [0] * 256; B = [0] * 256
    def setp(i, r, g, b):
        R[i], G[i], B[i] = r, g, b
    # bank 0 (sky, clouds, hills): 1-6 sky gradient, 7-9 cloud, 10-13 hills
    for k, (r, g, b) in enumerate([(30, 60, 200), (40, 80, 215), (55, 100, 225), (75, 125, 235),
                                  (100, 150, 240), (130, 175, 245)]):
        setp(1 + k, r, g, b)
    setp(7, 255, 255, 255); setp(8, 205, 220, 245); setp(9, 160, 185, 230)
    setp(10, 40, 120, 60); setp(11, 60, 150, 70); setp(12, 90, 175, 80); setp(13, 25, 90, 45)
    setp(14, 120, 90, 50); setp(15, 90, 60, 35)
    # bank 1 (rows 10-25: hills and water): 17-22 the sky again, 23-24 hills,
    # 25-28 the cycling falls, 29-31 water
    for k in range(6):
        setp(17 + k, R[1 + k], G[1 + k], B[1 + k])
    setp(23, 60, 150, 70); setp(24, 30, 100, 50)
    for k in range(4):
        setp(25 + k, 200, 230, 255)
    setp(29, 20, 70, 170); setp(30, 40, 110, 205); setp(31, 90, 160, 235)
    # bank 2 (front): grass, earth checker, trunk, leaves
    for i, c in enumerate([(0, 0, 0), (40, 160, 40), (80, 200, 60), (20, 110, 30), (190, 120, 50),
                           (150, 85, 35), (220, 150, 70), (110, 60, 25), (160, 110, 60), (120, 80, 40),
                           (60, 190, 90), (30, 140, 60), (240, 220, 120), (90, 50, 20), (250, 250, 250), (0, 0, 0)]):
        setp(32 + i, *c)
    # bank 3 (rings): golds
    for i, c in enumerate([(0, 0, 0), (255, 240, 120), (250, 200, 40), (210, 150, 20), (150, 100, 10),
                           (255, 255, 230)]):
        setp(48 + i, *c)
    pal = bytes(nib(v) for v in R + G + B)
    wf = bytes(nib(v) for v in [120, 160, 200, 240, 200, 160, 120, 160] +
               [180, 210, 235, 250, 235, 210, 180, 210] + [240, 250, 255, 255, 255, 250, 240, 250])
    s1 = bytes(int(80 + 78 * math.sin(2 * math.pi * i / 256)) for i in range(256))
    s2 = bytes(int(52 + 50 * math.sin(2 * math.pi * i / 128 + 0.7)) for i in range(256))
    gl = Glyphs()
    # background tiles (glyph $200 + b, b even): 0 sky ramp rows, clouds, hills, water
    def sky(level):
        return grid(lambda x, y: 1 + min(5, level + y // 6))
    bg = {}
    nb = [0]
    def bgt(pix):
        b = nb[0]; nb[0] += 2
        gl.tile(0x200 + b, pix); return b
    skyt = [bgt(sky(l)) for l in range(4)]
    def cloud(cx, cy, r, base):
        def f(x, y):
            d = ((x - cx) ** 2 + (y - cy) ** 2 * 2.2) ** 0.5
            return 7 if d < r - 3 else 8 if d < r - 1 else 9 if d < r else base[y][x]
        return grid(f)
    cl = [bgt(cloud(c, 9, r, sky(1))) for c, r in ((4, 7), (11, 8), (8, 9), (15, 6))]
    hill = [bgt(grid(lambda x, y, s=s: (7 + ((x + y + s) // 3) % 2) if y > 6 - 3 * math.sin((x + s) / 5)
                     else 1 + min(5, 3 + y // 6))) for s in range(0, 16, 4)]
    hillf = bgt(grid(lambda x, y: 7 + (x // 4 + y // 4) % 2))
    water = [bgt(grid(lambda x, y, s=s: 13 + ((x * 3 + y * 5 + s) % 3) if (x + y * 3 + s) % 11
                      else 9 + (s % 4))) for s in range(0, 8, 2)]
    falls = bgt(grid(lambda x, y: 9 + ((y + x // 4) % 4)))
    # band data: B1 (5 x 50) sky and clouds, B2 (3 x 49) hills, B3-7 (5 x 42) water
    b1 = []
    for t in range(5):
        row = []
        for c in range(29):
            v = skyt[min(3, t)]
            if t in (1, 3) and (c * 7 + t) % 9 < 3:
                v = cl[(c + t) % 4]
            row.append(v)
        b1 += row + row[:21]
    b2 = []
    for t in range(3):
        row = [hill[(c + t) % 4] if t == 0 else hillf if t == 2 else hill[(c * 3) % 4] for c in range(28)]
        b2 += row + row[:21]
    b3 = []
    for t in range(5):
        row = [falls if (c + t) % 10 == 3 else water[(c + t) % 4] for c in range(21)]
        b3 += row + row[:21]
    # front tiles (glyph $100 + b, b even from $60): $60 empty, grass top, earth checker, palm
    nf = [0x60]
    def frt(pix):
        b = nf[0]; nf[0] += 2
        gl.tile(0x100 + b, pix); return b
    empty = frt(grid(lambda x, y: 0))
    grass = frt(grid(lambda x, y: 0 if y < 3 - (x * 5 % 7) // 3 else 1 + ((x + y) % 3) if y < 9 else 4 + ((x // 8 + y // 8) % 2)))
    earth = [frt(grid(lambda x, y, p=p: 4 + p if (x < 8) == (y < 8) else 5 + p)) for p in (0, 2)]
    trunk = frt(grid(lambda x, y: 0 if abs(x - 8) > 2 else 7 + ((y // 3) % 2)))
    leaves = frt(grid(lambda x, y: 0 if (x - 8) ** 2 + (y - 10) ** 2 * 3 > 70 else 10 + ((x + y) % 2)))
    leafl = frt(grid(lambda x, y: 0 if (y - 6 - x // 3) ** 2 > 9 else 10 + (x % 2)))
    leafr = frt(grid(lambda x, y: 0 if (y - 11 + x // 3) ** 2 > 9 else 11 - (x % 2)))
    rows = [[empty] * 124 for _ in range(13)]
    for c in range(124):
        h = 9 + int(1.6 * math.sin(c / 9.0) + 0.9 * math.sin(c / 3.7))
        h = max(7, min(11, h))
        rows[h][c] = grass
        for t in range(h + 1, 13):
            rows[t][c] = earth[(c + t) % 2]
        if c % 23 == 5:
            top = h - 4
            rows[top][c - 1] = leafl; rows[top][c] = leaves; rows[top][c + 1] = leafr
            for t in range(top + 1, h):
                rows[t][c] = trunk
    mp = []
    for t in range(13):
        mp += rows[t] + rows[t][:21]
    # rings: 6 frames x 3 glyphs from $284 (24 x 16 pixels), a spinning ring
    for f in range(6):
        w = [7.5, 6.0, 3.5, 1.2, 3.5, 6.0][f]
        def ring(x, y):
            if y < 4 or y > 19:
                return 0
            dx = (x - 7.5) / max(w, 0.8); dy = (y - 11.5) / 7.5
            d = (dx * dx + dy * dy) ** 0.5
            return 0 if d > 1.0 or d < 0.62 else (1 if dy < -0.5 else 2 if d > 0.85 else 3)
        gl.tall(0x284 + 3 * f, [[ring(x, y) for x in range(16)] for y in range(24)])
    out = pal + wf + s1 + s2 + bytes(b1) + bytes(b2) + bytes(b3) + bytes(mp) + bytes(gl.g)
    return out

TEXTCH = 0x1740                     # char of ' ' in the overlay font (FCM, at $5D000)

def text_pack():
    """build/B65GHZS.BBC: act 2's overlay: lines (2 bytes), the font (96 FCM
    glyphs, ASCII 32..127, pixel colour 250), then 40 tokens a line: blank
    lines, '...BUT IN BASIC?', blank lines, examples/ghz.bas wrapped at 40
    columns, blank lines"""
    font = []
    for ln in open(os.path.join(ROOT, 'src', 'font.a')):
        if '!byte' in ln:
            font += [int(v.strip().lstrip('$'), 16) for v in ln.split('!byte')[1].split(';')[0].split(',')]
    glyphs = bytearray()
    for c in range(96):
        for y in range(8):
            row = font[c * 8 + y]
            glyphs += bytes(250 if row >> (7 - x) & 1 else 0 for x in range(8))
    lines = [''] * 13 + ['...BUT IN BASIC?'.center(40)] + [''] * 13
    for ln in open(os.path.join(ROOT, 'examples', 'ghz.bas')):
        ln = ln.rstrip('\n')
        while len(ln) > 40:
            lines.append(ln[:40]); ln = '  ' + ln[40:]
        lines.append(ln)
    lines += [''] * 30
    toks = bytearray()
    for ln in lines:
        for ch in ln.ljust(40)[:40]:
            t = TEXTCH + (ord(ch) - 32 if 32 <= ord(ch) < 128 else 0)
            toks += bytes((t & 255, t >> 8))
    return bytes((len(lines) & 255, len(lines) >> 8)) + bytes(glyphs) + bytes(toks)

def main():
    if '--text' in sys.argv:
        t = text_pack()
        out = os.path.join(ROOT, 'build', 'B65GHZS.BBC')
        open(out, 'wb').write(t)
        print('%s: %d bytes, %d lines' % (out, len(t), t[0] | t[1] << 8))
        return
    if '--local' in sys.argv:
        p = local_pack()
        out = os.path.join(LOCAL, 'B65GHZ.BBC')
    else:
        p = gen_pack()
        os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
        out = os.path.join(ROOT, 'build', 'B65GHZG.BBC')
    assert len(p) == 3796 + NG * 64, len(p)
    open(out, 'wb').write(p)
    print('%s: %d bytes' % (out, len(p)))

if __name__ == '__main__':
    main()
