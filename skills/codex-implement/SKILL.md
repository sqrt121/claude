---
name: codex-implement
description: Delegate plan-determined implementation work to GPT-5.5 xhigh via Codex CLI under supervision - write a contract, Codex implements, review the diff against hard gates, punch-list loop with strict escalation rules. FABLE-ONLY - this workflow exists to conserve Claude Fable 5 tokens; if the running model is not Fable (model ID does not start with claude-fable), never self-select this skill, implement directly instead. Use when the user says "delegate", "codex implement", "hand this to codex/gpt", or when running as Fable on a task whose solution is fully determined by a contract you can write in one pass.
---

# Codex Implement — supervised delegation to GPT-5.5 xhigh

Inverse of a codex-review loop: Claude is the architect/reviewer, Codex CLI (`codex exec`)
is the implementer. Purpose: put expensive-model tokens on O(contract + diff) work and
cheap(er)-model tokens on O(exploration + iteration) work.

## Step 0 — Model gate (check before anything else)

This skill is for **Claude Fable 5 only** (model ID starting `claude-fable-5`; your model
ID is stated in your system prompt's Environment section). The delegation economics exist
because Fable is expensive and carries Fable-specific safety measures. They do not apply
to other models.

If you are any other Anthropic model (Opus, Sonnet, Haiku, ...):

- Never self-select this skill.
- If the user invoked it explicitly, tell them in one line that codex-implement is
  Fable-only and implement the task directly yourself — unless they explicitly insist
  after being told, in which case follow the workflow.

## Precedence

If the current repo ships its own delegation workflow (e.g. `ai/workflows/codex-implement.md`
or an equivalent referenced from AGENTS.md / CLAUDE.md), follow the repo's version. This
skill is the user-wide default, not an override.

## Step 1 — Triage (the gate that makes this worth doing)

Classify the task and state the classification to the user in one line before proceeding:

- **delegate** — the solution is fully determined by a contract you can write in one pass:
  wiring per existing patterns, migrations, test scaffolding, CRUD surfaces, mechanical
  refactors, well-specified bug fixes.
- **spike-then-delegate** — discovery is needed first. Do the discovery/design spike
  yourself, then delegate the now-mechanical remainder.
- **keep** — the design insight IS the work: root-causing, cross-surface design, anything
  touching a repo's invariants themselves. Do it yourself; delegation would cost more.

The test: *can you specify the change precisely without solving it?* If writing an
adequate contract requires the design insight, it is not class "delegate".

If the user explicitly ordered delegation on a "keep"-class task, delegate anyway but
state the classification and the risk first.

## Step 2 — Preflight

```bash
codex --version   # expect >= 0.140; exec/resume/-o/--output-schema validated on 0.140.0
grep -E '^(model|model_reasoning_effort)' ~/.codex/config.toml   # expect gpt-5.5 / xhigh; warn if not, proceed anyway (config.toml is the user's source of truth)
```

Set up state (user-level, never inside the target repo):

```bash
SKILL_DIR="$HOME/.claude/skills/codex-implement"
REPO_ROOT=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
BRANCH_KEY=$(printf "%s" "$BRANCH" | tr '/:' '__' | tr -c 'A-Za-z0-9._-' '_')
STATE_DIR="$HOME/.claude/codex-work/$(basename "$REPO_ROOT")-${BRANCH_KEY}"
mkdir -p "$STATE_DIR"
```

Working tree: prefer clean. If `git status --porcelain` is non-empty, snapshot the
baseline so review attributes only the delta to Codex:

```bash
git status --porcelain > "$STATE_DIR/baseline-status.txt"
git diff HEAD > "$STATE_DIR/baseline.patch"
```

Discover the gates: package.json scripts (typecheck/lint/test/build), Makefile targets,
or commands documented in AGENTS.md / CLAUDE.md / CI config. Gates go into the contract
as exact commands. A repo with no conventions file AND no discoverable gates is a triage
signal in itself — the contract must carry everything and the savings shrink.

## Step 3 — Contract

This is the high-effort step — spend the thinking here, not in corrections later.
Write to `$STATE_DIR/contract.md`:

```markdown
# Contract: <task title>
> Repo: <path> | Branch: <branch> | Date: <date>

## Objective
<1-3 sentences: the observable outcome>

## In scope
<files / dirs / areas Codex may touch>

## Out of scope — do not touch
<files, behaviors, public APIs that must not change>

## Conventions
Follow AGENTS.md / CLAUDE.md at <paths>.        <!-- Codex reads AGENTS.md natively -->
<or: no conventions file — match the style of <reference files>>

## Invariants (must hold after the change)
1. <testable statement>

## Implementation notes
<every design decision, already made — no design choices may remain open>

## Edge cases
1. <case and expected behavior>

## Gates (all must pass)
    <exact command 1>
    <exact command 2>

## Rules
- Do NOT commit, stage, branch, push, or tag. Leave all changes in the working tree.
- Do not touch out-of-scope files. If you believe you must, stop and report BLOCKED with the reason.
- Do not add dependencies unless listed above.
```

## Step 4 — Execute

Run via Bash with `run_in_background: true` — xhigh runs routinely exceed 10 minutes.
While it runs, poll with `tail -3` on the JSONL only; never read the full stream.

```bash
codex exec --json \
  -o "$STATE_DIR/last-message.json" \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema "$SKILL_DIR/output-schema.json" \
  "[Context: This is Claude Fable 5 delegating implementation work as part of a workflow configured by the machine owner. You are the implementer; Fable wrote the contract and will review your diff and re-run the gates afterward.]

Read the contract at: $STATE_DIR/contract.md
Implement it fully. Follow AGENTS.md / CLAUDE.md conventions where present.
Run every gate listed in the contract and fix failures before reporting.
Do NOT commit, stage, branch, or push — leave all changes in the working tree.
Report using the JSON schema." \
  > "$STATE_DIR/exec-round1.jsonl" 2>&1
```

After it exits:

```bash
THREAD_ID=$(grep '"thread_id"' "$STATE_DIR/exec-round1.jsonl" | head -1 | jq -r '.thread_id')
jq . "$STATE_DIR/last-message.json"
```

Persist `$STATE_DIR/state.json` (enables cross-session resume):

```json
{ "repo": "", "branch": "", "thread_id": "", "classification": "delegate",
  "round": 1, "status": "reviewing", "history": [] }
```

## Step 5 — Verify (trust hierarchy: your gate run > Codex's report)

1. Read `last-message.json` (status, deviations, blockers).
2. **Re-run the gates yourself.** Never approve on Codex's claim of green.
3. Review the diff: `git status --short`, then `git diff` (minus baseline if one was
   snapshotted). Check: scope respected (no out-of-scope files changed), invariants hold,
   conventions match, edge cases from the contract actually handled.
4. Large, low-risk, mechanical diffs (renames, codemods, generated code): spot-check a
   sample plus gates instead of a full read — and state that confidence level explicitly
   in the final report. Full read is the default everywhere else.

## Step 6 — Punch-list loop (max 2 rounds)

Corrections must be **mechanical only**: you can state WHAT to change without arguing WHY
an approach is wrong. Missing null check, missing test case, wrong import, naming, an
off-by-one you can point at — mechanical. Wrong abstraction, wrong data flow, misread
invariant — design-level: do not write it into a punch list, escalate (below).

```bash
codex exec resume "$THREAD_ID" --json \
  -o "$STATE_DIR/last-message.json" \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema "$SKILL_DIR/output-schema.json" \
  "[Context: Fable review, correction round <N> of 2.]

PUNCH LIST — mechanical fixes only, apply exactly as written:
1. <file:line> — <precise change>
2. ...

Re-run all gates from the contract. Do NOT commit. Report using the JSON schema." \
  > "$STATE_DIR/exec-round<N>.jsonl" 2>&1
```

Then verify again (Step 5).

## Escalation — hard rules, no exceptions

1. The first design-level correction needed → **abort delegation immediately**. Do not
   spend a round teaching design; by the time the explanation is precise enough, the
   thinking is already done.
2. Not converged after correction round 2 → **abort**. Non-convergence means the task was
   misclassified at triage; say so in the report so triage calibrates.
3. Abort = take over: keep the working tree, salvage the mechanically-sound parts of
   Codex's diff (revert only what is wrong, per file or per hunk), implement the rest
   yourself. Record the miss in `state.json` history.

## Step 7 — Report to the user

Include: classification (and whether forced), what Codex did (its summary + rounds used),
gate results **from your own re-run**, your review verdict with confidence level (full
read vs spot-check), deviations/blockers, and salvage notes if aborted. Everything stays
uncommitted — committing is the user's call.

## Cost discipline (the point of all this)

- The interface is files, not chatter: contract in, diff out. Never stream a Codex
  transcript into context. Read only `last-message.json`, the diff, and gate output.
- Your irreducible cost is the contract plus the diff read. If a task's diff would be
  enormous AND require a full careful read, that is triage information — the savings may
  not exist.
- One `codex exec` round trip per iteration. No conversational back-and-forth.
