# Decide mode — blind ensemble for one-way doors

Deliverable: an adjudicated decision on an irreversible call (schema, API contract,
core abstraction, migration semantics), backed by two independent recommendations
produced blind.

When: a "keep"-class one-way door where the answer is genuinely contested and being
wrong is expensive to unwind. Most one-way doors need judgment, not a committee — the
rough gate: would the wrong choice cost a day or more to reverse? If not, just decide.

## Brief template (`$STATE_DIR/brief-decide-<topic>.md`)

```markdown
# Decision brief: <question>
> Repo: <path> | Branch: <branch> | Date: <date>

## The decision
<one question, stated so a recommendation can be unambiguous>

## Hard constraints
<what any answer must satisfy>

## Options already considered
<numbered, with what is known for/against each; add "other" as an allowed answer>

## Evaluation criteria
<weighted — what matters most>

## Context
<everything needed to decide, self-contained; both legs receive exactly this file>
```

## Procedure

1. Write the brief. Both legs get identical, self-contained context; neither may see
   the other's output, this round's chat, or prior thread state.
2. Leg A — Codex, **fresh thread** (never `resume`: independence requires no shared
   context), read-only rules, `--output-schema "$SKILL_DIR/schemas/decide.json"`:

```bash
codex exec --json \
  -o "$STATE_DIR/decide-codex.json" \
  --dangerously-bypass-approvals-and-sandbox \
  --output-schema "$SKILL_DIR/schemas/decide.json" \
  "[Context: independent technical recommendation for a decision brief; another model is answering the same brief blind. Investigate the codebase READ-ONLY as needed.]

Read the brief at: $STATE_DIR/brief-decide.md
Recommend one option. Report using the JSON schema." \
  > "$STATE_DIR/exec-decide-1.jsonl" 2>&1
```

3. Leg B — Opus subagent (Agent tool; user policy: opus or stronger, highest effort),
   the same brief verbatim, asked to end with the same fields: recommendation,
   rationale, risks, rejected alternatives, confidence.
4. Run both in parallel. Adjudicate yourself: agreement is a strong signal but check
   the shared blind spots against the criteria; disagreement is the value — decide
   with stated reasons. Record decision + rationale in the implement contract's
   Implementation notes (or an ADR where the repo keeps them).
5. The ensemble is advisory. You own the decision; never average the recommendations.

## Chaining

The made decision enters the implement contract as a closed decision, never as an open
question. Codex leg A's thread is NOT reused for implementation — start the implement
round per its own reference.
