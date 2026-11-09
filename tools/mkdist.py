#!/usr/bin/env python3
"""Build dist/: a D81 disk image with B65.PRG and the examples.

  dist/b65.d81   B65 (PRG, load it from BASIC 65: DLOAD "B65" then RUN)
                 + every examples/*.bas as a SEQ file NAME.BAS (plain text)
                 + every examples/basic65/*.bas tokenised as a BASIC 65 PRG
  dist/sd/       the same files for copying to the SD card root
                 (B65.PRG, NAME.BAS)

B65 loads programs from the SD card (FAT) or, read-only, from the D81
mounted as drive 0, and accepts plain-text programs: LOAD "NAME.BAS" (or
just LOAD "NAME") then RUN.

usage: tools/mkdist.py [outdir]
"""
import os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRACKS, SECTORS, SECSIZE = 80, 40, 256
DIRTRACK = 40


def version():
    s = open(os.path.join(ROOT, 'src/version.a')).read()
    return re.search(r'!text\s+"([^"]+)"', s).group(1)


class D81:
    def __init__(self, name, ident=b'B6'):
        self.img = bytearray(TRACKS * SECTORS * SECSIZE)
        self.free = {t: set(range(SECTORS)) for t in range(1, TRACKS + 1)}
        for s in range(4):                      # header, 2 BAM, first dir sector
            self.free[DIRTRACK].discard(s)
        h = self.sec(DIRTRACK, 0)
        h[0], h[1], h[2] = DIRTRACK, 3, 0x44
        h[4:20] = self.pad(name)
        h[20:22] = b'\xa0\xa0'
        h[22:24] = ident
        h[24] = 0xa0
        h[25:27] = b'3D'
        h[27:29] = b'\xa0\xa0'
        d = self.sec(DIRTRACK, 3)
        d[0], d[1] = 0, 0xff
        self.dirs = [3]

    @staticmethod
    def pad(name):
        n = name.upper().encode('ascii')[:16]
        return n + b'\xa0' * (16 - len(n))

    def off(self, t, s):
        return ((t - 1) * SECTORS + s) * SECSIZE

    def sec(self, t, s):
        o = self.off(t, s)
        return memoryview(self.img)[o:o + SECSIZE]

    def alloc(self):
        for t in list(range(1, DIRTRACK)) + list(range(DIRTRACK + 1, TRACKS + 1)):
            if self.free[t]:
                s = min(self.free[t])
                self.free[t].discard(s)
                return t, s
        raise SystemExit('disk full')

    def add(self, name, data, ftype):
        chain = []
        chunks = [data[i:i + 254] for i in range(0, len(data), 254)] or [b'']
        for c in chunks:
            chain.append((self.alloc(), c))
        for i, ((t, s), c) in enumerate(chain):
            b = self.sec(t, s)
            if i + 1 < len(chain):
                b[0], b[1] = chain[i + 1][0]
            else:
                b[0], b[1] = 0, len(c) + 1
            b[2:2 + len(c)] = c
        self.direntry(name, ftype, chain[0][0], len(chain))

    def direntry(self, name, ftype, first, nsec):
        for idx, s in enumerate(self.dirs):
            d = self.sec(DIRTRACK, s)
            for e in range(8):
                o = e * 32
                if d[o + 2] == 0:
                    d[o + 2] = 0x80 | ftype
                    d[o + 3], d[o + 4] = first
                    d[o + 5:o + 21] = self.pad(name)
                    d[o + 30], d[o + 31] = nsec & 255, nsec >> 8
                    return
        s = min(self.free[DIRTRACK])           # another directory sector
        self.free[DIRTRACK].discard(s)
        last = self.sec(DIRTRACK, self.dirs[-1])
        last[0], last[1] = DIRTRACK, s
        n = self.sec(DIRTRACK, s)
        n[0], n[1] = 0, 0xff
        self.dirs.append(s)
        self.direntry(name, ftype, first, nsec)

    def finish(self):
        for side, (first, last) in enumerate(((1, 40), (41, 80))):
            b = self.sec(DIRTRACK, 1 + side)
            b[0], b[1] = (DIRTRACK, 2) if side == 0 else (0, 0xff)
            b[2], b[3] = 0x44, 0xbb
            b[4:6] = self.sec(DIRTRACK, 0)[22:24]
            b[6], b[7] = 0xc0, 0
            for i, t in enumerate(range(first, last + 1)):
                o = 0x10 + 6 * i
                free = self.free[t]
                b[o] = len(free)
                bits = 0
                for s in free:
                    bits |= 1 << s
                b[o + 1:o + 6] = bits.to_bytes(5, 'little')
        return bytes(self.img)


# work in progress: kept out of the disk image and dist/sd until finished
WIP = {'walkers.bas', 'walkers65.bas'}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'dist')
    prg = open(os.path.join(ROOT, 'build/b65.prg'), 'rb').read()
    ex = sorted(f for f in os.listdir(os.path.join(ROOT, 'examples'))
                if f.endswith('.bas') and f not in WIP)
    sd = os.path.join(out, 'sd')
    if os.path.isdir(sd):               # no stale files from earlier builds
        shutil.rmtree(sd)
    os.makedirs(sd)
    disk = D81('B65 BASIC ' + version())
    disk.add('B65', prg, 2)
    shutil.copy(os.path.join(ROOT, 'build/b65.prg'), os.path.join(out, 'sd', 'B65.PRG'))
    for name in ('obj65', 'obj65x'):    # the BASIC 65 object library (docs/OBJ65.md)
        lib = open(os.path.join(ROOT, 'build', name + '.prg'), 'rb').read()
        disk.add(name.upper(), lib, 2)
        open(os.path.join(out, 'sd', name.upper() + '.PRG'), 'wb').write(lib)
    for f in ex:
        name = os.path.splitext(f)[0].upper().replace('_', '')[:12] + '.BAS'
        text = open(os.path.join(ROOT, 'examples', f), 'rb').read().replace(b'\r\n', b'\n')
        disk.add(name, text, 1)
        open(os.path.join(out, 'sd', name), 'wb').write(text)
        print('  %-16s %6d bytes  (examples/%s)' % (name, len(text), f))
    # the BASIC 65 twins (examples/basic65/*.bas), tokenised: DLOAD "NAME65" in BASIC 65
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import tok65
    for f in sorted(os.listdir(os.path.join(ROOT, 'examples', 'basic65'))):
        if f.endswith('.bas') and f not in WIP:
            name = os.path.splitext(f)[0].upper()[:16]
            prg = tok65.tokenise(open(os.path.join(ROOT, 'examples', 'basic65', f)).read())
            disk.add(name, prg, 2)
            open(os.path.join(out, 'sd', name + '.PRG'), 'wb').write(prg)
            print('  %-16s %6d bytes  (examples/basic65/%s, BASIC 65 PRG)' % (name, len(prg), f))
    open(os.path.join(out, 'b65.d81'), 'wb').write(disk.finish())
    print('dist/b65.d81: B65 %s + %d examples' % (version(), len(ex)))


main()
