---
name: design-registry
description: Build the authoritative, pixel-verified spec↔design registry for a project — every ticket and spec page bound to its design node by rendered evidence, every component classified by role (template/widget/listing/primitive/parked), conflicts and sub-certain bindings queued for the owner as falsifiable checks. Use BEFORE the first design-bound build unit of a new project, when inheriting ANY name-based binding claims (prior harvests, PM-authored links, decision decks), or as incident response when one binding proves wrong. Triggers - "design registry", "rescan the design", "bind the design", "verify the spec-to-Figma mapping", "which Figma node is X", "are these bindings right".
---

# Design Registry — pixel-verified spec↔design bindings

Purpose: produce the one artifact every design-bound build round cites — a
registry mapping tickets + spec pages ↔ design nodes, with identity
established by RENDERED PIXELS and usage evidence, never names; plus a
role classification of every component, a facts-only conflict record, an
owner queue for everything below certainty, and a salvage diff of all
inherited claims.

Provenance: distilled from the project-G design rescan (2026-08-12/13),
run as incident response after a name-bound harvest chain misbound an
entire component family. The failure mode to internalize: components
named "Stage Slider V3" were actually the Image Teaser List widget; a
full plan was written, adversarially reviewed, and revised against the
wrong component — **internally consistent at every step, wrong at the
root**. Three agents held the data; none rendered a pixel until the
owner did. The rescan re-verified 8/10 shipped-widget records, rebound 4
misnamed units, reclassified the whole library, and found two authority
files asserting stale claims about already-shipped work.

## When to run

1. **New project, before the first design-bound build unit.** Not
   literally day one — after repo scaffolding, before any widget/page
   round cites a design node. Greenfield cost ≈ half a day (enumerate +
   bind; no salvage forensics).
2. **On inheriting ANY binding claims** — prior harvests, extraction
   records, PM-authored spec links, decision decks. Run at least the
   salvage-diff step. Inherited mappings are CLAIMS, including your own
   from last month.
3. **Incident response** when one binding proves wrong: assume the whole
   chain is suspect, not the instance. Full run.

## Hard rules (each one is a burned lesson)

1. **Names are evidence, NEVER identity.** In one project, ALL of these
   lied simultaneously: component-set names (fossils of an archived
   concept lineage), board names (two boards with the same name hosting
   different families; a course-cards set on a board named after another
   widget), board canvas titles (a third contradictory label on the same
   board), and the spec's own design links (a PM misclick pointing an
   approved spec at a different widget — copy-pasted from the adjacent
   page). Identity = rendered pixels of the component AND ≥1 placed
   instance in context, plus usage evidence. Component properties help
   (a rows-property literally named "Linklist" settled a rebinding);
   read them.
2. **Both directions, always.** Spec-driven (every ticket/spec page →
   design location or NOT-FOUND flag) AND design-driven (every component
   + page section → spec binding or UNSPECCED flag). The design-driven
   sweep is what CATCHES misbindings; spec-driven alone can only confirm
   them.
3. **100% or owner.** Anything below certainty goes to an owner queue as
   falsifiable screenshot pairs — never resolved by inference. Ratify
   even convergent high-stakes rebindings: "internally consistent" is
   what the failure mode looks like from the inside.
4. **Encapsulate the pass.** All output in ONE new directory (own
   branch/worktree); modify nothing existing until the owner ratifies
   and orders the merge. Evidence binaries live OUTSIDE the repo,
   referenced by path.
5. **Every claim is a falsifiable prediction.** The owner checklist row
   is "open this link — you should see X", where X comes from the
   finding. A mismatch falsifies the row. This made a full owner review
   take minutes and caught a stale authority file in the process.
6. **Instances: exhaustive from data, verified by eyes, ancestor-visible.**
   Enumerate ALL placements from API data; eyes on ≥1 instance per
   distinct context. Compute visibility through the ANCESTOR chain —
   instance-local `visible` flags lie (a hidden parent group makes a
   "visible" card cluster a phantom). Hidden layers are parked designer
   intent: designer questions, never build input, and never silently
   dropped either.
7. **Masters are defaults; placed instances are truth** (imported from
   figma-extract rule 1 — it applies to identity, not just geometry).
   Overrides, variant choice per context, and per-page content live on
   instances; the variant-per-context mapping is what separates template
   chrome from widgets (see step 4).
8. **Trust tiers, explicit in every row.** e.g. client-approved spec
   pages = behavioral ground truth; agency-authored drafts = claims; the
   rendered design = the only visual ground truth; tickets = checklist.
   A binding row states which tier its spec side sits on.
9. **The registry needs a maintenance hook the day it merges.** Wire it
   into the repo's distill/post-merge ritual: every design-bound unit
   that ships updates its registry row (status + merge ref). An
   authority file without a write-back ritual becomes the next stale
   authority — observed twice in one day (a "build this next" roadmap
   entry for a unit that had shipped three days earlier).

## Method

