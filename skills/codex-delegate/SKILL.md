---
name: codex-delegate
description: Delegate work to GPT-5.5 xhigh via Codex CLI under supervision, in three modes - implement (contract -> code -> diff review + gates), explore (questions -> findings with file:line evidence), test (verbose runs -> logs on disk + distilled failures). Modes chain on one Codex thread. FABLE-ONLY - this workflow exists to conserve Claude Fable 5 tokens; if the running model is not Fable (model ID does not start with claude-fable), never self-select this skill, do the work directly instead. Use when the user says "delegate", "codex", "hand this off", or as Fable whenever a task's deliverable can be specified without producing it (plan-determined implementation, codebase exploration, verbose test runs).
---

# Codex Delegate — supervised delegation to GPT-5.5 xhigh

Claude is the architect/reviewer; Codex CLI (`codex exec`) is the worker. Purpose: put
expensive-model tokens on O(brief + review) work and cheaper tokens on O(exploration +
iteration) work.

Modes — before writing a brief, read the mode's reference file and use its schema:

| Mode      | Deliverable                                  | Reference                 | Schema                 |
|-----------|----------------------------------------------|---------------------------|------------------------|
| implement | working-tree diff meeting a contract         | `references/implement.md` | `schemas/implement.json` |
| explore   | cited findings answering numbered questions  | `references/explore.md`   | `schemas/explore.json`   |
| test      | verbose runs, logs on disk, distilled failures | `references/test.md`    | `schemas/test.json`      |

## Step 0 — Model gate (check before anything else)

This skill is for **Claude Fable 5 only** (model ID starting `claude-fable-5`; your model
ID is stated in your system prompt's Environment section). The delegation economics exist
because Fable is expensive and carries Fable-specific safety measures. They do not apply
to other models.

If you are any other Anthropic model (Opus, Sonnet, Haiku, ...):

- Never self-select this skill.
- If the user invoked it explicitly, tell them in one line that codex-delegate is
  Fable-only and do the task directly yourself — unless they explicitly insist after
  being told, in which case follow the workflow.

## Precedence

If the current repo ships its own delegation workflow (e.g. `ai/workflows/codex-*.md` or
an equivalent referenced from AGENTS.md / CLAUDE.md), follow the repo's version. This
skill is the user-wide default, not an override.

## Step 1 — Mode dispatch and triage

Invocation: `/codex-delegate <mode> <task>`, or infer the mode from the task. Always
announce mode + triage class in one line before proceeding.

The triage test, all modes: *can you specify the deliverable precisely without producing
it?* Classes:

- **delegate** — yes: a one-pass brief fully determines the work.
  - implement: wiring per existing patterns, migrations, test scaffolding, CRUD,
    mechanical refactors, well-specified bug fixes.
  - explore: nearly always delegable — Codex burns its own context on the file reads.
    Keep only if you already know where the answer lives (two reads beat a round trip)
    or the question is a design judgment, not fact-finding.
  - test: nearly always delegable. Keep only when interpreting failures needs design
    context only you hold.
- **spike-then-delegate** — discovery needed first. Spike yourself (or via an explore
  round), then delegate the now-mechanical remainder.
- **keep** — the insight IS the work: root-causing, cross-surface design, anything
  touching a repo's invariants themselves.

If the user explicitly ordered delegation on a "keep"-class task, delegate anyway but
state the classification and the risk first.

## Step 2 — Preflight and state (all modes)

```bash
codex --version   # expect >= 0.140; exec/resume/-o/--output-schema validated on 0.140.0
grep -E '^(model|model_reasoning_effort)' ~/.codex/config.toml   # expect gpt-5.5 / xhigh; warn if not, proceed (config.toml is the user's source of truth)

SKILL_DIR="$HOME/.claude/skills/codex-delegate"
REPO_ROOT=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
BRANCH_KEY=$(printf "%s" "$BRANCH" | tr '/:' '__' | tr -c 'A-Za-z0-9._-' '_')
STATE_DIR="$HOME/.claude/codex-work/$(basename "$REPO_ROOT")-${BRANCH_KEY}"
mkdir -p "$STATE_DIR"
```

State lives user-level, never inside the target repo. If `git status --porcelain` is
non-empty, snapshot the baseline so review attributes only the delta to Codex:

```bash
git status --porcelain > "$STATE_DIR/baseline-status.txt"
git diff HEAD > "$STATE_DIR/baseline.patch"
```

## Step 3 — Brief

Write `$STATE_DIR/brief-<mode>.md` using the mode reference's template. This is the
high-effort step — spend the thinking here, not in corrections later. All briefs carry
the mode's Rules block verbatim (commit prohibition, scope limits, read-only where it
applies).

