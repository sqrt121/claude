# Explore mode

Deliverable: cited findings answering numbered questions. Codex burns its own context on
the file reads; you read a two-page report. Best economics of the three modes.

When: map how a subsystem works, find where behavior lives, inventory usages/patterns,
gather facts before a design or an implement contract.

Not for point lookups. "Where is X defined", "which version of Y", "does Z exist" —
answer those yourself with rg/glob in seconds: deterministic, no fidelity risk, no
round trip. Delegate only when the deliverable is synthesis across many reads (map a
subsystem, trace a flow, inventory a pattern). A delegated round trip on a one-grep
question adds a trust surface for nothing.

## Brief template (`$STATE_DIR/brief-explore-<topic>.md`)

```markdown
# Exploration brief: <topic>
> Repo: <path> | Branch: <branch> | Date: <date>

## Questions (numbered; specific; answerable from this codebase)
1. <question>
2. <question>

## Scope hints
<entry points, dirs to focus on or ignore, naming conventions to chase>

## Depth
<overview vs exhaustive; when to stop digging>

## Rules
- READ-ONLY. Do not create, modify, or delete any file. No commits, branches, installs, or builds.
- Every answer must cite evidence as repo-relative file:line. No citation -> mark the finding confidence "unsure".
- Answer the numbered questions in order; put anything else worth knowing in open_questions.
```

## Mode instruction block (goes into the exec prompt)

```
Investigate the codebase READ-ONLY and answer every numbered question in the brief with
repo-relative file:line evidence. Do not create, modify, or delete any file.
```

## Verify

1. `git status --porcelain` must match the baseline exactly. Any new dirt is a protocol
   violation: revert it and apply core Escalation rule 3.
2. Spot-check citations: pick 2-3 load-bearing findings (more if a decision hangs on
   them), open the cited file:line, confirm the claim says what the report says. One
   false citation → distrust the entire report (core rule 3).
3. Treat `confidence: unsure` findings as leads, not facts. Never build a contract on an
   unverified "unsure".

## Correction rounds (max 1)

One follow-up batch of numbered clarifying questions via `codex exec resume` (same flags,
schema `schemas/explore.json`). If answers are still inadequate: either the questions
were unanswerable as written (your miss — rewrite the brief counts as the same round) or
take over the remaining reading yourself.

## Chaining

Findings feed an implement contract naturally — resume the SAME thread for the implement
round; the contract can then reference the explored areas instead of re-specifying them.
