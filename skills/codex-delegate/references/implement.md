# Implement mode

Deliverable: a working-tree diff meeting a contract. Codex codes; you review the diff
against hard gates.

## Brief template (`$STATE_DIR/brief-implement-<topic>.md`)

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

Gates are discovered from package.json scripts (typecheck/lint/test/build), Makefile
targets, or commands documented in AGENTS.md / CLAUDE.md / CI config. A repo with no
conventions file AND no discoverable gates is a triage signal — the contract must carry
everything and the savings shrink.

## Mode instruction block (goes into the exec prompt)

```
Implement the contract fully. Follow AGENTS.md / CLAUDE.md conventions where present.
Run every gate listed in the contract and fix failures before reporting.
Do NOT commit, stage, branch, or push — leave all changes in the working tree.
```

## Verify

1. Read the report: status, deviations, blockers. Treat an empty `deviations` array as
   unverified, not as absence — implement rounds under-report design decisions
   (observed repeatedly in live runs); the diff review is where deviations are actually
   found, even on green gates.
2. **Re-run the gates yourself.** Never approve on Codex's claim of green.
3. Review the diff: `git status --short`, then `git diff` (minus baseline if one was
   snapshotted). Check: scope respected (no out-of-scope files changed), invariants
   hold, conventions match, edge cases from the contract actually handled.
4. Large, low-risk, mechanical diffs (renames, codemods, generated code): spot-check a
   sample plus gates instead of a full read — and state that confidence level explicitly
   in the final report. Full read is the default everywhere else.

## Correction rounds (max 2)

Punch lists are **mechanical only**: you can state WHAT to change without arguing WHY an
approach is wrong. Missing null check, missing test case, wrong import, naming, an
off-by-one you can point at — mechanical. Wrong abstraction, wrong data flow, misread
invariant — design-level: escalate per the core rules (abort, salvage per file or per
hunk, implement the rest yourself).

```bash
codex exec resume "$THREAD_ID" --json \
  -o "$STATE_DIR/last-message-<topic>.json" \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema "$SKILL_DIR/schemas/implement.json" \
  "[Context: Fable review, correction round <N> of 2.]

PUNCH LIST — mechanical fixes only, apply exactly as written:
1. <file:line> — <precise change>
2. ...

Re-run all gates from the contract. Do NOT commit. Report using the JSON schema." \
  > "$STATE_DIR/exec-implement-<topic>-<N+1>.jsonl" 2>&1
```

## Chaining

After an explore round on the same thread, the contract may reference "the areas you
explored" instead of re-specifying them. After implement, a test round on the same
thread already knows what was built.