## Step 4 — Execute

Run via Bash with `run_in_background: true` — xhigh runs routinely exceed 10 minutes.
While it runs, poll with `tail -3` on the JSONL only; never read the full stream.

```bash
codex exec --json \
  -o "$STATE_DIR/last-message.json" \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema "$SKILL_DIR/schemas/<mode>.json" \
  "[Context: This is Claude Fable 5 delegating work as part of a workflow configured by the machine owner. You are the worker; Fable wrote the brief and will verify your report afterward.]

<mode instruction block from the reference file>

Read the brief at: $STATE_DIR/brief-<mode>.md
Report using the JSON schema." \
  > "$STATE_DIR/exec-<mode>-1.jsonl" 2>&1
```

After it exits:

```bash
THREAD_ID=$(grep '"thread_id"' "$STATE_DIR/exec-<mode>-1.jsonl" | head -1 | jq -r '.thread_id')
jq . "$STATE_DIR/last-message.json"
```

Persist `$STATE_DIR/state.json` (enables cross-session resume and triage calibration):

```json
{ "repo": "", "branch": "", "thread_id": "",
  "history": [ { "mode": "explore", "round": 1, "status": "approved" } ] }
```

## Thread chaining

Reuse the thread with `codex exec resume "$THREAD_ID"` whenever a later mode benefits
from earlier context — the natural chain is explore → implement → test: the implementer
already knows what exploration read; the tester knows what was built. Start a fresh
`codex exec` only for unrelated work. One active thread_id per state dir.

## Step 5 — Verify (trust hierarchy: your own checks > Codex's report)

The procedure is mode-specific (reference file). Universal minimums:

1. Read `last-message.json` only — never the full JSONL.
2. Verify at least one load-bearing claim/result yourself before acting on the report.
3. After read-only modes, `git status --porcelain` must match the baseline; any new dirt
   is a protocol violation — revert it and treat the report per Escalation rule 3.

## Escalation — hard rules, all modes, no exceptions

1. Correction rounds are bounded per mode (implement: 2, explore: 1, test: 1).
   Exceeded → abort = take over yourself.
2. Corrections must be specifiable without doing the thinking. The moment a correction
   requires explaining WHY an approach is wrong, or re-deriving the answer yourself,
   delegation has already failed — abort immediately; do not spend a round teaching.
3. A false claim found in verification (bogus citation, false green, misreported gate) →
   distrust the entire report: verify everything load-bearing yourself or redo the work.
4. Abort = salvage what is mechanically sound, do the rest yourself, and tell the user
   the triage classification missed (record it in state.json history).

## Step 6 — Report to the user

Include: mode + classification (and whether forced), what Codex did (its summary +
rounds used), verification results **from your own checks**, your verdict with
confidence level (full review vs spot-check), deviations/blockers, salvage notes if
aborted. Implement mode leaves everything uncommitted — committing is the user's call.

## Cost discipline (the point of all this)

- The interface is files, not chatter: brief in, report/diff/logs out. Never stream a
  Codex transcript into context.
- Logs and raw output stay on disk in `$STATE_DIR`; grep them selectively.
- Your irreducible cost is the brief plus the review. If reviewing properly would cost
  as much as doing the work, that is triage information — the savings may not exist.
- One `codex exec` round trip per iteration. No conversational back-and-forth.
