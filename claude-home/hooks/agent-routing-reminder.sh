#!/usr/bin/env bash
# PreToolUse[Agent|Task]: non-blocking routing reminder — Claude subagents share
# the Claude-plan token pool with the main session.
# Incident: 2026-07-04 com.zanoboo — Opus fan-out ate the 5h window in ~1.5h.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"User policy reminder: Claude subagents burn the shared Claude token pool. Offloadable work routes to codex-delegate first; spawn a Claude subagent only for harness-bound work or true parallelism, and state why codex is not doing it."}}
JSON
