#!/usr/bin/env python3
"""Run B65 BASIC test scripts on the real MEGA65 (lab setup: Rockchip at
$M65_HOST with m65run, the serial monitor on TCP 4510, m65d on TCP 4511).

  tests/board.py load                 load build/b65.prg and start it (fresh reset)
  tests/board.py run SCRIPT [...]     run test scripts, print transcripts
  tests/board.py smoke [--update]     run tests/smoke/*.txt, compare with *.expected
  tests/board.py type 'TEXT\\n'       type on the matrix (m65ctl)
  tests/board.py screen               dump the 80x25 text screen (screen RAM)

The script goes to attic RAM ($8000000, magic "B65HWTS:"; the monitor's binary
load 'l', as m65run uses it, then three spots read back); B65 BASIC reads it
as keyboard input, writes a transcript to $8010000 and the marker "B65DONE"
to $800FFF0 when the script ends (then it continues with the keyboard).
The first 4 lines (banner + hardware line) are not compared.
"""
import os, re, socket, subprocess, sys, time

HOST = os.environ.get('M65_HOST', '192.168.1.143')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRG = os.path.join(ROOT, 'build', 'b65.prg')
CTL = '/home/me/projects/mega65/scripts/m65ctl.py'


def retry(cmd, tries=4, timeout=120):
    for i in range(tries):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            if r.returncode == 0:
                return r.stdout
            err = r.stderr + r.stdout
        except subprocess.TimeoutExpired as e:
            err = 'timeout'
        time.sleep(3)
    raise RuntimeError('failed: %s: %s' % (' '.join(cmd), err[-300:]))


def mon(cmd, wait=0.5):
    for i in range(4):
        try:
            with socket.create_connection((HOST, 4510), timeout=5) as s:
                s.sendall((cmd + '\r').encode())
                s.settimeout(0.1)
                out, t0 = b'', time.time()
                while time.time() - t0 < wait:
                    try:
                        out += s.recv(65536)
                    except socket.timeout:
                        pass
            return out.decode('latin-1')
        except OSError:
            time.sleep(2)
    raise RuntimeError('monitor not reachable')


def peek(addr, n):
    data = b''
    a = addr
    while len(data) < n:
        r = mon('M%07x' % a, 1.0)
        got = b''
        for m in re.finditer(r':0?([0-9A-F]{7}):([0-9A-F]{32})', r):
            if int(m.group(1), 16) == a + len(got):
                got += bytes.fromhex(m.group(2))
        if not got:
            raise RuntimeError('no monitor reply for %07X' % a)
        data += got
        a += len(got)
    return data[:n]


def poke(addr, data):
    for i in range(0, len(data), 16):
        mon('s%07x %s' % (addr + i, ' '.join('%02x' % b for b in data[i:i + 16])), 0.25)


def load_binary(addr, data):
    """write data at a 28-bit address with the monitor's binary load
    ('l<start> <end>' then the raw bytes, 4 KB at a time; the end is the low
    16 bits of start + length, as m65run does it: ~190 KB/s instead of ~50
    bytes/s through 's' lines), then compare three 256-byte spots read back"""
    with socket.create_connection((HOST, 4510), timeout=5) as s:
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        for o in range(0, len(data), 4096):
            chunk = data[o:o + 4096]
            a = addr + o
            s.setblocking(False)            # drop output already buffered
            try:
                while s.recv(65536):
                    pass
            except (BlockingIOError, InterruptedError):
                pass
            s.setblocking(True)
            s.sendall(('l%x %x\r' % (a, (a + len(chunk)) & 0xFFFF)).encode() + chunk)
            out, t0 = b'', time.time()
            s.settimeout(3)
            while not out.rstrip(b'\r\n ').endswith(b'\n.') and time.time() - t0 < 5:
                try:
                    out += s.recv(65536)
                except socket.timeout:
                    break
    for o in sorted({0, max(0, len(data) // 2 - 128), max(0, len(data) - 256)}):
        n = min(256, len(data) - o)
        if peek(addr + o, n) != data[o:o + n]:
            print('binary load: read-back differs at %07X, writing with s lines (slow)' % (addr + o))
            poke(addr, data)
            return


def ctl(*args):
    return retry(['/usr/bin/python3', CTL] + list(args), timeout=60)


def load(reset=True):
    retry(['scp', '-o', 'ConnectTimeout=8', PRG, 'root@%s:/tmp/b65.prg' % HOST])
    # no retry here: a second m65run would type RUN into the running B65
    r = subprocess.run(['ssh', '-o', 'ConnectTimeout=8', 'root@%s' % HOST,
                        'm65run /tmp/b65.prg --run' + (' --reset' if reset else '')],
                       capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        raise RuntimeError('m65run failed: ' + (r.stderr + r.stdout)[-300:])
    time.sleep(3)


def expand_includes(script):
    """'#include path' lines (path relative to the repository) insert that
    file, as in tests/run.py"""
    out = []
    for ln in script.split(b'\n'):
        if ln.startswith(b'#include '):
            out.append(open(os.path.join(ROOT, ln[9:].strip().decode()), 'rb').read().rstrip(b'\n'))
        else:
            out.append(ln)
    return b'\n'.join(out)


def run_script(path, timeout=300):
    script = expand_includes(open(path, 'rb').read())
    if not script.endswith(b'\n'):
        script += b'\n'
    blob = b'B65HWTS:' + script + b'\0'
    assert len(blob) < 0xFFF0
    poke(0x800FFF0, b'\0' * 8)          # clear the done marker
    load_binary(0x8000000, blob)        # script (magic written last would be nicer:
    load(reset=True)                    # B65 reads it at start-up)
    t0 = time.time()
    while time.time() - t0 < timeout:
        if peek(0x800FFF0, 7) == b'B65DONE':
            break
        time.sleep(2)
    else:
        print('*** TIMEOUT waiting for B65DONE')
    out = b''
    a = 0x8010000
    while True:
        chunk = peek(a, 256)
        if 0 in chunk:
            out += chunk[:chunk.index(0)]
            break
        out += chunk
        a += 256
    return out.decode('latin-1').replace('\r\n', '\n').replace('\r', '')


def screen():
    d = peek(0x800, 2000)
    for r in range(25):
        print(''.join(chr(c & 0x7f) if 32 <= (c & 0x7f) < 127 else '.' for c in d[r * 80:r * 80 + 80]).rstrip())


def strip_banner(t):
    return '\n'.join(t.split('\n')[4:])


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == 'load':
        load(reset=True)
    elif a[0] == 'type':
        print(ctl('type', a[1]))
    elif a[0] == 'screen':
        screen()
    elif a[0] == 'run':
        for p in a[1:]:
            print('=== %s' % p)
            print(run_script(p))
    elif a[0] == 'smoke':
        import glob
        fails = 0
        for p in sorted(glob.glob(os.path.join(ROOT, 'tests/smoke/*.txt'))):
            t = run_script(p)
            exp = os.path.splitext(p)[0] + '.expected'
            bexp = os.path.splitext(p)[0] + '.board.expected'   # board-specific (e.g. K325T info)
            if os.path.exists(bexp):
                exp = bexp
            e = open(exp, encoding='latin-1').read() if os.path.exists(exp) else ''
            if strip_banner(t).rstrip() == strip_banner(e).rstrip():
                print('PASS', os.path.basename(p))
            else:
                fails += 1
                print('FAIL', os.path.basename(p))
                open(os.path.join(ROOT, 'build', os.path.basename(p) + '.board'), 'w').write(t)
        sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
