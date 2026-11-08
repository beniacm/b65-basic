#!/usr/bin/env python3
"""LZH: LZ77 with canonical-Huffman literals, for the overlay images.

One code-length table (256 nibbles = 128 bytes, symbol 2k in the high
nibble of byte k) is shared by all streams. A stream is a bit string, most
significant bit of each byte first:
  0 <huffman literal>
  1 <gamma(length - 1)> 0 <8 bits: distance - 1>       (distance 1..256)
  1 <gamma(length - 1)> 1 <16 bits: distance>, high byte first
                                                      (distance 0 = end)
gamma(v), v >= 1: k zero bits, then v in k + 1 bits (k = floor(log2 v)).
Lengths 2..256. Canonical codes: shorter first, then by symbol value."""
import heapq, sys

MAXLEN = 15

def code_lengths(freq):
    f = dict((s, c) for s, c in freq.items() if c)
    while True:
        h = [(c, i, [s]) for i, (s, c) in enumerate(sorted(f.items()))]
        heapq.heapify(h)
        L = dict((s, 0) for s in f)
        if len(h) == 1:
            L[h[0][2][0]] = 1
            return L
        n = len(h)
        while len(h) > 1:
            a = heapq.heappop(h); b = heapq.heappop(h)
            for s in a[2] + b[2]:
                L[s] += 1
            n += 1
            heapq.heappush(h, (a[0] + b[0], n, a[2] + b[2]))
        if max(L.values()) <= MAXLEN:
            return L
        f = dict((s, (c + 1) // 2) for s, c in f.items())

def canonical(L):
    codes = {}
    code = 0
    for ln in range(1, MAXLEN + 1):
        for s in range(256):
            if L.get(s, 0) == ln:
                codes[s] = (code, ln)
                code += 1
        code <<= 1
    return codes

def tokens(d):
    """greedy parse with one byte of lazy look-ahead"""
    n = len(d); heads = {}; out = []; i = 0
    def best(i):
        b = (0, 0)
        if i + 2 > n:
            return b
        for j in reversed(heads.get(bytes(d[i:i + 2]), [])[-400:]):
            l = 0
            while i + l < n and d[j + l] == d[i + l] and l < 256:
                l += 1
            if l > b[0] or (l == b[0] and i - j < b[1]):
                b = (l, i - j)
        return b
    def ok(l, dist):
        return l >= 3 or (l == 2 and dist <= 256)
    def add(i):
        if i + 2 <= n:
            heads.setdefault(bytes(d[i:i + 2]), []).append(i)
    while i < n:
        l, dist = best(i)
        if ok(l, dist):
            l2, d2 = best(i + 1) if i + 1 < n else (0, 0)
            if ok(l2, d2) and l2 > l + 1:
                out.append(('L', d[i])); add(i); i += 1
                continue
            out.append(('M', l, dist))
            for k in range(l):
                add(i + k)
            i += l
        else:
            out.append(('L', d[i])); add(i); i += 1
    return out

class Bits:
    def __init__(self):
        self.b = bytearray(); self.n = 0; self.cur = 0
    def put(self, v, k):
        for i in range(k - 1, -1, -1):
            self.cur = self.cur << 1 | (v >> i & 1); self.n += 1
            if self.n == 8:
                self.b.append(self.cur); self.cur = 0; self.n = 0
    def gamma(self, v):
        k = v.bit_length() - 1
        self.put(0, k); self.put(v, k + 1)
    def done(self):
        if self.n:
            self.b.append(self.cur << (8 - self.n))
        return bytes(self.b)

def pack(blobs):
    """-> (table128, [stream, ...])"""
    toks = [tokens(b) for b in blobs]
    freq = {}
    for t in toks:
        for x in t:
            if x[0] == 'L':
                freq[x[1]] = freq.get(x[1], 0) + 1
    L = code_lengths(freq)
    codes = canonical(L)
    table = bytes((L.get(2 * k, 0) << 4) | L.get(2 * k + 1, 0) for k in range(128))
    streams = []
    for t in toks:
        w = Bits()
        for x in t:
            if x[0] == 'L':
                c, ln = codes[x[1]]
                w.put(0, 1); w.put(c, ln)
            else:
                w.put(1, 1); w.gamma(x[1] - 1)
                if x[2] <= 256:
                    w.put(0, 1); w.put(x[2] - 1, 8)
                else:
                    w.put(1, 1); w.put(x[2], 16)
        w.put(1, 1); w.gamma(1); w.put(1, 1); w.put(0, 16)
        streams.append(w.done())
    return table, streams

def unpack(table, s):
    L = {}
    for k in range(128):
        L[2 * k] = table[k] >> 4; L[2 * k + 1] = table[k] & 15
    cnt = [0] * (MAXLEN + 1); syms = []
    for ln in range(1, MAXLEN + 1):
        for x in range(256):
            if L[x] == ln:
                cnt[ln] += 1; syms.append(x)
    pos = [0]
    def bit():
        v = s[pos[0] >> 3] >> (7 - (pos[0] & 7)) & 1; pos[0] += 1; return v
    def bits(k):
        v = 0
        for _ in range(k):
            v = v << 1 | bit()
        return v
    def huff():                      # as puff.c decode()
        code = first = index = 0
        for ln in range(1, MAXLEN + 1):
            code |= bit()
            c = cnt[ln]
            if code - c < first:
                return syms[index + code - first]
            index += c; first += c; first <<= 1; code <<= 1
        raise ValueError('bad code')
    o = bytearray()
    while True:
        if not bit():
            o.append(huff()); continue
        k = 0
        while not bit():
            k += 1
        ln = (1 << k | bits(k)) + 1
        if bit():
            dist = bits(16)
            if dist == 0:
                return bytes(o)
        else:
            dist = bits(8) + 1
        for _ in range(ln):
            o.append(o[-dist])

if __name__ == '__main__':
    blobs = [open(f, 'rb').read() for f in sys.argv[1:]]
    t, ss = pack(blobs)
    for b, s in zip(blobs, ss):
        assert unpack(t, s) == b
        print(len(b), len(s))
