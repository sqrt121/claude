# claude

Version-controlled Claude Code assets (user-wide, machine: sqrt121).

## Layout

```
skills/            # personal skills, symlinked into ~/.claude/skills/<name>
  codex-delegate/  # Fable-only: delegate work to GPT-5.5 xhigh via Codex CLI
    SKILL.md         # shared core: model gate, triage, plumbing, escalation
    bin/delegate.sh  # mechanical rails: init/exec/append/status, un-adjudicated round blocks next exec
    references/      # per-mode protocol: implement, explore, test, ensemble (decide)
    schemas/         # per-mode strict output schemas for codex exec --output-schema
    playbooks/       # standing task-family playbooks (contract skeletons + reviewer checklists)
claude-home/       # user-global files, each symlinked to ~/.claude/<name>
  CLAUDE.md              # user-global instructions
  statusline-command.sh  # statusline (repo | branch± | model | effort | ctx% + headroom + >200k | ±lines | $ | rate windows ↻ resets)
```

## Install (new machine / after clone)

```bash
./install.sh
```

Symlinks each skill (`~/.claude/skills/<name>` -> `skills/<name>`) and the user-global
CLAUDE.md. Idempotent; refuses to overwrite real (non-symlink) files.

## Editing

Edit files here directly — the `~/.claude` entries are symlinks into this repo, so
changes are live immediately (symlink discovery confirmed working, including mid-session
re-scans). Commit as you go.

## Design notes

The delegation design (contract/brief templates, punch-list economics, bounded
correction rounds, escalation rules, Fable-only gating, thread chaining across modes)
is documented inside `skills/codex-delegate/SKILL.md` and its `references/`.
