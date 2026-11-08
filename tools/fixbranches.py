#!/usr/bin/env python3
"""Run ACME repeatedly; turn short branches that are out of range into
45GS02 16-bit branches (lbxx)."""
import os, re, subprocess, sys
for it in range(20):
    r = subprocess.run(['acme'] + os.environ.get('ACMEFLAGS', '').split() + ['src/b65.a'], capture_output=True, text=True)
    errs = re.findall(r'File (\S+), line (\d+) \(Zone [^)]*\): Target out of range', r.stderr)
    if not errs:
        print(r.stderr, end='')
        if r.returncode == 0:
            p = subprocess.run([sys.executable, 'tools/packovl.py'])
            if p.returncode:
                sys.exit(p.returncode)
        if os.environ.get('ACMEFLAGS') and os.path.exists('build/b65.prg'):
            os.utime('build/b65.prg', (0, 0))   # special build: make rebuilds next time
        sys.exit(r.returncode)
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
