#!/usr/bin/env python3
"""Extract Qt6 rcc v3 resource files (Adrenalin CNext UI). Pure stdlib."""
import struct, sys, os, zlib

def u32(d, o): return struct.unpack_from(">I", d, o)[0]
def u16(d, o): return struct.unpack_from(">H", d, o)[0]

NODE = 22  # v2/v3: name_off(4) flags(2) territory(2) language(2) payload(4) lastmod(8)

def extract(path, outdir):
    data = open(path, "rb").read()
    assert data[:4] == b"qres", "not an rcc"
    ver = u32(data, 4)
    assert ver >= 3, f"unsupported rcc version {ver}"
    tree_off, data_off, name_off = u32(data, 8), u32(data, 12), u32(data, 16)
    names, payloads = name_off, data_off
    root_count = u32(data, tree_off + 6)   # root node's child_count (root is node 0)
    root_child = u32(data, tree_off + 10)

    def node_name(node):
        no = u32(data, tree_off + node * NODE)
        ln = u16(data, names + no)          # u16 length at +0, u32 hash at +2, chars at +6
        chars = data[names + no + 6: names + no + 6 + ln * 2]
        s = "".join(chr(struct.unpack_from(">H", chars, i)[0]) for i in range(0, len(chars), 2))
        return s.encode("utf-8", "surrogatepass").decode("utf-8", "replace")

    def node_flags(node):
        return u16(data, tree_off + node * NODE + 4)

    def node_payload(node):
        return u32(data, tree_off + node * NODE + 10)

    written = 0
    def walk(node, relpath):
        nonlocal written
        flags = node_flags(node)
        name = node_name(node)
        p = os.path.join(relpath, name)
        if flags & 0x02:  # directory: count at +6, child index at +10 (no locale field)
            count = u32(data, tree_off + node * NODE + 6)
            child = u32(data, tree_off + node * NODE + 10)
            for i in range(count):
                walk(child + i, p)
        else:
            off = node_payload(node)  # file: data_offset at +10 (locale at +6/+8)
            ln = u32(data, payloads + off)
            blob = data[payloads + off + 4: payloads + off + 4 + ln]
            if flags & 0x01:  # stored as [u32 uncompressed_size][zlib stream]
                blob = zlib.decompress(blob[4:])
            elif flags & 0x04:
                raise SystemExit("zstd payload not supported")
            dst = os.path.join(outdir, p.lstrip("/"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(blob)
            written += 1

    for i in range(root_count):
        walk(root_child + i, "")
    return written

if __name__ == "__main__":
    outdir, *files = sys.argv[1:]
    total = 0
    for f in files:
        n = extract(f, outdir)
        print(f"{f}: {n} files")
        total += n
    print(f"TOTAL {total}")
