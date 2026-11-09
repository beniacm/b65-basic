#!/usr/bin/env python3
"""Reference model of the GHZ scroller (examples/ghz.bas, act 1): the per
frame state machine of Maxice's SCROLLTEST as decoded from its 45GS02 code
(see docs/GHZ.md). pack: dict with the data tables (band, map, sine1,
sine2); the model produces the low bytes of the 26 screen rows' tokens:
row[r][t] for t = 0..103 (GOTOX bytes and glyph low bytes as SCROLLTEST
writes them), the ring slots as written, and the waterfall phase."""
BANDS = [  # rows, table, row stride, tile rows, step, reload add, wrap, fine shift, data offset
    dict(rows=(0, 10), tab='b1', stride=50, n=5, step=1, add=None, reload=0x1F, wrap=0x1D, shift=1, off=0),
    dict(rows=(10, 16), tab='b2', stride=49, n=3, step=1, add=None, reload=0x0F, wrap=0x1C, shift=0, off=0),
    dict(rows=(16, 18), tab='b3', stride=0, n=1, step=3, add=0x1F, reload=None, wrap=0x15, shift=1, off=0),
    dict(rows=(18, 20), tab='b3', stride=0, n=1, step=2, add=0x10, reload=None, wrap=0x15, shift=0, off=0x2A),
    dict(rows=(20, 22), tab='b3', stride=0, n=1, step=5, add=0x1F, reload=None, wrap=0x15, shift=1, off=0x54),
    dict(rows=(22, 24), tab='b3', stride=0, n=1, step=3, add=0x10, reload=None, wrap=0x15, shift=0, off=0x7E),
    dict(rows=(24, 26), tab='b3', stride=0, n=1, step=4, add=0x10, reload=None, wrap=0x15, shift=0, off=0xA8),
]
INIT_CNT = [1, 0x0A, 3, 3, 3, 3, 3]

class GHZ:
    def __init__(self, pack):
        self.p = pack
        self.cnt = list(INIT_CNT)
        self.col = [0] * 7
        self.fx = 0                 # front fine X ($2D1A)
        self.fcol = 0               # front column ($2D2E)
        self.speed = 4              # ($213F)
        self.ramp = True            # False: the speed stays (ghz.bas after act 1)
        self.wf_c = 0               # waterfall frame counter ($2D19), phase ($2D18)
        self.wf_p = 0
        self.rg = 0x84              # ring frame base ($2D1F), counter ($2D20)
        self.rc = 0
        self.ph = [0x00, 0x3F]      # $2FEB (x), $2FEC (y)
        self.c = [0x00, 0x3F]       # $2FF0, $2FF1
        self.row = [[0] * 208 for _ in range(26)]   # screen bytes per row
        for b in range(7):
            self.copyband(b)
        self.copyfront()

    def copyband(self, b):
        d = BANDS[b]
        tab = self.p[d['tab']]
        for t in range(d['n']):
            x = self.col[b] + d['off'] + t * d['stride']
            r = d['rows'][0] + 2 * t
            for i in range(21):
                v = tab[x + i]
                self.row[r][2 + 2 * i] = v
                self.row[r + 1][2 + 2 * i] = (v + 1) & 255

    def copyfront(self):
        m = self.p['map']
        for t in range(13):
            for i in range(21):
                v = m[t * 145 + self.fcol + i]
                self.row[2 * t][46 + 2 * i] = v
                self.row[2 * t + 1][46 + 2 * i] = (v + 1) & 255

    def frame(self):
        # $238E: the bands
        fine = []
        for b, d in enumerate(BANDS):
            c = self.cnt[b] - d['step']
            if c < 0:
                c = d['reload'] if d['add'] is None else c + d['add']
                self.col[b] += 1
                if self.col[b] >= d['wrap']:
                    self.col[b] = 0
                self.copyband(b)
            self.cnt[b] = c & 255
            fine.append(self.cnt[b] >> d['shift'])
        for b, d in enumerate(BANDS):
            for r in range(*d['rows']):
                self.row[r][0] = fine[b]
        # $2106: the waterfall
        self.wf_c += 1
        if self.wf_c == 8:
            self.wf_c = 0
            self.wf_p = (self.wf_p + 1) & 3
        # $2140: the front layer
        f = self.fx - self.speed
        if f < 0:
            f += 16
            self.fcol += 1
            if self.fcol == 0x7C:
                s = (self.speed + 1) & 15 if self.ramp else 0   # (ghz.bas: only in act 1)
                if s:
                    self.speed = s
                self.fcol = 0
        self.fx = f
        for r in range(26):
            self.row[r][44] = self.fx
        self.copyfront()
        # $2B1F: ring slots parked (byte 1 of each slot = 2), slot counters 0
        for r in range(26):
            for s in range(30):
                self.row[r][88 + 4 * s + 1] = 2
        cnt = [0] * 28
        # $2A41: ring motion
        s1, s2 = self.p['sine1'], self.p['sine2']
        self.ph[0] = (self.ph[0] + 1) & 255
        self.ph[1] = (self.ph[1] + 1) & 255
        self.rc += 1
        if self.rc == 10:
            self.rc = 0
            self.rg += 3
            if self.rg == 0x96:
                self.rg = 0x84
        rx, ry, rgl = [0] * 65, [0] * 65, [0] * 65
        q2, q3 = self.c[0], self.c[1]
        g = self.rg
        for grp in range(4):
            q0, q1 = self.ph[0], self.ph[1]
            for x in range(16, 0, -1):
                i = grp * 16 + x
                rx[i] = s1[q0] + s1[q2]
                ry[i] = (s2[q1] + s2[q3]) & 255
                rgl[i] = g
                q0 = (q0 + 16) & 255; q2 = (q2 + 16) & 255
                q1 = (q1 + 16) & 255; q3 = (q3 + 16) & 255
            q2 = (q2 + 0x20) & 255; q3 = (q3 + 0x20) & 255
            g += 3
            if g == 0x96:
                g = 0x84
        self.rings = (rx, ry, rgl)
        # $2B69: ring placement (not while the speed is 4)
        if self.speed != 4:
            for i in range(64, 0, -1):
                yo = ((ry[i] & 7) ^ 7) << 5
                idx = ry[i] >> 3
                gl = rgl[i]
                for k in range(3):
                    if idx >= 0x1C or cnt[idx] == 0x1D:
                        break
                    s = cnt[idx]
                    cnt[idx] += 1
                    if idx >= 2:
                        o = 88 + 4 * s
                        rr = self.row[idx - 2]
                        rr[o] = rx[i] & 255
                        rr[o + 1] = (rx[i] >> 8) | yo
                        rr[o + 2] = gl
                    idx += 1
                    gl = (gl + 1) & 255
        self.slots = cnt

def pack_from_prg(path):
    d = open(path, 'rb').read()
    m = d[2:]
    a = lambda x, n: list(m[x - 0x2001:x - 0x2001 + n])
    return dict(b1=a(0x3300, 250), b2=a(0x33FA, 147), b3=a(0x348D, 210), map=a(0x355F, 13 * 145),
                sine1=a(0x2DEB, 256), sine2=a(0x2EEB, 256))
