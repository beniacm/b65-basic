#!/usr/bin/env python3
"""Compare OBJ65X's HITPIX (BASIC 65, Xemu with the MEGA65 ROM) with
tests/hitmodel.py on the scenes of tests/hitcheck.py: every ordered pair,
plain and moved by (DX, DY); the results are poked to $5F000 by the BASIC
65 driver and read from Xemu's memory dump.
usage: tests/hit65check.py [seed] [objects]"""
import os, subprocess, sys, tempfile, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'tools'))
import hitcheck, hitmodel, tok65, obj65check
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = 0x5f000

def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    rnd = random.Random(seed)
    d054 = 0 if seed % 3 == 0 else hitcheck.D054
    mem = hitcheck.scene(rnd, n, d054)
    c = obj65check.syms('build/obj65x.sym')
    L = ['10 bload "obj65":bload "obj65x",p($52000):bank 5:sys $2000:bank 128']
    L.append('20 poke $d054,(peek($d054) and $f9) or %d:poke $d068,%d,%d,%d' % (
        d054, hitcheck.CSET & 255, (hitcheck.CSET >> 8) & 255, hitcheck.CSET >> 16))
    L.append('30 read a,a$:if a<0 then 50')
    L.append('40 for k=0 to len(a$)/2-1:poke a+k,dec(mid$(a$,2*k+1,2)):next k:goto 30')
    L.append('50 sys $1600,%d,%d,%d,0' % (hitcheck.BASE >> 16, (hitcheck.BASE >> 8) & 255, n))
    pa = 0x50000 + c['hpa']
    L.append('60 for i=0 to %d:for j=0 to %d:for m=0 to 1' % (n - 1, n - 1))
    L.append('70 wpoke $%x,i,j,m*%d,m*%d' % (pa, hitcheck.DX & 0xffff, hitcheck.DY & 0xffff))
    L.append('80 bank 5:sys $2006:bank 128:rreg a:poke $%x+2*(i*%d+j)+m,a:next m,j,i' % (RES, n))
    L.append('90 sys $1603:poke $d6cf,0:poke $d6cf,$42')
    ln = 100
    keys = sorted(mem)
    runs = []
    for a in keys:
        if runs and runs[-1][0] + len(runs[-1][1]) == a and len(runs[-1][1]) < 60:
            runs[-1][1].append(mem[a])
        else:
            runs.append([a, [mem[a]]])
    for a, bs in runs:
        L.append('%d data %d,"%s"' % (ln, a, ''.join('%02x' % v for v in bs))); ln += 1
    L.append('%d data -1,""' % ln)
    prg = tok65.tokenise('\n'.join(L) + '\n')
    with tempfile.TemporaryDirectory() as td:
        disk = obj65check.d81(td, [('OBJ65', open(os.path.join(ROOT, 'build/obj65.prg'), 'rb').read()),
                                   ('OBJ65X', open(os.path.join(ROOT, 'build/obj65x.prg'), 'rb').read())])
        pp = os.path.join(td, 't.prg')
        open(pp, 'wb').write(prg)
        mfile = os.path.join(td, 'mem.bin')
        env = dict(os.environ, XEMU_EXTRA='-8 ' + disk)
        r = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), '-', '--prg', pp,
                            '--timeout', '300', '--memout', mfile, '--screen'],
                           capture_output=True, text=True, env=env)
        if not os.path.exists(mfile):
            print(r.stdout[-2000:]); return 2
        m = open(mfile, 'rb').read()
    rd = lambda a: mem.get(a, 0)
    bad = hits = 0
    for i in range(n):
        for j in range(n):
            for k, (dx, dy) in enumerate(((0, 0), (hitcheck.DX, hitcheck.DY))):
                want = 1 if hitmodel.hitpix(rd, hitcheck.BASE, i, j, d054, hitcheck.CSET, dx, dy) else 0
                got = m[RES + 2 * (i * n + j) + k]
                hits += want
                if got != want:
                    bad += 1
                    if bad <= 5:
                        print('pair %d,%d moved %d: model %d obj65 %d' % (i, j, k, want, got))
    if bad and 'TIMEOUT' in r.stdout:
        print(r.stdout[-1200:])
    print('hit65check seed %d ($D054 %d): %d objects, %d pairs x 2, %d hits, %s' % (
        seed, d054, n, n * n, hits, 'OK' if not bad else '%d differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
