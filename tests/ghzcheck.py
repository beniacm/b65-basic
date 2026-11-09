#!/usr/bin/env python3
"""examples/ghz.bas (act 1) against tests/ghzmodel.py: B65 runs N frames in
Xemu (MEGA65 ROM boot, a private card copy with the art), the memory dump's
screen (token low bytes, GOTOX fine X, ring slots) must equal the model's.
usage: tests/ghzcheck.py [frames] [--local | --pack] [--act2 frame] [--shot file.png] [-v]
  default  the generated build/B65GHZG.BBC; INTRO2.D81 with one checked byte
           of SCROLLTEST changed (or none): the program must fall back
  --local  INTRO2.D81 (D81 below) on the card: ghz.bas reads SCROLLTEST from it
  --pack   the local pack local/ghz_assets/B65GHZ.BBC (tools/mkghz.py --local)
           under the name B65GHZG.BBC, no D81: the same model as --local
The art line the program prints must match (ORIGINAL ART... with --local)."""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghzmodel
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D81 = os.path.expanduser('~/projects/mega65/ext/filehost/intros/sdcard-files/INTRO2.D81')   # read only
SC = 0x50000
LS = 372                            # bytes a row (SCROLLTEST's 208, then act 2's text tokens)

def tamper(src, dst):
    """a copy of the D81 with byte 1600 of SCROLLTEST changed (a byte the
    program's check sums)"""
    d = bytearray(open(src, 'rb').read())
    off = lambda t, s: ((t - 1) * 40 + s) * 256
    t, s = 40, 3
    while t:
        sec = d[off(t, s):off(t, s) + 256]
        for e in range(0, 256, 32):
            if sec[e + 2] & 7 == 2 and sec[e + 5:e + 21].rstrip(b'\xa0') == b'SCROLLTEST':
                ft, fs = sec[e + 3], sec[e + 4]
        t, s = sec[0], sec[1]
    for _ in range(1600 // 254):
        ft, fs = d[off(ft, fs)], d[off(ft, fs) + 1]
    d[off(ft, fs) + 2 + 1600 % 254] ^= 0x55
    open(dst, 'wb').write(d)

def unpack(p):
    b = lambda o, n: list(p[o:o + n])
    return dict(sine1=b(792, 256), sine2=b(1048, 256), b1=b(1304, 250), b2=b(1554, 147),
                b3=b(1701, 210), map=b(1911, 1885))

def main():
    frames = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 600
    local = '--local' in sys.argv
    lpack = local or '--pack' in sys.argv
    pf = os.path.join(ROOT, 'local/ghz_assets/B65GHZ.BBC') if lpack else os.path.join(ROOT, 'build/B65GHZG.BBC')
    pack = open(pf, 'rb').read()
    gen = os.path.join(ROOT, 'build/B65GHZG.BBC')
    src = open(os.path.join(ROOT, 'examples/ghz.bas')).read().replace('110 BN%=0', '110 BN%=' + str(frames))
    shot = sys.argv[sys.argv.index('--shot') + 1] if '--shot' in sys.argv else None
    if '--act2' in sys.argv:        # act 2 from this frame (the overlay file goes on the card too)
        src = src.replace('A1%=3000:SM%=1', 'A1%=' + sys.argv[sys.argv.index('--act2') + 1] + ':SM%=0')
    if shot:                        # keep the picture: no return to text, stay in a loop
        src = src.replace('T0%=TIME-T0%:PROCback:', 'T0%=TIME-T0%:REPEAT UNTIL FALSE:')
    with tempfile.TemporaryDirectory() as td:
        card = os.path.join(td, 'card.img')
        subprocess.run(['cp', '--sparse=always', os.path.expanduser('~/src/xemu-work/card.img'), card], check=True)
        env = dict(os.environ, MTOOLS_SKIP_CHECK='1')
        subprocess.run(['mcopy', '-o', '-i', card + '@@1M', gen if local else pf, '::B65GHZG.BBC'], check=True, env=env)
        if local:
            subprocess.run(['mcopy', '-o', '-i', card + '@@1M', D81, '::INTRO2.D81'], check=True, env=env)
        elif not lpack and os.path.exists(D81):
            tamper(D81, os.path.join(td, 'INTRO2.D81'))
            subprocess.run(['mcopy', '-o', '-i', card + '@@1M', os.path.join(td, 'INTRO2.D81'), '::INTRO2.D81'], check=True, env=env)
        else:
            subprocess.run(['mdel', '-i', card + '@@1M', '::INTRO2.D81'], env=env, stderr=subprocess.DEVNULL)
        if '--act2' in sys.argv:
            subprocess.run([sys.executable, os.path.join(ROOT, 'tools/mkghz.py'), '--text'], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(['mcopy', '-o', '-i', card + '@@1M', os.path.join(ROOT, 'build/B65GHZS.BBC'), '::B65GHZS.BBC'],
                           check=True, env=env)
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
            d = sum(1 for r in range(26) for i in range(0, 88, 2) if m[SC + LS * r + i] != h.row[r][i])
            print('model frame %d: %d tile/GOTOX bytes differ' % (f, d))
    bad = 0
    for row in range(26):
        a = SC + LS * row
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
    art = [l for l in out.splitlines() if 'ART' in l and ' in ' in l]
    print(art[-1] if art else 'no art line')
    if not art or ('ORIGINAL ART FROM INTRO2.D81' in art[-1]) != local:
        bad += 1
    print(tail[-1] if tail else out[-600:])
    if '-v' in sys.argv: print(out[-3000:])
    print('ghzcheck %s %d frames: %s' % ('d81' if local else 'pack' if lpack else 'generated', frames, 'OK' if not bad else '%d bytes differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
