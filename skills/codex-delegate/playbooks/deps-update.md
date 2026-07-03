# Playbook: dependency update (bulk / overdue repo)

Distilled from a 2026-07 run on a client Nuxt storefront (65+72 type
errors fixed across two contracts, two module replacements, Nuxt 3→4, TypeScript 6,
eslint 10 — 14 phased commits, browser-smoke verified). Reuse the skeletons; re-derive
the specifics per repo. Reviewer = Fable; executor = Codex per the codex-delegate core.

## Phase strategy

0. **Hygiene baseline** (implement contract). Get lint + type gates green BEFORE any
   bump — re-enable cheaply-disabled rules, fix pre-existing errors. Every later
   regression is then attributable to a bump instead of archaeology. Snapshot
   `pnpm outdated` (or ecosystem equivalent) to the state dir.
1. **Split the inventory**: in-range / small majors / big majors / framework majors.
   Which majors to take, hold, or replace are one-way-door calls — the reviewer's,
   not the executor's; use decide mode if genuinely contested.
2. **In-range bumps**: reviewer runs the update command personally (one command, not
   delegation material), then delegates the fallout as an implement contract (skeleton
   below).
3. **Majors smallest-first, one contract each**. Dead or abandoned wrapper modules get
   replaced with the underlying library (module → direct plugin) rather than held.
   Hold-backs are documented with reasons, never silent.
4. **Framework major last**, own contract(s), full smoke suite re-run after.

Commit at phase boundaries (with user consent per repo rules); each boundary gets a
docs commit recording completion, deviations, and hold-backs. The close-out commit
carries a hold-back table: package, held-at version, reason, revisit trigger.

## Implement-contract skeleton (fallout fixes; guards proven in the run)

- The bump itself is already applied by the reviewer; manifests and lockfile are OUT of
  scope for the executor ("do NOT touch package.json/lockfile").
- **Error inventory file** in the state dir with every error as file(line,col), plus
  the exact command to regenerate the list (e.g.
  `pnpm type-check-all 2>/dev/null | grep ": error TS" | grep -v node_modules`).
- **Cluster errors by cause** in Implementation notes, with a prescribed fix per
  cluster and a preferred-fix order ("Pattern 1 — apollo 3.14 strictness, ~30 sites:
  widen the wrapper signature rather than touching every caller").
- **Type-source preference order** for the repo (generated API types → shared local
  types → library .d.ts → new colocated types).
- **Suppression ban with a grep gate** (`no-explicit-any`, `@ts-ignore`,
  `@ts-expect-error`, `as any`, `as unknown as X`), pre-existing exceptions named
  explicitly so the gate stays exact.
- **Runtime-behavior freeze**: type-level fixes only; a correct type exposing a latent
  bug goes in `deviations`, not into a behavior change. Prefer narrowing that yields
  identical runtime flow (`?.`, `?? fallback` matching what already renders).
- **Generated-file guards**: read-only, grep-don't-read (name the file sizes), never
  run codegen.
- **Baseline-relative invariant**: "only `src/**` changes beyond the pre-existing
  diff" + the baseline snapshot path (re-snapshot per phase).
- **Reference commits for style** once phase 1 lands ("match the typing patterns of
  commits X, Y").

## Test-brief skeleton (browser smoke; repos without unit coverage)

- Pin a RUNNING build ("already running at :PORT — do not start/stop/rebuild"); name
  env specifics the assertions depend on (analytics container ID, CSP nonce).
- Assertion-level runs, never "look at the page": exact DOM selectors
  (`.map .gm-style`), dataLayer/event payloads, script attributes; client-side
  navigation by CLICKING links, not hard reloads.
- One console-error sweep run across representative pages.
- Screenshots per run to `$STATE_DIR/smoke/`, logs tee'd per run, rerun as `-rN` after
  fixes; anomalies enumerated per the test schema (classification is the reviewer's).

## Reviewer checklist

- [ ] Gates re-run personally per contract — never approve on the executor's green.
- [ ] Diff review per contract against the phase baseline; an empty `deviations`
      array is unverified, not absence.
- [ ] Every anomaly attributed: same page/command on the base branch or production;
      new-on-branch = blocker until explained; recurring-across-pages = systemic, one
      finding. (The run's hydration-mismatch error was nearly lost as "noise".)
- [ ] Hold-back table complete and committed in the close-out.
- [ ] state.json history has one entry per round with adjudication notes.
