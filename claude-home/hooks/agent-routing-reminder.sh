#!/usr/bin/env bash
# PreToolUse[Agent|Task]: non-blocking routing reminder — Claude subagents share
# the Claude-plan token pool with the main session.
# Incident: 2026-07-04 com.zanoboo — Opus fan-out ate the 5h window in ~1.5h.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"User policy reminder: Claude subagents burn the shared Claude token pool and have no standing use case — codex has equivalent MCPs and tools. Route offloadable work to codex-delegate; work needing Fable-grade judgment stays inline. A spawn is an exception: name what codex structurally cannot do here (e.g. a fork inheriting this session's context)."}}
JSON
