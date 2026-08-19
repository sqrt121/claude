---
name: figma-extract
description: Extract exact design facts (geometry, tokens, breakpoint ladders, colors, type) from a Figma file for implementation — via dev-browser attach to the user's logged-in session and the window.figma plugin API. Use when a task needs design measurements, component extraction, token mapping, spacing/layout verification against Figma, or "check the design/artboards". Read-only by hard rule.
---

# Figma Extract — node-tree extraction over screenshot archaeology

Purpose: turn a Figma design into EXACT implementation facts (px values,
auto-layout paddings/gaps, breakpoint ladders, fills/tokens, type styles)
with citations, without ever mutating the design file.

Provenance: distilled from the project-G component phase (Steps-List +
Image-with-Text extractions, 2026-07-29 — see
`project-G:docs/reference/2026-07-29-steps-list-figma-extraction.md`) and the
project-K design-system work (Figma-provenance-in-code pattern,
`project-K:apps/web/src/lib/image-sizes.ts`).

## Access (in order)

**Connect FIRST, at prompt time.** If the task might need the browser,
attaching is the first act of the turn — the user is present when they
prompt and can approve the takeover; minutes later they may be gone and
connection attempts hit an empty chair (popup storms, 2026-07-31).
**Batch the round:** one connection harvests EVERYTHING conceivable —
node trees, reference PNGs, SVG exports, `effects` — because going back
needs the user again; include the components queued NEXT (the project's
QUEUE/backlog), not just today's target. **Harvests are durable state:**
store them under the project's codex-work state dir (e.g.
`project-G-main/figma-fidelity/harvest/`), never a session /tmp scratchpad —
the Akkordeon trees sat in a scratchpad flagged "may not survive reboot"
and were rescued two days later (project-G 2026-08-02). One failed connect = stop and ask; never retry-loop
against a stale endpoint (Chrome restarts invalidate the cached CDP GUID).

1. **dev-browser attach to the user's LOGGED-IN Chrome** (`/browser` skill;
   `dev-browser --connect` with NO endpoint — the wrapper's takeover flow,
   owner approves once, one warm session). Never launch a fresh debug
   profile for design files: it has no logins, and the owner will
   (rightly) insist on their session.
   - Symptom check when attach fails: port 9222 LISTENS but `/json/*`
     returns empty ⇒ Chrome ≥136 default-profile protection. The takeover
     wrapper is the answer, not `--remote-debugging-port` flags.
2. Figma REST API if a token exists (`FIGMA_TOKEN`) — full file JSON, no
   browser. Check before doing anything interactive.
3. Fallback only: canvas screenshots + Design-panel reads (slow, error-prone
   — the panel shows one node at a time and you WILL misread renders).

### View-only files (`window.figma` is GATED)

On view/comment access the plugin API is absent — the core technique below
does not apply (project-G file, confirmed 2026-07-21 + 2026-07-31). The visual
fallback that works, proven on the project-G search sweep:

- Deep-link `?node-id=<id>` opens zoomed to the node; clicking a frame
  TITLE selects it; then **Enter descends into children, Tab cycles
  siblings, Shift+2 zooms to each — screenshot every stop**. This walks an
  arbitrarily tall artboard structurally. Do NOT navigate by mouse wheel:
  wheel pan/zoom is erratic over CDP and you lose position silently.
- The right Design panel shows EXACT numbers in view mode (W/H, auto-layout
  padding/gap, fills, token names) for the selected node — screenshot it
  alongside the canvas; that is where "side padding 176, gap 48" comes from
  without the API.
- Check the LAYERS panel before speccing: hidden layers (eye markers) look
  absent on canvas but are design intent parked in the file — a hidden
  "Video Teaser" under the project-G results list would have been invisible to a
  canvas-only read; surface such layers as designer questions.
- dev-browser writes relative screenshot paths to the DAEMON's cwd
  (`~/.dev-browser/tmp/`), not the shell's.

## The core technique: `window.figma` is live in the editor page

The full plugin API is exposed on `window` in the Figma web editor.
`page.evaluate` can serialize entire node trees as JSON in ONE call —
exact values, no zoom math, no panel screenshots:

```js
// dev-browser --connect <<'EOF'  (page = the user's Figma tab)
const data = await page.evaluate(() => {
  function ser(n, depth) {
    const o = { name: n.name, type: n.type, x: Math.round(n.x), y: Math.round(n.y),
                w: Math.round(n.width), h: Math.round(n.height) };
    if (n.layoutMode && n.layoutMode !== "NONE") {
      o.layout = n.layoutMode; o.gap = n.itemSpacing;               // NEGATIVE gap = overlap
      o.pad = [n.paddingTop, n.paddingRight, n.paddingBottom, n.paddingLeft];
    }
    if (n.maxWidth) o.maxW = n.maxWidth;                            // container caps live here
    if (n.layoutSizingHorizontal) o.sizeH = n.layoutSizingHorizontal;
    if (n.type === "TEXT") { o.fontSize = n.fontSize;
      o.lineHeight = n.lineHeight && n.lineHeight.value; o.chars = n.characters.slice(0, 30); }
    try { const f = n.fills && n.fills[0];
      if (f && f.type === "SOLID" && f.visible !== false) {
        const c = f.color; o.fill = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(","); }
    } catch (e) {}
    if (depth > 0 && n.children) o.children = n.children.map(c => ser(c, depth - 1));
    return o;
  }
  const frame = figma.currentPage.children.find(n => n.name === "TARGET");
  return ser(frame, 5);
});
```

