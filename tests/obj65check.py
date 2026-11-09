#!/usr/bin/env python3
"""Compare OBJ65 (the BASIC 65 library, build/obj65.prg + obj65x.prg) with
tests/objmodel.py in Xemu with the MEGA65 ROM: the scenes of
tests/objcheck.py, driven by a BASIC 65 program (BLOAD both modules from a
D81, INIT, INSTALL, N times STEP), the table and the event bits read from
Xemu's memory dump.
usage: tests/obj65check.py [seed] [objects] [frames] | --irq | --jumper"""
import os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'tools'))
import objmodel, objcheck, tok65
import importlib.util
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('mkdist', os.path.join(ROOT, 'tools/mkdist.py'))
BASE = 0x58000

def syms(f):
    d = {}
    for ln in open(os.path.join(ROOT, f)):
        p = ln.split('=')
        if len(p) == 2:
            v = p[1].split(';')[0].strip()
            if v.startswith('$'):
                d[p[0].strip()] = int(v[1:], 16)
    return d

def d81(td, files):
    src = open(os.path.join(ROOT, 'tools/mkdist.py')).read()
    src = src[:src.index('\ndef main')]          # the D81 class only
    ns = {'__file__': os.path.join(ROOT, 'tools/mkdist.py')}
    exec(compile(src, 'mkdist', 'exec'), ns)
    disk = ns['D81']('OBJ65 TEST')
    for name, data in files:
        disk.add(name, data, 2)
    path = os.path.join(td, 't.d81')
    open(path, 'wb').write(disk.finish())
    return path

def irqtest():
    """tests/obj65/irq.bas: the frame interrupt moves an object one pixel a
    frame, EVENT reports a lifetime kill once, REMOVE restores the vector"""
    import re
    prg = tok65.tokenise(open(os.path.join(ROOT, 'tests/obj65/irq.bas')).read())
    with tempfile.TemporaryDirectory() as td:
        disk = d81(td, [('OBJ65', open(os.path.join(ROOT, 'build/obj65.prg'), 'rb').read()),
                        ('OBJ65X', open(os.path.join(ROOT, 'build/obj65x.prg'), 'rb').read())])
        pp = os.path.join(td, 't.prg')
        open(pp, 'wb').write(prg)
        env = dict(os.environ, XEMU_EXTRA='-8 ' + disk)
        out = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), '-', '--prg', pp,
                              '--timeout', '40', '--screen'], capture_output=True, text=True, env=env).stdout
    m = re.search(r'MOVED\s+(\d+)\s+IN\s+(\d+)\s+FRAMES', out)
    ok = (m and abs(int(m.group(1)) - int(m.group(2))) <= 1 and 'EVENT OF 1: 1' in out
          and 'AGAIN: 0' in out and re.search(r'REMOVED, IRQ\s+(\d+)', out)
          and int(re.search(r'REMOVED, IRQ\s+(\d+)', out).group(1)) not in range(0x1600, 0x1fe8))
    if not ok:
        print(out[-1500:])
    print('obj65check irq: %s' % ('OK' if ok else 'FAIL'))
    return 0 if ok else 1

def jumpertest():
    """examples/basic65/jumper65.bas with the landing script of
    tests/smoke/31_jumper_land.txt: the same end as B65's jumper"""
    src = open(os.path.join(ROOT, 'examples/basic65/jumper65.bas')).read()
    src = src.replace('120 bn=0:rs=1:np=6:sl=0', '120 bn=30:rs=0:np=6:sl=0')
    prg = tok65.tokenise(src)
    with tempfile.TemporaryDirectory() as td:
        disk = d81(td, [('OBJ65', open(os.path.join(ROOT, 'build/obj65.prg'), 'rb').read()),
                        ('OBJ65X', open(os.path.join(ROOT, 'build/obj65x.prg'), 'rb').read())])
        pp = os.path.join(td, 't.prg')
        open(pp, 'wb').write(prg)
        env = dict(os.environ, XEMU_EXTRA='-8 ' + disk)
        out = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), '-', '--prg', pp,
                              '--timeout', '120', '--screen'], capture_output=True, text=True, env=env).stdout
    want = 'LANDED AT FRAME 12 , FELL OFF AT FRAME 21 , NOW X 377 Y 240 STANDING ON 0'
    ok = want in out
    if not ok:
        print(out[-1500:])
    print('obj65check jumper65: %s' % ('OK' if ok else 'FAIL'))
    return 0 if ok else 1

