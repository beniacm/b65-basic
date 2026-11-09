"""Python model of HITPIX(a,b) (src/objst.a): pixel overlap of two list mode
v3 objects. mem(addr) returns a byte of the 28-bit address space (chip RAM,
colour RAM at 0xFF80000); d054 is $D054, cset CHARPTR ($D068-$D06A)."""

def s10(v):
    v &= 0x3ff
    return v - 0x400 if v & 0x200 else v

def record(mem, base, n):
    e = [mem(base + 32 * n + k) for k in range(16)]
    h = e[5] & 63 or 1
    return dict(x=(e[0] | e[1] << 8) & 0x3ff, y=s10(e[2] | e[3] << 8), w=e[14] or 8,
                h=h, ph=8 * h, flags=e[6], scr=(e[6] & 15) << 16 | e[8] | e[9] << 8,
                col=e[10] | e[11] << 8, stride=e[12] | e[13] << 8, mask=e[4])

def row(mem, o, ly, lx0, n, d054, cset):
    """opaque flags of local pixels lx0 .. lx0+n-1 in local row ly"""
    out = [False] * n
    r, gy = ly >> 3, ly & 7
    vf = 0
    if o['flags'] & 0x20:
        r, vf = o['h'] - 1 - r, 0x80
    hf = (o['flags'] & 0x10) << 2
    t = (o['scr'] + r * o['stride']) & 0xfffff
    c = (o['col'] + r * o['stride']) & 0xffff
    px = 0
    while px < lx0 + n:
        w = mem(t) | mem(t + 1) << 8
        if w == 0xffff:
            break
        c0 = mem(0xff80000 + c)
        t, c = t + 2, (c + 2) & 0xffff
        if c0 & 0x10:                       # GOTOX: skipped
            continue
        if px + 8 > lx0:
            fl = (c0 & 0xc0) ^ hf ^ vf
            gr = 7 - gy if fl & 0x80 else gy
            g = w & 0x1fff
            fcm = d054 & (4 if g > 255 else 2)
            for j in range(8):
                i = px + j - lx0
                if i < 0 or i >= n:
                    continue
                col = 7 - j if fl & 0x40 else j
                if fcm:
                    op = mem(g * 64 + gr * 8 + col) != 0
                else:
                    op = mem((cset + g * 8 + gr) & 0xfffffff) & (0x80 >> col) != 0
                out[i] = out[i] or op
        px += 8
    return out

def hitpix(mem, base, a, b, d054, cset, dx=0, dy=0):
    A, B = record(mem, base, a), record(mem, base, b)
    A['x'] += dx
    A['y'] += dy
    if not A['mask'] or not B['mask']:
        return False
    x0, x1 = max(A['x'], B['x']), min(A['x'] + A['w'], B['x'] + B['w'])
    y0, y1 = max(A['y'], B['y']), min(A['y'] + A['ph'], B['y'] + B['ph'])
    if x1 <= x0 or y1 <= y0:
        return False
    n = x1 - x0
    for y in range(y0, y1):
        ra = row(mem, A, y - A['y'], x0 - A['x'], n, d054, cset)
        if not any(ra):
            continue
        rb = row(mem, B, y - B['y'], x0 - B['x'], n, d054, cset)
        if any(p and q for p, q in zip(ra, rb)):
            return True
    return False