Useful getters beyond the snippet: `figma.currentPage.selection`,
`node.itemReverseZIndex` (paint order — "image on top of card" lives here),
`node.getRangeAllFontNames`, `figma.getStyleById(node.fillStyleId).name`
(the TOKEN name, e.g. `backgrounds/bg-light`), `node.mainComponent.name`
(instance → library source), `node.componentProperties` (variant props).

## Attached tooling (`scripts/`)

The snippet above is a minimal illustration — for real rounds use the
attached templates instead of retyping it:

- `scripts/figma-ser-v2-template.js` — the full serializer: auto-layout
  incl. wrap/align/reverse-Z, per-side stroke weights, `effects`,
  opacity, `visible` on every node, `textStyleId`+`fontSize` pairs,
  fills beyond `[0]`, and per-instance `main` (master component name) +
  variant props — i.e. it already encodes rule 10's and rule 16's
  deciding getters. `scripts/figma-ser-template.js` is the earlier compact
  variant. Both are dev-browser templates: substitute the page id and
  target frame, run via `page.evaluate`, write the JSON into the
  project's harvest bank.
- `scripts/outline.py <harvest.json>…` — flattens harvested trees into
  compact indented outlines (writes `.outline.txt` next to each input);
  read/diff outlines instead of raw JSON.
- `scripts/pngscan.py <ref.png> <x> <y0> <y1>` — minimal PNG decoder +
  vertical scanline dump for rule 11: settles what the API reports as
  `mixed` or not at all (underline weights, stroke paint alpha, shadow
  falloff).
- `scripts/icon-census.py <file-full.json> [board-id …]` — walks a REST
  harvest (ancestor-visibility-checked) and prints per-board tables of
  every visible icon instance: path, master component name resolved via
  the `components`/`componentSets` maps, size, plus name→count
  summaries; `--json` writes the manifest. Rule 16's sweep tool. The
  output is a derived, per-round artifact — trusted only alongside its
  harvest, never a maintained bank.

## Hard rules (read-only law)

- **Getters only.** Never call any mutating plugin API (no `node.x = …`,
  no `figma.createX`, no `setProperties`, no plugin-data writes). Never add
  export settings (they are STORED IN THE FILE — export via UI modifies it;
  use the API or screenshots instead).
- Canvas interaction allowlist: click-select, Meta+click deep-select,
  Enter/Tab traversal (descend/sibling), Shift+1/2 zoom, Shift+G guides.
  NEVER: drags, arrow keys (nudge = edit!), double-click into text,
  Cmd+D/V, renames.
- Tell the owner what state you leave their tab in (page, zoom, guides).

## Method rules (each one is a burned lesson)

1. **Library components are DEFAULTS; page-artboard instances are truth.**
   Fills, placements, even column spans get overridden per instance (project-G:
   library card white → every Home instance `bg-light` full-width band).
   Always extract at least one REAL page instance; prefer instances over
   the component set for geometry.
2. **Extract every breakpoint artboard.** Ladders are non-linear (project-G band:
   72/72/120/160 across 1024/1280/1600) — interpolating from two points
   fabricates the third.
3. **`maxWidth` + centered on the widest artboard = the container cap.**
   The widest artboard often exists precisely to show capping behavior
   (2100 board centering a 1504 box ⇒ container 1600).
4. **Negative `itemSpacing` = overlap; check paint order** for which child
   sits on top (`itemReverseZIndex`).
5. **Map to the project's tokens; never ship raw px silently.** Off-token
   values in the design (a 15px text with no token) are DESIGNER QUESTIONS
   — implement the nearest token and flag it in the record.
6. **Document provenance at the point of use** (project-K pattern): each
   slot/`sizes` string/spacing constant cites its Figma measurement in a
   code comment, and the extraction lands as a dated record doc
   (`docs/reference/YYYY-MM-DD-<component>-figma-extraction.md`) with a
   values table + divergences + designer flags.
7. **Figma-vs-spec divergences go on record, not into code** (invariant-3
   spirit): if the design shows structure the written spec doesn't model,
   flag it — don't silently invent CMS fields for it.
8. Verify one load-bearing value visually (screenshot) after extraction —
   the API tells you the tree you asked for, not whether you asked for the
   right node.
9. **Export INSTANCES, never component masters.** Rule 1 applies to
   `exportAsync` too: masters carry hidden helper layers (stacked glyph
   variants, bounding boxes, layered avatars) that render into the SVG —
   a doubled search magnifier shipped before this was caught (project-G
   2026-07-31). Export the artboard instance; it renders only visible
   layers.
