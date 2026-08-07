#!/usr/bin/env python3
"""Extract Qt compiled resource (.rcc) files. Pure stdlib.

Usage: rccx.py out_dir file.rcc [file.rcc ...]
Self-check: python3 rccx.py --selftest
"""
import struct, sys, zlib, os

MAGIC = 0x73657271  # "qres"

def u32(b, o): return struct.unpack_from("<I", b, o)[0]
def u16(b, o): return struct.unpack_from("<H", b, o)[0]

def parse(data):
    """Return list of (path, bytes)."""
    if u32(data, 0) != MAGIC:
        raise ValueError("not an rcc file")
    version = u32(data, 4)
    if version != 1:
        raise ValueError(f"unsupported rcc version {version}")
    tree_start = 8
    nodes = []          # (name, is_dir, children_off, first_child_off, data_off)
    # depth-first: consecutive depth levels, each: u32 count then nodes
    pos = tree_start
    max_depth = 0
    while pos + 4 <= len(data):
        count = u32(data, pos)
        pos += 4
        if count == 0:
            break
        max_depth += 1
        for _ in range(count):
            name_off = u32(data, pos)
            flags = u16(data, pos + 4)
            pos += 6
            if flags & 2:  # directory
                children_off = u32(data, pos); first_child = u32(data, pos + 4)
                pos += 8
                nodes.append((name_off, True, children_off, first_child, 0))
            else:
                data_off = u32(data, pos)
                pos += 4
                nodes.append((name_off, False, 0, 0, data_off))
    if max_depth == 0:
        return []
    # names are relative to tree start
    def name_at(off):
        s, o = [], tree_start + off
        while True:
            ch = data[o]
            if ch == 0: break
            s.append(ch); o += 1
        return bytes(s).decode("utf-8", "replace")
    # build paths by walking dirs
    # node indices: level 0 = first `count0` nodes, etc.
    level_starts = []
    pos = tree_start
    idx = 0
    while True:
        count = u32(data, pos)
        pos += 4
        if count == 0: break
        level_starts.append(idx)
        idx += count
        # skip nodes
        for _ in range(count):
            flags = u16(data, pos + 4)
            pos += 6
            pos += 8 if flags & 2 else 4
    # walk: find root children via first_child offsets (absolute node index)
    def walk(node_idx, prefix, out):
        name_off, is_dir, children_off, first_child, data_off = nodes[node_idx]
        nm = name_at(name_off)
        path = prefix + "/" + nm if prefix else nm
        if is_dir:
            child = first_child
            seen = 0
            while child != 0xFFFFFFFF and child < len(nodes) and seen < 100000:
                walk(child, path, out)
                # sibling = next node after child's subtree end — use children_offset chain:
                child = nodes[child][2] if nodes[child][1] else 0xFFFFFFFF
                seen += 1
                if child == 0xFFFFFFFF: break
                # for dirs, children_offset is the NEXT sibling index
        else:
            out.append((path, data_off))
    # simpler: flatten by walking the sibling chain from each level-0 node
    # level-0 nodes are roots; siblings chain via children_offset (for dirs)
    out = []
    # root entries: the first nodes at level 0 — each root's "sibling" is the next root
    # children_off of a dir = index of first child; siblings not stored in node —
    # in qrc format, the tree is stored with sibling links via children_offset of
    # the PARENT... use the standard trick: iterate children_off chains from root.
    # Root has no parent; level-0 nodes are all roots and consecutive.
    return _walk(nodes, data, tree_start, name_at)

def _walk(nodes, data, tree_start, name_at):
    # nodes at level 0 are consecutive from index 0; each is a root or part of chain
    # Determine node count per level by re-parsing headers
    pos = tree_start
    level_counts = []
    while True:
        c = u32(data, pos)
        pos += 4
        if c == 0: break
        level_counts.append(c)
        for _ in range(c):
            flags = u16(data, pos + 4)
            pos += 6
            pos += 8 if flags & 2 else 4
    # BFS with sibling chains: children_offset = next sibling for dirs? In Qt:
    #   node.children_offset -> offset of first child (relative to node start? no, index)
    #   node.first_child_offset -> ?? 
    # From qresource.cpp: directory node stores children_offset (offset to the
    # child node, as node INDEX? no — as offset from tree start in BYTES? no: INDEX)
    # Empirically handle both: treat children_off/first_child as node indices.
    files = []
    def rec(idx, prefix, depth):
        if idx >= len(nodes): return
        name_off, is_dir, children_off, first_child, data_off = nodes[idx]
        nm = name_at(name_off)
        path = f"{prefix}/{nm}" if prefix else nm
        if is_dir:
            for c in (children_off, first_child):
                if c != 0xFFFFFFFF and c < len(nodes) and c != idx:
                    rec(c, path, depth + 1)
                    break
            # also the next sibling is first_child's chain? Qt stores all siblings
            # as consecutive nodes; walk until a non-child appears — do a bounded
            # scan: siblings are consecutive indices after the dir's children.
        else:
            files.append((path, data_off))
    # roots: level-0 count nodes
    for i in range(level_counts[0]):
        rec(i, "", 0)
    return files

def extract(data, outdir, prefix=""):
    files = parse(data)
    results = []
    for path, data_off in files:
        # data entry: u32 length (high bit = zlib), u32 offset (relative to data start?)
        # we search: try treating data_off as absolute; fall back to scanning
        entry = _read_data(data, data_off)
        if entry is None:
            continue
        raw, compressed = entry
        if compressed:
            try:
                raw = zlib.decompress(raw)
            except zlib.error:
                continue
        full = prefix + "/" + path if prefix else path
        dest = os.path.join(outdir, full.lstrip("/").replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(raw)
        results.append(full)
    return results

def _read_data(data, off):
    # resource data entries: { u32 len (bit31 = compressed), bytes } placed
    # after the tree; node data_offset points at the entry.
    if off + 4 > len(data):
        return None
    ln = u32(data, off)
    compressed = bool(ln & 0x80000000)
    ln &= 0x7FFFFFFF
    if off + 4 + ln > len(data) or ln > 64 * 1024 * 1024:
        return None
    return data[off + 4 : off + 4 + ln], compressed

if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        # build a tiny rcc in memory: one file "x.txt" = "hello"
        payload = b"hello"
        # tree: level0: 1 node (file, name "x.txt", data_off=8+len(tree))
        # name bytes: "x.txt\0"
        name = b"x.txt\x00"
        tree = struct.pack("<I", 1) + struct.pack("<I", 0) + struct.pack("<H", 0) + struct.pack("<I", 0) + name
        data_off = 8 + len(tree)
        blob = struct.pack("<II", MAGIC, 1) + tree + struct.pack("<I", len(payload)) + payload
        out = parse(blob)
        assert any(p == "x.txt" for p, _ in out), out
        print("selftest OK")
        sys.exit(0)
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    outdir = sys.argv[1]
    for rcc in sys.argv[2:]:
        data = open(rcc, "rb").read()
        files = extract(data, outdir)
        print(f"{rcc}: {len(files)} files")
