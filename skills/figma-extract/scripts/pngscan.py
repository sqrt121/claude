#!/usr/bin/env python3
"""Minimal PNG decoder (8-bit RGBA/RGB, non-interlaced) + vertical scanline dump."""
import struct, sys, zlib

def load(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, meta = 8, [], None
    while pos < len(data):
        ln, typ = struct.unpack_from(">I4s", data, pos)
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype, comp, filt, inter = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and inter == 0 and ctype in (2, 6), (depth, ctype, inter)
            meta = (w, h, 4 if ctype == 6 else 3)
        elif typ == b"IDAT":
            idat.append(chunk)
        pos += 12 + ln
    w, h, bpp = meta
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        if f == 1:
            for i in range(bpp, stride): line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    def px(x, y):
        i = y * stride + x * bpp
        return tuple(out[i:i + bpp])
    return px, w, h

path, x, y0, y1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
px, w, h = load(path)
prev = None
for y in range(y0, min(y1 + 1, h)):
    c = px(x, y)
    if c != prev:
        print(f"y={y} rgba{c}")
    prev = c
