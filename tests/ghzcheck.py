#!/usr/bin/env python3
"""examples/ghz.bas (act 1) against tests/ghzmodel.py: B65 runs N frames in
Xemu (MEGA65 ROM boot, a private card copy with the pack), the memory dump's
screen (token low bytes, GOTOX fine X, ring slots) must equal the model's.
usage: tests/ghzcheck.py [frames] [--local] [--shot file.png] [-v]   (--local: the local SCROLLTEST
pack local/ghz_assets/B65GHZ.BBC, else the generated build/B65GHZG.BBC)"""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghzmodel
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SC = 0x50000

def unpack(p):
    b = lambda o, n: list(p[o:o + n])
    return dict(sine1=b(792, 256), sine2=b(1048, 256), b1=b(1304, 250), b2=b(1554, 147),
                b3=b(1701, 210), map=b(1911, 1885))

def main():
    frames = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 600
    local = '--local' in sys.argv
    pf = os.path.join(ROOT, 'local/ghz_assets/B65GHZ.BBC') if local else os.path.join(ROOT, 'build/B65GHZG.BBC')
    name = 'B65GHZ.BBC' if local else 'B65GHZG.BBC'
    pack = open(pf, 'rb').read()
    src = open(os.path.join(ROOT, 'examples/ghz.bas')).read().replace('110 BN%=0', '110 BN%=' + str(frames))
    shot = sys.argv[sys.argv.index('--shot') + 1] if '--shot' in sys.argv else None
    if shot:                        # keep the picture: no return to text, stay in a loop
        src = src.replace('T0%=TIME-T0%:PROCback:', 'T0%=TIME-T0%:REPEAT UNTIL FALSE:')
    with tempfile.TemporaryDirectory() as td:
        card = os.path.join(td, 'card.img')
        subprocess.run(['cp', '--sparse=always', os.path.expanduser('~/src/xemu-work/card.img'), card], check=True)
        env = dict(os.environ, MTOOLS_SKIP_CHECK='1')
        subprocess.run(['mcopy', '-o', '-i', card + '@@1M', pf, '::' + name], check=True, env=env)
        pf2 = os.path.join(td, 'B65GHZT.BBC')        # the program as a text file (a short transcript)
        open(pf2, 'w').write(src.replace('\n', '\r'))
        subprocess.run(['mcopy', '-o', '-i', card + '@@1M', pf2, '::B65GHZT.BBC'], check=True, env=env)
        sf = os.path.join(td, 's.txt')
        open(sf, 'w').write('LOAD "B65GHZT"\nRUN\n')
        mem = os.path.join(td, 'mem.bin')
        cmd = [sys.executable, os.path.join(ROOT, 'tests/run.py'), sf, '--rom', '--timeout', '60' if shot else '400',
               '--memout', mem]
        if shot:
            cmd += ['--screenshot', os.path.abspath(shot)]
        r = subprocess.run(cmd, capture_output=True, text=True, env=dict(env, CARD=card))
        out = r.stdout
        if not os.path.exists(mem):
            print(out[-1500:]); return 2
        m = open(mem, 'rb').read()
    g = ghzmodel.GHZ(unpack(pack))
    for _ in range(frames):
        g.frame()
    if '-v' in sys.argv:            # which model frame is nearest (debugging)
        h = ghzmodel.GHZ(unpack(pack))
        for f in range(frames + 6):
            if f:
                h.frame()
            d = sum(1 for r in range(26) for i in range(0, 88, 2) if m[SC + 208 * r + i] != h.row[r][i])
            print('model frame %d: %d tile/GOTOX bytes differ' % (f, d))
    bad = 0
    for row in range(26):
        a = SC + 208 * row
        got = m[a:a + 208]
        want = g.row[row]
        idx = [0, 44] + list(range(2, 44, 2)) + list(range(46, 88, 2))
        for s in range(30):
            o = 88 + 4 * s
            idx += [o + 1] if want[o + 1] == 2 else [o, o + 1, o + 2]
        for i in idx:
            if got[i] != want[i]:
                bad += 1
                if bad <= 8:
                    print('row %d byte %d: b65 %02x model %02x' % (row, i, got[i], want[i]))
    tail = [l for l in out.splitlines() if l.startswith('frames')]
    print(tail[-1] if tail else out[-600:])
    if '-v' in sys.argv: print(out[-3000:])
    print('ghzcheck %s %d frames: %s' % ('local' if local else 'generated', frames, 'OK' if not bad else '%d bytes differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
