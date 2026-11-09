#!/usr/bin/env python3
"""Run ACME repeatedly; turn short branches that are out of range into
45GS02 16-bit branches (lbxx). Builds B65 (src/b65.a, five runs, then
tools/packovl.py) and the BASIC 65 library OBJ65 (src/obj65.a; its
integrator src/objfar.a is generated from src/obj.a first)."""
import os, re, subprocess, sys
FLAGS = os.environ.get('ACMEFLAGS', '').split()
os.makedirs('build', exist_ok=True)       # (a fresh checkout has none)

def fixloop(srcfile):
    """assemble until no branch is out of range; returns ACME's result"""
    for it in range(20):
        r = subprocess.run(['acme'] + FLAGS + [srcfile], capture_output=True, text=True)
        errs = re.findall(r'File (\S+), line (\d+) \(Zone [^)]*\): Target out of range', r.stderr)
        if not errs:
            return r
        files = {}
        for f, l in errs:
            files.setdefault(f, set()).add(int(l))
        for f, ls in files.items():
            lines = open(f).read().split('\n')
            for l in ls:
                s = lines[l - 1]
                n = re.sub(r'\b(bra|beq|bne|bcc|bcs|bpl|bmi)\b', lambda m: 'l' + m.group(1), s, count=1)
                if n == s:
                    print('cannot fix', f, l, s); sys.exit(1)
                lines[l - 1] = n
            open(f, 'w').write('\n'.join(lines))
    print('too many iterations'); sys.exit(1)

# src/objfar.a: generated from src/obj.a (OBJ65 and the OBJFAR measurement build)
subprocess.run([sys.executable, 'tools/mkobjfar.py'], check=True, stdout=subprocess.DEVNULL)
if not FLAGS:                       # OBJ65 first: its long branches suit both
    o = fixloop('src/obj65.a')
    print(o.stderr, end='')
    if o.returncode:
        sys.exit(o.returncode)
    with open('build/obj65.inc', 'w') as inc:   # the core's addresses for OBJ65X
        for ln in open('build/obj65.sym'):
            p = ln.split('=')
            if len(p) == 2 and p[0].strip().isidentifier():
                inc.write('c_%s = %s\n' % (p[0].strip(), p[1].split(';')[0].strip()))
    subprocess.run([sys.executable, 'tools/mkhit65.py'], check=True, stdout=subprocess.DEVNULL)
    o = fixloop('src/obj65x.a')
    print(o.stderr, end='')
    if o.returncode:
        sys.exit(o.returncode)
r = fixloop('src/b65.a')
print(r.stderr, end='')
if r.returncode == 0:
    for k in range(1, 5):           # the other overlay images (src/b65.a)
        q = subprocess.run(['acme'] + FLAGS + ['-DOVL=%d' % k, 'src/b65.a'], capture_output=True, text=True)
        if q.returncode:
            print(q.stderr, end=''); sys.exit(q.returncode)
    p = subprocess.run([sys.executable, 'tools/packovl.py'])
    if p.returncode:
        sys.exit(p.returncode)
if FLAGS and os.path.exists('build/b65.prg'):
    os.utime('build/b65.prg', (0, 0))   # special build: make rebuilds next time
sys.exit(r.returncode)
