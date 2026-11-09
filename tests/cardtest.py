#!/usr/bin/env python3
"""B65 BASIC file-writing test on a real FAT32 card image (Xemu, MEGA65 ROM).

Copies the card image (CARD env, default ~/src/xemu-work/card.img; never
written) to a private sparse copy, repairs the copy's file system first
(fsck.fat -a -w: the stock Xemu card already has findings), runs
tests/hw/0[1-4]*.txt, 07_bigprog.txt, 09_textload.txt (with dist/b65.d81
as drive 0) and 11_delete.txt in sequence on it (with --rom), compares
each transcript (up to a *CAT line) with tests/hw/NN.card.expected, and
checks the file system with fsck.fat -n: no findings at all (both FATs
the same, the FSInfo free count right, no lost clusters or orphaned long
names), and every B65* file must be readable with mtools.
usage: tests/cardtest.py [--update]
"""
import os, re, shutil, subprocess, sys, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD = os.environ.get('CARD', os.path.expanduser('~/src/xemu-work/card.img'))
TESTS = ['tests/hw/01_files.txt', 'tests/hw/02_save.txt', 'tests/hw/03_chan.txt',
         'tests/hw/04_install.txt', 'tests/hw/07_bigprog.txt', 'tests/hw/09_textload.txt',
         'tests/hw/11_delete.txt']
# extra Xemu options per test: 09 loads examples from dist/b65.d81 (drive 0)
EXTRA = {'tests/hw/09_textload.txt': '-8 ' + os.path.join(ROOT, 'dist/b65.d81')}

def fsck(img, td):
    part = os.path.join(td, 'part.img')
    off = 2048 * 512
    with open(img, 'rb') as f, open(part, 'wb') as o:
        f.seek(off)
        o.write(f.read(2 << 30))
    r = subprocess.run(['fsck.fat', '-n', part], capture_output=True, text=True)
    os.unlink(part)
    out = [l for l in (r.stdout + r.stderr).splitlines()[1:]
           if not l.startswith(part)]
    return [re.sub(r'\d+', 'N', l) for l in out]

def repair(img, td):
    """fsck.fat -a -w on the partition of the copy (written back in place)"""
    part = os.path.join(td, 'part.img')
    off = 2048 * 512
    with open(img, 'rb') as f, open(part, 'wb') as o:
        f.seek(off)
        o.write(f.read(2 << 30))
    subprocess.run(['fsck.fat', '-a', '-w', part], capture_output=True)
    with open(part, 'rb') as p, open(img, 'r+b') as f:   # changed 64 KB blocks only
        pos = 0
        while True:
            new = p.read(65536)
            if not new:
                break
            f.seek(off + pos)
            if f.read(len(new)) != new:
                f.seek(off + pos)
                f.write(new)
            pos += len(new)
    os.unlink(part)

def main():
    update = '--update' in sys.argv
    fail = 0
    subprocess.run(['make', '-s', 'all', 'dist'], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory() as td:
        img = os.path.join(td, 'card.img')
        subprocess.run(['cp', '--sparse=always', CARD, img], check=True)
        repair(img, td)
        before = fsck(img, td)
        if before:
            print('FAIL fsck: the repaired copy still has findings:', *before, sep='\n  '); fail = 1
        env = dict(os.environ, CARD=img)
        for t in TESTS:
            e = dict(env, XEMU_EXTRA=EXTRA.get(t, ''))
            r = subprocess.run([sys.executable, 'tests/run.py', t, '--rom', '--timeout', '300'],
                               cwd=ROOT, env=e, capture_output=True, text=True)
            out = []
            for l in r.stdout.splitlines():
                out.append(l)
                if l.startswith('>*CAT'):
                    break
            out = '\n'.join(out) + '\n'
            exp = os.path.join(ROOT, t.replace('.txt', '.card.expected'))
            if update:
                open(exp, 'w').write(out); print('updated', exp); continue
            if os.path.exists(exp) and open(exp).read() == out:
                print('PASS', t)
            else:
                print('FAIL', t); fail = 1
                sys.stdout.writelines(__import__('difflib').unified_diff(
                    open(exp).read().splitlines(True) if os.path.exists(exp) else [],
                    out.splitlines(True), 'expected', 'got'))
        after = fsck(img, td)
        if after == before == []:
            print('PASS fsck (clean card stays clean)')
        else:
            print('FAIL fsck'); fail = 1
            print('before:', *before, sep='\n  '); print('after:', *after, sep='\n  ')
        env2 = dict(os.environ, MTOOLS_SKIP_CHECK='1')
        ls = subprocess.run(['mdir', '-b', '-i', img + '@@1M', '::'], env=env2,
                            capture_output=True, text=True).stdout.split()
        for n in ls:
            b = n.lstrip(':/')
            if b.upper().startswith('B65') and b.upper().endswith('.BBC'):
                r = subprocess.run(['mcopy', '-n', '-i', img + '@@1M', '::' + b, os.path.join(td, 'x')],
                                   env=env2, capture_output=True)
                print(('PASS' if r.returncode == 0 else 'FAIL'), 'mcopy', b,
                      os.path.getsize(os.path.join(td, 'x')) if r.returncode == 0 else '')
                fail |= r.returncode != 0
    sys.exit(fail)

main()
