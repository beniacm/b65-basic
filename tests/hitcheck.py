#!/usr/bin/env python3
"""Compare B65's HITPIX(a,b) (in Xemu) with tests/hitmodel.py.

usage: tests/hitcheck.py [seed] [objects]
Random scenes of overlapping objects: full colour and mono glyphs (random
sparse pixels), FLIPX/FLIPY per object and per glyph, heights 1..3, box
widths, GOTOX tokens, token bits 15..13, draw mask 0; every ordered pair
(a self pair included). Exit status 0 when equal."""
import os, random, re, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hitmodel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = 0x58000                          # objbase without the K325T (Xemu)
GLY = 0x54000                           # full colour glyphs: chars $1500..
CSET = 0x55000                          # CHARPTR: mono glyphs 0..
TOK = 0x56000                           # token lists: object i at TOK + 64 i
COL = 0x7000                            # colour offsets: COL + 64 i
DX, DY = 3, -2                          # the moved pairs: HITPIX(a,b,DX,DY)
D054 = 4                                # chars > 255 full colour (seeds 3, 6, ..: 0, all mono)

def scene(rnd, n, d054):
    mem = {}
    def put(a, bs):
        for k, v in enumerate(bs):
            mem[a + k] = v
    for g in range(8):
        put(GLY + 64 * g, [rnd.choice((0, 0, rnd.randint(1, 255))) for _ in range(64)])
        put(CSET + 8 * g, [rnd.randint(0, 255) & rnd.randint(0, 255) for _ in range(8)])
        if not d054 & 4:                # chars $1500.. as mono glyphs
            put(CSET + 8 * (0x1500 + g), [rnd.randint(0, 255) & rnd.randint(0, 255) for _ in range(8)])
    for i in range(n):
        h = rnd.randint(1, 3)
        stride = 16
        for r in range(h):
            toks, cols = [], []
            for _ in range(rnd.randint(0, 6)):
                if rnd.random() < 0.15:
                    toks.append(rnd.randint(0, 0x3ff)); cols.append(0x10 | rnd.choice((0, 0x80)))
                    continue
                g = rnd.randint(0, 7)
                toks.append((0x1500 + g if rnd.random() < 0.6 else g) | rnd.choice((0, 0, 0xe000)))
                cols.append(rnd.choice((0, 0x40, 0x80, 0xc0)))
            toks.append(0xffff); cols.append(0)
            a = TOK + 64 * i + stride * r
            c = COL + 64 * i + stride * r
            for k, (t, cb) in enumerate(zip(toks, cols)):
                put(a + 2 * k, (t & 255, t >> 8))
                put(0xff80000 + c + 2 * k, (cb, rnd.randint(0, 15)))
        x = rnd.randint(90, 160)
        y = rnd.randint(-20, 30) & 0x3ff
        e = bytearray(16)
        e[0], e[1] = x & 255, x >> 8
        e[2], e[3] = y & 255, y >> 8
        e[4] = 0 if rnd.random() < 0.08 else rnd.choice((255, 255, 0x0f))
        e[5] = rnd.choice((h, h, 0)) if h == 1 else h
        e[6] = (TOK >> 16) | rnd.choice((0, 0x10, 0x20, 0x30)) | rnd.choice((0, 0x40))
        e[7] = 1
        t = TOK + 64 * i
        e[8], e[9] = t & 255, (t >> 8) & 255
        c = COL + 64 * i
        e[10], e[11] = c & 255, c >> 8
        e[12], e[13] = stride, 0
        e[14] = rnd.choice((0, 8, 12, 16, 20, 24, 3, 40, 56))
        put(BASE + 32 * i, e)
        put(BASE + 32 * i + 16, bytes(16))
    return mem

def basic(mem, n, d054):
    L = []
    ln = [10]
    def add(s):
        L.append('%d %s' % (ln[0], s)); ln[0] += 10
    add('OBJUPDATE:OBJECT %d,0,0,0' % (n - 1))
    add('?&D054=(?&D054 AND &F9) OR %d:?&D068=%d:?&D069=%d:?&D06A=%d' % (d054, CSET & 255, (CSET >> 8) & 255, CSET >> 16))
    # runs of consecutive addresses as hex strings
    keys = sorted(mem)
    runs = []
    for a in keys:
        if runs and runs[-1][0] + len(runs[-1][1]) == a and len(runs[-1][1]) < 100:
            runs[-1][1].append(mem[a])
        else:
            runs.append([a, [mem[a]]])
    for a, bs in runs:
        add('A%%=&%X:D$="%s":PROCp' % (a, ''.join('%02X' % v for v in bs)))
    add('FOR I%%=0 TO %d:S$="":FOR J%%=0 TO %d:S$=S$+CHR$(48-HITPIX(I%%,J%%)):NEXT:PRINT "H";I%%;" ";S$:NEXT' % (n - 1, n - 1))
    add('FOR I%%=0 TO %d:S$="":FOR J%%=0 TO %d:S$=S$+CHR$(48-HITPIX(I%%,J%%,%d,%d)):NEXT:PRINT "M";I%%;" ";S$:NEXT' % (n - 1, n - 1, DX, DY))
    add('END')
    add('DEF PROCp:LOCAL I%:FOR I%=0 TO LEN(D$)/2-1:?(A%+I%)=EVAL("&"+MID$(D$,2*I%+1,2)):NEXT:ENDPROC')
    return '\n'.join(L) + '\nRUN\n'

def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    rnd = random.Random(seed)
    d054 = 0 if seed % 3 == 0 else D054
    mem = scene(rnd, n, d054)
    script = basic(mem, n, d054)
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as f:
        f.write(script)
        fn = f.name
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), fn, '--timeout', '200'],
                         capture_output=True, text=True).stdout
    os.unlink(fn)
    got = {int(m.group(1)): m.group(2) for m in re.finditer(r'^H\s*(\d+) ([01]+)', out, re.M)}
    gotm = {int(m.group(1)): m.group(2) for m in re.finditer(r'^M\s*(\d+) ([01]+)', out, re.M)}
    if len(got) != n or len(gotm) != n:
        print(out[-2000:]); print('hitcheck: no complete result'); return 2
    rd = lambda a: mem.get(a, 0)
    bad = hits = boxes = 0
    for i in range(n):
        A = hitmodel.record(rd, BASE, i)
        for j in range(n):
            B = hitmodel.record(rd, BASE, j)
            boxes += (A['mask'] and B['mask'] and max(A['x'], B['x']) < min(A['x'] + A['w'], B['x'] + B['w'])
                      and max(A['y'], B['y']) < min(A['y'] + A['ph'], B['y'] + B['ph'])) and 1 or 0
        want = ''.join('1' if hitmodel.hitpix(rd, BASE, i, j, d054, CSET) else '0' for j in range(n))
        hits += want.count('1')
        if want != got[i]:
            bad += 1
            print('object %d: model %s b65 %s' % (i, want, got[i]))
        wm = ''.join('1' if hitmodel.hitpix(rd, BASE, i, j, d054, CSET, DX, DY) else '0' for j in range(n))
        hits += wm.count('1')
        if wm != gotm[i]:
            bad += 1
            print('object %d moved: model %s b65 %s' % (i, wm, gotm[i]))
    print('hitcheck seed %d ($D054 %d): %d objects, %d pairs (and moved), %d boxes overlap, %d hits, %s' % (seed, d054, n, n * n, boxes, hits, 'OK' if not bad else '%d rows differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