def main():
    if sys.argv[1:2] == ['--irq']:
        return irqtest()
    if sys.argv[1:2] == ['--jumper']:
        return jumpertest()
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    frames = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    rnd = __import__('random').Random(seed)
    tab, lim = objcheck.scenario(rnd, n)
    for e in tab:
        e[1] &= 3; e[3] &= 3
    c = syms('build/obj65.sym')
    L = ["10 bload \"obj65\":bload \"obj65x\",p($52000):bank 5:sys $2000:bank 128"]
    ln = 20
    for i, (x0, y0, x1, y1, a) in enumerate(lim):
        vals = []
        for v in (x0, y0, x1, y1):
            vals += [v & 255, (v >> 8) & 255]
        vals.append(a)
        L.append('%d poke $%x,%s' % (ln, c['objlim'] + 9 * i, ','.join(str(v) for v in vals))); ln += 1
    L.append('%d for i=0 to %d:read a$:for k=0 to 31:poke $%x+32*i+k,dec(mid$(a$,2*k+1,2)):next k,i' % (ln, n - 1, BASE)); ln += 1
    L.append('%d sys $1600,%d,%d,%d,%d' % (ln, BASE >> 16, (BASE >> 8) & 255, n & 255, n >> 8)); ln += 1
    L.append('%d for f=1 to %d:sys $1606:next f' % (ln, frames)); ln += 1
    L.append('%d sys $1603:poke $d6cf,0:poke $d6cf,$42' % ln); ln += 1
    for e in tab:
        L.append('%d data "%s"' % (ln, bytes(e).hex())); ln += 1
    prg = tok65.tokenise('\n'.join(L) + '\n')
    mt = [bytearray(e) for e in tab]
    ev = set()
    for _ in range(frames):
        ev |= objmodel.step(mt, lim)
    with tempfile.TemporaryDirectory() as td:
        disk = d81(td, [('OBJ65', open(os.path.join(ROOT, 'build/obj65.prg'), 'rb').read()),
                        ('OBJ65X', open(os.path.join(ROOT, 'build/obj65x.prg'), 'rb').read())])
        pp = os.path.join(td, 't.prg')
        open(pp, 'wb').write(prg)
        mem = os.path.join(td, 'mem.bin')
        env = dict(os.environ, XEMU_EXTRA='-8 ' + disk)
        r = subprocess.run([sys.executable, os.path.join(ROOT, 'tests/run.py'), '-', '--prg', pp,
                            '--timeout', '200', '--memout', mem, '--screen'],
                           capture_output=True, text=True, env=env)
        if not os.path.exists(mem):
            print(r.stdout[-2000:]); print('obj65check: no memory dump'); return 2
        m = open(mem, 'rb').read()
    bad = 0
    for i, e in enumerate(mt):
        got = m[BASE + 32 * i:BASE + 32 * i + 32]
        if bytes(e) != got:
            bad += 1
            if bad <= 5:
                print('object %d mode %02x\n  model %s\n  obj65 %s' % (i, tab[i][16], bytes(e).hex(), got.hex()))
    evb = m[c['objevb']:c['objevb'] + 128]
    gev = {i for i in range(n) if evb[i // 8] >> (i % 8) & 1}
    if gev != ev:
        bad += 1
        print('events: model %s, obj65 %s' % (sorted(ev), sorted(gev)))
    if bad and 'TIMEOUT' in r.stdout:
        print(r.stdout[-1500:])
    print('obj65check seed %d: %d objects, %d frames, %s' % (seed, n, frames, 'OK' if not bad else '%d differ' % bad))
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
