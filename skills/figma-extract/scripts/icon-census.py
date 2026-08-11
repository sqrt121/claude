#!/usr/bin/env python3
"""Icon census over a Figma REST harvest (file-full.json).

Walks the harvested document tree, ancestor-visibility-checked, and reports
every visible INSTANCE whose master component name matches a prefix
(default "Icon/"), grouped by board. Identity comes from the harvest's
`components`/`componentSets` maps — by NAME, never by render (method rule
16; project-C wrong-icon incident, 2026-08-10).

Usage:
  icon-census.py <file-full.json> [BOARD_ID ...] [--prefix PFX ...] [--all]
                 [--json OUT.json]

BOARD_ID scopes the sweep to those nodes as roots (Figma ids, "7901:12444"
or the URL form "7901-12444"). Default roots: every top-level frame on
every canvas page (sections are descended into one level).

Output: a per-board table (path, master name, size, position; `[master]`
marks sites inside a component/set definition rather than a page instance)
plus name->count summaries. --json writes the same as a manifest. The
manifest is a derived, per-round artifact of its harvest — trusted only
alongside it, never a maintained bank.
"""

import argparse
import json
import sys


def norm_id(s):
    return s.replace("-", ":")


def resolve_name(component_id, components, component_sets):
    comp = components.get(component_id)
    if comp is None:
        return None
    set_id = comp.get("componentSetId")
    if set_id and set_id in component_sets:
        return f"{component_sets[set_id]['name']}/{comp['name']}"
    return comp["name"]


def iter_boards(document, board_ids):
    """Yield (page_name, board_node). Board roots are top-level frames per
    canvas page (one level of SECTION descended), or the nodes matching
    board_ids anywhere in the tree when ids are given."""
    if board_ids:
        wanted = set(board_ids)

        def find(node, page):
            if node.get("id") in wanted:
                yield (page, node)
                return  # a board is not nested inside another board
            for child in node.get("children", []) or []:
                yield from find(child, page)

        for page in document.get("children", []):
            yield from find(page, page.get("name", "?"))
        return

    for page in document.get("children", []):
        for child in page.get("children", []) or []:
            if child.get("type") == "SECTION":
                for sub in child.get("children", []) or []:
                    yield (page.get("name", "?"), sub)
            else:
                yield (page.get("name", "?"), child)


def census_board(board, components, component_sets, prefixes, match_all):
    rows = []

    def walk(node, path, in_master):
        if node.get("visible", True) is False:
            return
        ntype = node.get("type")
        in_master = in_master or ntype in ("COMPONENT", "COMPONENT_SET")
        if ntype == "INSTANCE" and node.get("componentId"):
            name = resolve_name(node["componentId"], components, component_sets)
            resolved = name is not None
            name = name if resolved else node.get("name", "?")
            low = name.lower()
            if match_all or any(low.startswith(p.lower()) for p in prefixes):
                box = node.get("absoluteBoundingBox") or {}
                rows.append({
                    "name": name,
                    "path": " > ".join(path),
                    "w": round(box.get("width", 0)),
                    "h": round(box.get("height", 0)),
                    "x": round(box.get("x", 0)),
                    "y": round(box.get("y", 0)),
                    "node_id": node.get("id"),
                    "component_id": node.get("componentId"),
                    "resolved": resolved,
                    "in_master": in_master,
                })
        for child in node.get("children", []) or []:
            walk(child, path + [child.get("name", "?")], in_master)

    walk(board, [], False)
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("harvest", help="path to a REST file-full.json")
    ap.add_argument("boards", nargs="*", help="board node ids to scope to")
    ap.add_argument("--prefix", action="append", default=None,
                    help="component-name prefix to match (repeatable; default Icon/)")
    ap.add_argument("--all", action="store_true",
                    help="list every visible instance, not just prefix matches")
    ap.add_argument("--json", metavar="OUT",
                    help="also write the manifest as JSON")
    args = ap.parse_args()

    with open(args.harvest) as f:
        data = json.load(f)
    components = data.get("components", {})
    component_sets = data.get("componentSets", {})
    prefixes = args.prefix or ["Icon/"]
    board_ids = [norm_id(b) for b in args.boards]

    manifest = {
        "source": args.harvest,
        "file_name": data.get("name"),
        "file_version": data.get("version"),
        "last_modified": data.get("lastModified"),
        "prefixes": ["*"] if args.all else prefixes,
        "boards": [],
    }
    totals = {}
    found_roots = 0

    for page_name, board in iter_boards(data.get("document", {}), board_ids):
        found_roots += 1
        rows = census_board(board, components, component_sets, prefixes, args.all)
        if not rows:
            continue
        counts = {}
        for r in rows:
            counts[r["name"]] = counts.get(r["name"], 0) + 1
            totals[r["name"]] = totals.get(r["name"], 0) + 1
        manifest["boards"].append({
            "id": board.get("id"),
            "name": board.get("name"),
            "page": page_name,
            "icons": rows,
            "counts": counts,
        })

        print(f"\n== {page_name} / {board.get('name')} ({board.get('id')}) — {len(rows)} site(s)")
        for r in rows:
            flags = "" + (" [master]" if r["in_master"] else "") + ("" if r["resolved"] else " [UNRESOLVED componentId]")
            print(f"  {r['name']:<40} {r['w']}x{r['h']:<6} at {r['x']},{r['y']}{flags}")
            print(f"    {r['path']}")
        print("  counts: " + ", ".join(f"{n} x{c}" for n, c in sorted(counts.items())))

    if board_ids and found_roots < len(board_ids):
        missing = len(board_ids) - found_roots
        print(f"\nWARNING: {missing} board id(s) not found in the harvest", file=sys.stderr)

    manifest["totals"] = totals
    print(f"\n== TOTALS across {len(manifest['boards'])} board(s) with matches")
    for name, count in sorted(totals.items()):
        print(f"  {name:<40} x{count}")
    if not totals:
        print("  (no matching instances)")

    if args.json:
        with open(args.json, "w") as f:
            json.dump(manifest, f, indent=2)
        print(f"\nmanifest written: {args.json}")


if __name__ == "__main__":
    main()
