# Test mode

Deliverable: verbose test/flow runs with full logs on disk and distilled failures with
pointers into those logs. The value: log volume stays out of your context.

When: run suites at maximum verbosity, reproduce a reported bug, characterize flakiness
(repeat runs), verify a change end-to-end.

## Brief template (`$STATE_DIR/brief-test-<topic>.md`)

```markdown
# Test brief: <topic>
> Repo: <path> | Branch: <branch> | Date: <date>

## Runs (numbered; exact commands with max-verbosity flags)
1. <command> — <purpose>
2. <command> — <purpose>

## Log discipline
- mkdir -p $STATE_DIR/logs. Tee EVERY run: <command> 2>&1 | tee $STATE_DIR/logs/<nn>-<slug>.log
- Per failure report: distilled cause (<=5 lines), minimal repro command, log_ref as
  file:line-range. Never inline long output.
- Browser-driven runs additionally screenshot each run to $STATE_DIR/smoke/<nn>-<slug>.png
  and list the paths in environment_notes.
- Every console error, unexpected warning, or off-script observation goes in the
  anomalies field VERBATIM — even when the run's target assertions passed. Never
  classify anything as expected, noise, or pre-existing; that call is the reviewer's.

## Rules
- You MAY install dependencies and build as required to make the runs executable.
- Do NOT modify source or test files. If a run cannot execute without a code change,
  report that run's failures with kind "setup" / status BLOCKED and the reason.
- Never use snapshot-update or auto-fix flags (e.g. -u, --update-snapshots, --fix).
- Do NOT commit, stage, branch, or push.

## Environment notes to capture
Runtime/package-manager versions, required env vars, suites skipped and why.
```

## Mode instruction block (goes into the exec prompt)

```
Execute every numbered run in the brief with maximum verbosity, tee-ing each run's full
output to its log file under $STATE_DIR/logs/. Distill failures per the brief's log
discipline. Enumerate every console error or unexpected warning verbatim in the
anomalies field — do not classify anything as expected or noise; that judgment is not
yours. Do not modify source or test files; never use snapshot-update or auto-fix
flags. Do NOT commit.
```

## Verify

1. Green is a claim: re-run the single most load-bearing command yourself (or one
   reported failure via its repro) before acting on the report.
2. Attribute every anomaly before approving: reproduce the same page/command on the
   base branch (or production) — an anomaly that is new on this branch is a blocker
   until explained, no matter how benign it reads. An anomaly recurring across many
   runs/pages is systemic; treat it as one finding, not scattered noise. (In the first
   live run the executor filed a systemic hydration-mismatch console error under
   "expected noise"; the schema's anomalies field exists so that judgment never sits
   with the executor again.)
3. Investigate failures by grepping logs selectively (`rg "<test name>"
   $STATE_DIR/logs/`); never cat a whole log into context.
4. `git status --porcelain` vs baseline: runs may produce artifacts (coverage output,
   caches) — but any modified source, test, or snapshot file is a protocol violation:
   revert it and apply core Escalation rule 3.

## Correction rounds (max 1)

One re-run batch via `codex exec resume` (same flags, schema `schemas/test.json`):
different filters, seeds, verbosity, or repeat counts (flake confirmation). More than
that → run the remainder yourself.

## Chaining

Failures feed an implement contract — resume the SAME thread: "you saw the failures in
logs/<nn>-<slug>.log; here is the contract to fix them." After the fix round, a re-test
on the same thread closes the loop.
