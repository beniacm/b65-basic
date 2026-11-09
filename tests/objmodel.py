#!/usr/bin/env python3
"""Python model of B65's v3 object integrator (src/obj.a OBJSTEP), bit for bit.

Entries are 32-byte bytearrays (the table layout of docs/USER.md "Objects"),
limits 4 x (x0, y0, x1, y1, action). step() does one frame for all objects
and returns the set of objects that got an event.

tests/objcheck.py runs random tables through B65 (OBJUPDATE in Xemu) and
through this model and compares every byte."""
import math

def sintab():
    th = math.pi / 2048
    c = round(2 * math.cos(th) * 2**30)
    a, b = round(math.sin(0.5 * th) * 2**30), round(math.sin(1.5 * th) * 2**30)
    t = []
    for _ in range(1024):
        t.append(a >> 14)
        a, b = b, ((c * b + (1 << 29)) >> 30) - a
    return t

T = sintab()

def u16(e, o): return e[o] | e[o + 1] << 8
def s16(e, o):
    v = u16(e, o)
    return v - 65536 if v & 0x8000 else v
def w16(e, o, v):
    v &= 0xffff
    e[o] = v & 255
    e[o + 1] = v >> 8

def rsin(r, ang):
    """r (signed 8.8) * sin(ang (16-bit turn)) as .SIN: 8.8, truncated."""
    i = (ang >> 4) & 1023
    if ang & 0x4000:
        i ^= 1023
    mag = T[i]
    neg = bool(ang & 0x8000)
    if r < 0:
        neg = not neg
        r = -r
    v = ((r & 0xffff) * mag) >> 16
    return (-v if neg else v) & 0xffff

def pos_add(e, fo, lo, v):
    """10.8 coordinate at (frac fo, bytes lo/lo+1) += v (8.8), flags kept."""
    v &= 0xffff
    s = e[fo] + (v & 255)
    e[fo] = s & 255
    s = e[lo] + (v >> 8) + (s >> 8)
    e[lo] = s & 255
    sign = 0xff if v & 0x8000 else 0
    h = (e[lo + 1] + sign + (s >> 8)) & 3
    e[lo + 1] = (e[lo + 1] & 0xfc) | h

def step(tab, lim, base_events=None):
    ev = set()
    for n, e in enumerate(tab):
        m = e[16]
        mode = m & 15
        if mode == 1:
            if m & 0x10:
                harm(tab, e)
            elif e[17] & 0x40:            # +17 bit 6: acceleration
                w16(e, 18, u16(e, 18) + u16(e, 22))
                w16(e, 20, u16(e, 20) + u16(e, 24))
            vx, vy = u16(e, 18), u16(e, 20)
            pos_add(e, 30, 0, vx)
            pos_add(e, 31, 2, vy)
        elif mode == 4:                     # fast: integer steps only
            for lo, vo in ((0, 19), (2, 21)):
                st = e[vo]
                sign = 0xff if st & 0x80 else 0
                t = e[lo] + st
                e[lo] = t & 255
                h = (e[lo + 1] + sign + (t >> 8)) & 3
                e[lo + 1] = h               # (the flag bits are cleared)
        elif mode == 2:
            w16(e, 18, u16(e, 18) + u16(e, 22))
            w16(e, 20, u16(e, 20) + u16(e, 24))
            r, a = s16(e, 18), u16(e, 20)
            vx, vy = rsin(r, (a + 0x4000) & 0xffff), rsin(r, a)
            pos_add(e, 30, 0, vx)
            pos_add(e, 31, 2, vy)
        elif mode == 3:
            w16(e, 20, u16(e, 20) + u16(e, 24))
            r, a = s16(e, 18), u16(e, 20)
            ox, oy = rsin(r, (a + 0x4000) & 0xffff), rsin(r, a)
            p = tab[u16(e, 28) & 1023]
            for fo, lo, o in ((30, 0, ox), (31, 2, oy)):
                s = p[fo] + (o & 255)
                e[fo] = s & 255
                s = p[lo] + (o >> 8) + (s >> 8)
                e[lo] = s & 255
                sign = 0xff if o & 0x8000 else 0
                h = (p[lo + 1] + sign + (s >> 8)) & 3
                e[lo + 1] = (e[lo + 1] & 0xfc) | h
        else:
            continue
        if bounds(e, lim, m):
            kill(e, n, ev)
            continue
        life = u16(e, 26)
        if life and e[17] & 0x10:
            life -= 1
            w16(e, 26, life)
            if life == 0:
                kill(e, n, ev)
    return ev

def kill(e, n, ev):
    e[4] = 0
    e[16] = 0
    ev.add(n)

def harm(tab, e):
    p = tab[u16(e, 28) & 1023]
    k = u16(e, 22)
    for fo, lo, vo in ((30, 0, 18), (31, 2, 20)):
        d = ((e[lo + 1] << 16 | e[lo] << 8 | e[fo]) - (p[lo + 1] << 16 | p[lo] << 8 | p[fo]))
        hi = (d >> 16) & 3
        d = (d & 0xffff) | (hi << 16)
        if hi >= 2:
            d -= 1 << 18                # signed 10.8
        a = ((k * abs(d)) >> 8) & 0xffff
        if d >= 0:
            a = -a
        w16(e, vo, u16(e, vo) + a)

def coord(e, axis):
    lo = 0 if axis == 0 else 2
    v = e[lo] | (e[lo + 1] & 3) << 8
    if axis == 1 and v >= 512:
        v -= 1024
    return v

def setc(e, axis, v):
    lo = 0 if axis == 0 else 2
    e[lo] = v & 255
    e[lo + 1] = (e[lo + 1] & 0xfc) | ((v >> 8) & 3)

def bounds(e, lim, m):
    """True: killed."""
    act = e[17] & 15
    if not act:
        return False
    x0, y0, x1, y1, _ = lim[(m >> 5) & 3]
    for axis, a, c0, c1 in ((0, act & 3, x0, x1), (1, (act >> 2) & 3, y0, y1)):
        if not a:
            continue
        c = coord(e, axis)
        side = None
        if c < c0:
            side = 0
        elif c1 < c:
            side = 1
        if side is None:
            continue
        if a == 3:
            return True
        if a == 1:
            size = c1 - c0 + 1
            setc(e, axis, c + size if side == 0 else c - size)
        elif a == 2:
            setc(e, axis, c0 if side == 0 else c1)
            if m & 15 == 2:
                h = u16(e, 20)
                w16(e, 20, (0x8000 - h) if axis == 0 else -h)
            else:
                vo = 18 + 2 * axis
                v = s16(e, vo)
                if e[17] & 0x20:
                    v >>= 1
                w16(e, vo, -v)
    return False
