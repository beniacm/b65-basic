#!/usr/bin/env python3
"""Run B65 BASIC in Xemu headless with a scripted keyboard input.

usage: tests/run.py script.txt [--screenshot out.png] [--timeout secs]

The script is fed to the interpreter as keyboard input (one line per
input line). When the script is exhausted the interpreter asks Xemu to
exit (-testing mode, $D6CF). Prints the transcript of all output.
"""
import argparse, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XEMU = os.environ.get('XEMU', os.path.expanduser('~/src/xemu/build/bin/xmega65.native'))

def build_image(script_bytes):
    prg = open(os.path.join(ROOT, 'build/b65.prg'), 'rb').read()
    boot = open(os.path.join(ROOT, 'build/boot.bin'), 'rb').read()
    assert prg[:2] == b'\x01\x20'
    body = prg[2:]
    assert len(boot) <= 0x100 and len(body) <= 0x7000
    img = bytearray(0x8000)
    img[:len(boot)] = boot
    img[0x100:0x100 + len(body)] = body
    scr = b'B65T' + script_bytes + b'\0'
    assert len(scr) <= 0x7000
    return bytes(img) + scr

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('--screenshot')
    ap.add_argument('--timeout', type=float, default=60)
    ap.add_argument('--screen', action='store_true', help='also print final screen')
    a = ap.parse_args()
    script = open(a.script, 'rb').read()
    with tempfile.TemporaryDirectory() as td:
        img = os.path.join(td, 'boot.img')
        open(img, 'wb').write(build_image(script))
        sd = os.path.join(td, 'sd')
        os.mkdir(sd)
        mem = os.path.join(td, 'mem.bin')
        scr = os.path.join(td, 'screen.txt')
        cmd = [XEMU, '-skipconfigfile', '-headless', '-sleepless', '-besure', '-testing',
               '-virtsd', '-sdimg', sd, '-extonboard', img, '-dumpmem', mem,
               '-dumpscreen', scr]
        if a.screenshot:
            cmd += ['-screenshot', os.path.abspath(a.screenshot)]
        env = dict(os.environ, XEMU_SKIP_ONBOARDING='')
        env.pop('XEMU_SKIP_ONBOARDING')
        try:
            r = subprocess.run(['timeout', '-s', 'INT', str(a.timeout)] + cmd,
                               capture_output=True, env=env, cwd=td)
            rc = r.returncode
        except Exception as e:
            print('xemu failed:', e); return 2
        if not os.path.exists(mem):
            print('no memory dump; xemu rc', rc)
            print(r.stdout.decode(errors='replace')[-3000:])
            return 2
        m = open(mem, 'rb').read()
        t = m[0x18000:0x20000]
        t = t[:t.index(0)] if 0 in t else t
        out = t.decode('latin-1').replace('\r\n', '\n').replace('\r', '')
        sys.stdout.write(out)
        if a.screen and os.path.exists(scr):
            print('\n----- screen -----')
            print(open(scr, encoding='latin-1').read())
        if rc == 124 or rc == 130:
            print('\n*** TIMEOUT (xemu rc %d)' % rc)
            return 3
    return 0

if __name__ == '__main__':
    sys.exit(main())
