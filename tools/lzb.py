#!/usr/bin/env python3
"""LZB: a small byte-oriented LZ77 format for the overlay images.
Stream of blocks: token T.
  T < $80: T+1 literal bytes follow (1..128).
  T >= $80: match of (T & $7F) + 3 bytes (3..130) at distance D (2 bytes,
  little endian, 1..65535) back from the current output position.
  T = $00 with ... (end is given by the decompressed length).
Greedy parse with a longest-match search (hash chains)."""
import sys

def compress(d):
    out = bytearray(); lits = bytearray(); i = 0; n = len(d)
    heads = {}
    def flush():
        nonlocal lits
        while lits:
            c = lits[:128]; out.append(len(c) - 1); out.extend(c); lits = lits[128:]
    def best_at(i):
        best = (0, 0)
        if i + 3 > n: return best
        for j in reversed(heads.get(bytes(d[i:i+3]), [])[-256:]):
            l = 0
            while i + l < n and d[j + l] == d[i + l] and l < 130: l += 1
            if l > best[0]: best = (l, i - j)
            if l == 130: break
        return best
    def add(i):
        if i + 3 <= n: heads.setdefault(bytes(d[i:i+3]), []).append(i)
    while i < n:
        l, dist = best_at(i)
        if l >= 4 or (l == 3 and not lits):   # a 3-byte match only pays without a pending literal run
            # lazy: a longer match one byte later?
            l2, _ = best_at(i + 1) if i + 1 < n else (0, 0)
            if l2 > l + 1:
                lits.append(d[i]); add(i); i += 1; continue
            flush(); out.append(0x80 | (l - 3)); out.append(dist & 255); out.append(dist >> 8)
            for k in range(l): add(i + k)
            i += l
        else:
            lits.append(d[i]); add(i); i += 1
    flush()
    return bytes(out)

def decompress(c, n):
    o = bytearray(); i = 0
    while len(o) < n:
        t = c[i]; i += 1
        if t < 0x80:
            o.extend(c[i:i + t + 1]); i += t + 1
        else:
            l = (t & 0x7f) + 3; dist = c[i] | c[i + 1] << 8; i += 2
            for k in range(l): o.append(o[-dist])
    return bytes(o)

if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    c = compress(d)
    assert decompress(c, len(d)) == d
    print(len(d), len(c))
