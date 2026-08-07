#!/usr/bin/env python3
"""Flatten figma-fidelity JSON trees into compact indented outlines."""
import json, sys, os

def fmt(n, styles, depth, out):
    ind = "  " * depth
    bits = [f"{n.get('type','?')[:4]} {n.get('name','?')}", f"[{n.get('w')}x{n.get('h')} @{n.get('x')},{n.get('y')}]"]
    if "layout" in n:
        bits.append(f"{n['layout'][:4]} gap={n.get('gap')} pad={n.get('pad')}")
        a = n.get("mainAlign", ""); c = n.get("crossAlign", "")
        if a or c: bits.append(f"align={a}/{c}")
    if "maxW" in n: bits.append(f"maxW={n['maxW']}")
    if "radius" in n: bits.append(f"r={n['radius']}")
    if "opacity" in n: bits.append(f"op={n['opacity']}")
    if "fill" in n:
        f = f"fill({n['fill']}"
        if "fillOpacity" in n: f += f"@{n['fillOpacity']}"
        f += ")"
        if n.get("fillStyleId") in styles: f += f"={styles[n['fillStyleId']]}"
        bits.append(f)
    if "stroke" in n:
        s = f"stroke({n['stroke']} w={n.get('strokeW')})"
        if n.get("strokeStyleId") in styles: s += f"={styles[n['strokeStyleId']]}"
        bits.append(s)
    if n.get("type") == "TEXT":
        t = f"{n.get('fontSize')}px/{n.get('lineHeight')} {n.get('font','')}"
        if n.get("textStyleId") in styles: t += f" style={styles[n['textStyleId']]}"
        if "tracking" in n: t += f" trk={n['tracking']}"
        bits.append(t)
        bits.append(json.dumps(n.get("chars", ""))[:44])
    if n.get("type") == "INSTANCE":
        if n.get("main"): bits.append(f"<<{n['main']}>>")
        p = n.get("props", {})
        lbl = {k: v for k, v in p.items() if k in ("Label", "Status", "Type", "Breakpoint", "Dropdown", "Design", "Version")}
        if lbl: bits.append(str(lbl))
    out.append(ind + " ".join(str(b) for b in bits))
    for c in n.get("children", []):
        fmt(c, styles, depth + 1, out)

for path in sys.argv[1:]:
    with open(path) as fh:
        data = json.load(fh)
    tree = data.get("tree"); styles = data.get("styles", {})
    if not tree:
        print(f"SKIP {path}: {data.get('error')}"); continue
    out = []
    fmt(tree, styles, 0, out)
    dst = path.replace(".json", ".outline.txt")
    with open(dst, "w") as fh:
        fh.write("\n".join(out) + "\n")
    print(f"{os.path.basename(dst)}: {len(out)} nodes")
