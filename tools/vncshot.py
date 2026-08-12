#!/usr/bin/env python3
"""Grab a screenshot from a no-auth VNC server (QEMU default).
Usage: vncshot.py host port out.png
"""
import socket, struct, sys, zlib

def main():
    host, port, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    s = socket.create_connection((host, port), timeout=10)
    def rex(n):
        b = b""
        while len(b) < n:
            c = s.recv(n - len(b))
            if not c:
                raise EOFError
            b += c
        return b
    rex(12)  # greeting
    s.sendall(b"RFB 003.008\n")
    ntypes = rex(1)[0]
    types = rex(ntypes)
    if 1 not in types:
        print("no None auth", types); sys.exit(1)
    s.sendall(b"\x01")  # choose None
    res = rex(4)
    if res != b"\x00\x00\x00\x00":
        print("auth failed", res); sys.exit(1)
    s.sendall(b"\x01")  # shared
    # ServerInit
    w, h = struct.unpack(">HH", rex(4))
    rex(16)  # pixel format
    name = rex(struct.unpack(">I", rex(4))[0])
    print(f"{w}x{h} name={name}")
    # FramebufferUpdateRequest (incremental=0, full)
    s.sendall(b"\x03\x00" + struct.pack(">HHHH", 0, 0, w, h))
    assert rex(1) == b"\x00"
    rex(1)  # padding
    nrects = struct.unpack(">H", rex(2))[0]
    print("rects:", nrects)
    x, y, rw, rh, enc = struct.unpack(">HHHHI", rex(12))
    print("rect", x, y, rw, rh, "enc", enc)
    if enc == 0:  # raw
        data = rex(rw * rh * 4)
    elif enc == 6:  # zlib (QEMU uses zlib for screendump-ish rects? actually raw)
        length = struct.unpack(">I", rex(4))[0]
        data = zlib.decompress(rex(length))
    else:
        print("unhandled encoding", enc); sys.exit(1)
    # BGRA -> RGB
    import struct as st
    px = []
    for i in range(0, len(data), 4):
        b, g, r, a = data[i], data[i + 1], data[i + 2], data[i + 3]
        px.append(bytes((r, g, b)))
    from PIL import Image
    img = Image.frombytes("RGB", (rw, rh), b"".join(px))
    img.save(out)
    print("saved", out)

if __name__ == "__main__":
    main()