1. **Enumerate the three surfaces.** Tickets (API; full project dump —
   note which stories LACK spec pages and which spec pages lack
   stories: both are registry flags). Spec tree (enumerate the FULL
   tree, don't trust a partial list; Confluence folders are invisible to
   page-walk APIs — use the v2 `direct-children` REST through a
   logged-in browser session). Design file: pages → boards → component
   sets via depth-limited REST (`?depth=2`, then per-board `/nodes` —
   NEVER the full-file GET first, see Access ladder).
2. **Build the instance index.** Outermost instances only (skip
   instance-internals), main-component → set resolution, ancestry
   chain, bbox, ancestor-computed visibility. Best source: plugin-API
   full walk (see Access ladder). A stale REST dump is usable as
   CANDIDATE data if tagged with its version — renders are always
   current-version pixels, so bindings stay fresh-verified.
3. **Identity pass — eyes on every component.** Render every set
   (REST `/images` batches or plugin `exportAsync`); LOOK at every
   render; batch via labeled contact-sheet montages (PIL) to keep the
   pass tractable. Record identity as what the pixels show, not what
   the name says. Duplicate names get disambiguated here (two "Grid
   Section" sets = icon grid vs card grid, settled only by rendering
   both in context).
4. **Role taxonomy — classify every component.** One role each:
   TEMPLATE (page-top/site chrome driven by content-type fields — the
   tell: instanced once per page top, variant type correlates with
   content class; map variant-per-context from main-component names),
   WIDGET (editor-placed, repeats mid-page across pages), LISTING
   (query-driven shells/rows/filters/pagination — the tell: rows nested
   inside a universal list-shell set), PRIMITIVE (nested-only
   composition vocabulary), PARKED (hidden-only, archive-board, or
   client-blocked). This taxonomy is the cure for "the library boards
   are a mess" — boards mix roles freely and are never the unit of
   meaning.
5. **Bind, with confidence tiers** (VERIFIED-BY-EYES /
   OWNER-CONFIRMED / FLAGGED). Conflicts go in a facts-only file (no
   resolutions); sub-certain bindings go to the owner queue with the
   evidence pair and what YES/NO each implies.
6. **Salvage-diff every inherited claim** — extraction records, decks,
   plans, roadmap entries: RE-VERIFIED / CONTRADICTED / UNVERIFIABLE.
   Report only; corrections happen after ratification.
7. **Owner verification checklist** — stakes-first table, one clickable
   falsifiable check per row (☐ column). Decision-relevant rows first,
   corroborations second, cross-reference flags third.
8. **After ratification:** merge; re-point authority files with DATED
   notes (never silent edits); fix wrong upstream spec links with
   version messages; BANNER the incident-vector historical records
   (point at the registry — never rewrite dated records, they are
   provenance); install the maintenance hook (rule 9); expect the
   ratification conversation itself to surface more rulings — fold them
   in as OWNER-CONFIRMED with dates.

## Access ladder (Figma)

1. **REST with token:** fine for enumeration (`?depth=2`, `/nodes`) and
   renders (`/images`). The full-file GET on a large file can burn a
   MULTI-HOUR shared budget — 429s persisted 2h+ after a few attempts.
   Never probe-loop a 429; single retries, far apart.
2. **`window.figma` is gated on view-only files** — the plugin API
   simply isn't there.
3. **The unlock: export the `.fig` and import it into your own drafts**
   (owner does this; drafts are free). **Node-ids are preserved 1:1** —
   verify first thing (`getNodeById` on a known node) — and the copy
   has full plugin API in the browser. The copy is a frozen snapshot:
   stamp its date in provenance; re-export when the original moves.
   Files opened in the desktop app surface as cloud-backed "[local] …"
   entries reachable from Chrome.
4. **Plugin walk mechanics:** load + walk one page per invocation
   (dev-browser scripts have a ~30s wall clock; per-node getter loops
   are slow — collect everything in ONE recursive descent, computing
   ancestor visibility on the way down). Renders via
   `exportAsync` → base64 → decode outside. Read-only law from
   figma-extract applies verbatim (getters + exportAsync only).
5. **Live-tab fallback** (owner present): deep-link `?node-id=` +
   canvas screenshot per stop; the properties panel readout doubles as
   identity evidence. One failed connect = stop and ask; never
   retry-loop.

## Output contract

One directory (e.g. `docs/rescan/` or `docs/design-registry/`):

- `README.md` — method, trust tiers, data provenance incl. staleness
  caveats and what superseded what.
- `design-registry.md` — Part A spec-driven rows (ticket · spec page +
  tier · design node(s) · instances · confidence · evidence · flags);
  Part B design-driven set table; Part C role taxonomy + the
  variant-per-context template mapping; the safety rule ("build briefs
  cite registry rows; PARKED rows need a ruling").
- `conflicts.md` — every name-vs-role and spec-vs-design contradiction,
  facts only.
- `owner-queue.md` — sub-certain items as falsifiable pairs; rulings
  appended with dates as they land.
- `verification-checklist.md` — the owner's clickable spot-check table.
- `salvage-report.md` — inherited-claim diff, three buckets.
- Optional: `designer-letter-addendum.md` — questions only the designer
  can answer, batched for the project's designer-communication lane.

Evidence bank (outside the repo): raw API dumps tagged with file
version, all renders, browser captures, the instance index.
