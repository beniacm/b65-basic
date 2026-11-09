#!/usr/bin/env python3
"""Compare B65's object integrator (OBJUPDATE in Xemu) with tests/objmodel.py.

usage: tests/objcheck.py [seed] [objects] [frames]
Builds random tables (all modes, limits with none/wrap/bounce/kill, half
restitution, lifetimes, orbit parents and spring anchors), runs them through
B65 and the model and compares every byte of every entry and the event bits.
Exit status 0 when equal."""
import os, random, re, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import objmodel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = 0x58000                          # objbase without the K325T (Xemu)

def scenario(rnd, n):
    lim = []
    for _ in range(4):
        x0 = rnd.randint(-20, 100); x1 = rnd.randint(400, 700)
        y0 = rnd.randint(-100, 50); y1 = rnd.randint(250, 450)
        lim.append([x0, y0, x1, y1, rnd.randint(0, 15) | rnd.choice((0, 0x20))])
    tab = []
    for i in range(n):
        e = bytearray(32)
        x, y = rnd.randint(0, 639), rnd.randint(-100, 450)
        e[0], e[1] = x & 255, (x >> 8) & 3
        e[2], e[3] = y & 255, (y >> 8) & 3
        e[4] = 255
        e[7] = 1
        mode = rnd.choice((0, 1, 1, 1, 2, 2, 3, 0x11))
        if mode == 3 or mode == 0x11:
            if i == 0:
                mode = 1
            else:
                objmodel.w16(e, 28, rnd.randint(0, i - 1))
        e[16] = mode | rnd.randint(0, 3) << 5
        e[17] = rnd.choice((0, 0, rnd.randint(0, 15))) | rnd.choice((0, 0x10)) | rnd.choice((0, 0x20))
        for o in (18, 20, 22, 24):
            objmodel.w16(e, o, rnd.randint(-1500, 1500))
        if mode == 1:
            objmodel.w16(e, 22, rnd.choice((0, rnd.randint(-40, 40))))
            objmodel.w16(e, 24, rnd.choice((0, rnd.randint(-40, 40))))
        if mode == 0x11:
            objmodel.w16(e, 22, rnd.randint(0, 40))           # k (8.8)
        if mode == 2:
            objmodel.w16(e, 18, rnd.randint(0, 1200))
            objmodel.w16(e, 22, rnd.randint(-20, 20))
            objmodel.w16(e, 24, rnd.randint(-900, 900))
        if mode == 3:
            objmodel.w16(e, 18, rnd.randint(0, 20000))
            objmodel.w16(e, 24, rnd.randint(-2000, 2000))
        objmodel.w16(e, 26, rnd.choice((0, 0, rnd.randint(1, 80))))
        e[30], e[31] = rnd.randint(0, 255), rnd.randint(0, 255)
        tab.append(e)
    return tab, lim

def basic(tab, lim, frames, evaddr):
    L = []
    ln = 10
    def add(s):
        nonlocal ln
        L.append('%d %s' % (ln, s)); ln += 10
    add('OBJUPDATE:REM (no objects yet: only stops the frame interrupt)')
    add('OBJECT %d,0,0,0' % (len(tab) - 1))
    for i, (x0, y0, x1, y1, a) in enumerate(lim):
        add('OBJLIMITS %d,%d,%d,%d,%d,%d' % (i, x0, y0, x1, y1, a))
    for i, e in enumerate(tab):
        b = BASE + 32 * i
        words = ['!&%X=&%X' % (b + k, int.from_bytes(e[k:k + 4], 'little')) for k in range(0, 32, 4)]
        add(':'.join(words))
    add('FOR F%%=1 TO %d:OBJUPDATE:NEXT' % frames)
    add('FOR I%%=0 TO %d:S$="":FOR K%%=0 TO 31:S$=S$+RIGHT$("0"+STR$~?(&%X+32*I%%+K%%),2):NEXT:PRINT "E";I%%;" ";S$:NEXT' % (len(tab) - 1, BASE))
    add('S$="":FOR K%%=0 TO %d:S$=S$+RIGHT$("0"+STR$~?(&%X+K%%),2):NEXT:PRINT "V ";S$' % ((len(tab) + 7) // 8 - 1, evaddr))
    return '\n'.join(L) + '\nRUN\n'

def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    frames = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    rnd = random.Random(seed)
    tab, lim = scenario(rnd, n)
    evaddr = None
    for ln in open(os.path.join(ROOT, 'build/b65.sym')):
        p = ln.split('=')
        if len(p) == 2 and p[0].strip() == 'objevb':
            evaddr = int(p[1].split(';')[0].strip().lstrip('$'), 16)
    script = basic(tab, lim, frames, evaddr)
    for e in tab:
        e[1] &= 3; e[3] &= 3
    mt = [bytearray(e) for e in tab]
    # OBJECT n,0,0,0 (the last one) wrote its entry first; the pokes overwrite it
    ev = set()
    for _ in range(frames):
        ev |= objmodel.step(mt, lim)
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as f:
        f.write(script)
        fn = f.name
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), fn, '--timeout', '120'],
                         capture_output=True, text=True).stdout
    os.unlink(fn)
    got = {}
    for m in re.finditer(r'^E\s*(\d+) ([0-9A-F]{64})', out, re.M):
        got[int(m.group(1))] = bytes.fromhex(m.group(2))
    m = re.search(r'^V ([0-9A-F]+)', out, re.M)
    bad = 0
    if len(got) != n or not m:
        print(out[-2000:])
        print('objcheck: no complete dump')
        return 2
    for i, e in enumerate(mt):
        if bytes(e) != got[i]:
            bad += 1
            if bad <= 5:
                print('object %d mode %02x\n  model %s\n  b65   %s' % (i, tab[i][16], bytes(e).hex(), got[i].hex()))
    evb = bytes.fromhex(m.group(1))
    gev = {i for i in range(n) if evb[i // 8] >> (i % 8) & 1}
    if gev != ev:
        bad += 1
        print('events: model %s, b65 %s' % (sorted(ev), sorted(gev)))
    print('objcheck seed %d: %d objects, %d frames, %s' % (seed, n, frames, 'OK' if not bad else '%d differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