10. **Serialize the deciding getters:** `effects` (an empty array SETTLES
    shadow questions — never infer effects from renders alone), per-side
    stroke weights (`strokeWeight` is `figma.mixed` for underlines —
    read `strokeTopWeight`/`strokeBottomWeight`/…), fills beyond `[0]`
    (image fills, overlays), and the `textStyleId`+`fontSize` PAIR
    compared against the style's canonical size — same id + different
    size = per-node override, NOT a responsive style (project-G type incident:
    "responsive ramp" was really systematic overrides of single styles).
    ALSO: `visible` on EVERY node (without it, hidden layers — parked
    intent, master scaffolding, tail rows — are indistinguishable from
    rendered content except by render cross-check; project-G FAQ Controls
    Wrapper, 2026-08-02) and stroke PAINT `opacity` (a #111 divider at
    12% paint alpha reads as near-black without it and needed PNG pixel
    sampling to settle; same round).
11. **PNG-alpha decoding settles sub-pixel questions.** `exportAsync`
    renders transparency; decoding the PNG's alpha channel measures what
    the API reports as `mixed` or not at all (1.5px underline weights,
    shadow falloff ramps).
12. **Prior walkthrough notes are triage material, never build facts.** A
    UI build contract written from a design-notes summary instead of a
    fresh extraction shipped a wrong overlay AND contradicted the notes'
    own words ("filter sidebar" was in the summary; chips got built) —
    full redo round (project-G search, 2026-07-31). If the deliverable is
    user-facing UI and artboards exist, an extraction round precedes the
    contract. An owner's "don't go overboard" bounds polish effort, not
    fact-gathering — and an unavailable browser is a stop-and-ask (the
    unblock is one user command; the redo round costs hours).
13. **Inventory every frame with a disposition before building.** List every
    visible element of each target frame — per breakpoint, since composition
    itself can change (a 1024 two-column dropdown survived two passes as a
    full-screen modal because it was filed as a styling divergence) — and mark
    each `build` / `placeholder` / `deferred (why)` / `designer question`.
    Deferred-but-designed elements render as visible placeholders (measured
    values + `TODO(wiring:…)`), not absences; the owner rediscovering a known
    exclusion in review is a process failure (project-G chrome 2026-07-31: service
    band, header search, footer "Folgen Sie uns" all owner-caught).
14. **Master-vs-instance conflicts are questions, never silent calls.** An
    element visible only in the component master and hidden in every page
    instance is neither built nor dropped silently — record the conflict and
    ask (project-G CTA secondary link 2026-07-31: hidden in all 4 active variants
    AND all 47 page instances, yet wanted by the owner). Rules 1/9 give
    instances precedence for VALUES; existence conflicts get escalated.
15. **Alignment relationships are measured, not read.** Auto-layout props
    misread intent: the project-G nav was recorded as SPACE_BETWEEN/right-aligned,
    but the measured block center equaled the container center at 1600 AND
    1280 — the misread survived the dedicated fidelity pass (2026-07-30→31).
    For anything that could be centered, compute element-center vs
    container-center at ≥2 breakpoints and record the relationship.
16. **Glyph identity is a NAME, never a render judgment.** Refs at page
    scale cannot resolve a 24px glyph: a wrong icon survived a full 1:1
    pass — eyes AND numeric layers — and was QA-caught (project-C
    lockdown 2026-08-10: profile/book shipped for `Icon/course`/`Icon/modules`;
    the names sat unread in the harvest the whole time). For every
    visible icon INSTANCE in the round's scope, resolve the master
    component name — `main` in v2-serializer output, `componentId` →
    `components` map in a REST harvest (`scripts/icon-census.py` sweeps
    this) — and settle identity by name comparison against the code's
    icon atoms, recorded as a per-round identity map (design name → code
    atom → disposition). Exports follow the map, not a stockpile: only a
    site with no matching code atom gets its icon exported, that round,
    as an instance per rule 9. A pre-exported SVG pile trusted across
    rounds is the stale-asset trap; a greenfield bootstrap batch-export
    is project setup, not maintenance.
17. **Composition reads resolve CHILD variant identity, not just section
    identity — and visibility is a PATH property.** Two same-set section
    instances can host different card families via the child `Type`
    variant or a slot swap: resolve every hosted child's master name
    (`componentProperties` / `componentId` → components map), rule 16 one
    level deeper (project-G homepage 2026-08-18: both Home sliders read as
    "Teaser Slider ✓", owner caught the Type=Blog cards post-approval —
    a dedicated redo round). Same round, same trap class: a node's
    `visible: true` under a hidden ancestor is NOT rendered content —
    check ancestor visibility on every inventory walk, or a hidden
    intro/eyebrow reads as visible copy.

## Output contract

An extraction record (dated, in the repo's reference docs) containing: the
per-breakpoint values table, token mappings with off-token flags, layout
interpretation (columns/overlaps), divergences (library-vs-instance,
Figma-vs-spec), and the node names used — so the next extraction can
re-run the same query.
