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
    assert len(boot) <= 0x100 and len(body) <= 0xb000
    img = bytearray(0xc000)
    img[:len(boot)] = boot
    img[0x100:0x100 + len(body)] = body
    scr = b'B65TEST:' + script_bytes + b'\0'
    assert len(scr) <= 0x3f00
    return bytes(img) + scr

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('--screenshot')
    ap.add_argument('--timeout', type=float, default=15)
    ap.add_argument('--screen', action='store_true', help='also print final screen')
    ap.add_argument('--rom', action='store_true',
                    help='boot the real MEGA65 ROM from an onboarded card image (CARD env, default ~/src/xemu-work/card.img) and RUN the PRG from BASIC 65')
    ap.add_argument('--realtime', action='store_true', help='run at real MEGA65 speed (no -sleepless)')
    ap.add_argument('--card', help='use this SD card image (written to!) instead of the virtual SD directory')
    ap.add_argument('--peek', help='comma list of symbols/addresses to dump (from build/b65.sym)')
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
        if a.card:
            i = cmd.index('-virtsd'); cmd[i:i+3] = ['-sdimg', os.path.abspath(a.card)]
        if a.rom:
            card = os.environ.get('CARD', os.path.expanduser('~/src/xemu-work/card.img'))
            sb = os.path.join(td, 'script.bin')
            open(sb, 'wb').write(b'B65TEST:' + script + b'\0')
            cmd = [XEMU, '-skipconfigfile', '-headless', '-sleepless', '-besure', '-testing',
                   '-sdimg', card, '-prg', os.path.join(ROOT, 'build/b65.prg'),
                   '-prgtest', sb + '@$10000', '-dumpmem', mem, '-dumpscreen', scr]
        if a.realtime:
            cmd.remove('-sleepless')
        cmd += os.environ.get('XEMU_EXTRA', '').split()
        if a.screenshot:
            cmd += ['-screenshot', os.path.abspath(a.screenshot)]
        env = dict(os.environ)
        env.pop('XEMU_SKIP_ONBOARDING', None)
        # private preferences dir: parallel Xemu instances must not share
        # ~/.local/share/xemu-lgb (SDL pref path follows HOME/XDG_DATA_HOME)
        env['HOME'] = td
        env['XDG_DATA_HOME'] = os.path.join(td, 'xdg')
        sock = os.path.join(td, 'uart.sock')
        cmd += ['-uartmon', sock]
        import socket, time, signal
        logf = open(os.path.join(td, 'xemu.log'), 'wb')   # never a pipe: Xemu can log a lot
        p = subprocess.Popen(cmd, stdout=logf, stderr=subprocess.STDOUT, env=env, cwd=td)
        t0 = time.time(); rc = None
        pre = os.environ.get('UARTMON_PRE')
        if pre:
            for _ in range(200):
                if os.path.exists(sock):
                    break
                time.sleep(0.01)
            try:
                sp = socket.socket(socket.AF_UNIX); sp.connect(sock)
                for c in pre.split(';'):
                    sp.send(c.encode() + b'\n'); time.sleep(0.05)
                keep_sock = sp          # keep open (Xemu writes replies)
            except Exception as e:
                print('[uartmon pre failed]', e)
        while time.time() - t0 < a.timeout:
            if p.poll() is not None:
                rc = p.returncode; break
            time.sleep(0.05)
        if rc is None:
            try:
                s = socket.socket(socket.AF_UNIX); s.connect(sock); s.settimeout(1)
                s.send(b'r\n'); time.sleep(0.3)
                print('[uartmon] ' + s.recv(4096).decode(errors='replace').strip())
                s.close()
            except Exception as e:
                print('[uartmon failed]', e)
            p.send_signal(signal.SIGINT)
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                print('[xemu did not exit on SIGINT: killed]')
                p.kill(); p.wait()
            rc = 124
        class R: pass
        logf.close()
        if os.environ.get('XEMULOG'):
            import shutil; shutil.copy(os.path.join(td, 'xemu.log'), os.environ['XEMULOG'])
        r = R(); r.stdout = open(os.path.join(td, 'xemu.log'), 'rb').read()
        if not os.path.exists(mem):
            print('no memory dump; xemu rc', rc)
            print(r.stdout.decode(errors='replace')[-3000:])
            return 2
        m = open(mem, 'rb').read()
        t = m[0x48000:0x4f000]
        t = t[:t.index(0)] if 0 in t else t
        out = t.decode('latin-1').replace('\r\n', '\n').replace('\r', '')
        sys.stdout.write(out)
        if a.peek:
            syms = {}
            for ln in open(os.path.join(ROOT, 'build/b65.sym')):
                p = ln.split('=')
                if len(p) == 2:
                    v = p[1].split(';')[0].strip()
                    try: syms[p[0].strip()] = int(v.replace('$', '0x'), 16 if v.startswith('$') else 10)
                    except ValueError: pass
            for name in a.peek.split(','):
                n, _, ln = name.partition(':')
                ad = syms.get(n, None)
                if ad is None: ad = int(n, 16)
                ln = int(ln or 2)
                print('%-10s $%04x: %s' % (n, ad, ' '.join('%02x' % b for b in m[ad:ad + ln])))
        if a.screen and os.path.exists(scr):
            print('\n----- screen -----')
            print(open(scr, encoding='latin-1').read())
        if rc == 124 or rc == 130:
            print('\n*** TIMEOUT (xemu rc %d)' % rc)
            return 3
    return 0

if __name__ == '__main__':
    sys.exit(main())
