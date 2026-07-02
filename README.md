# claude

Version-controlled Claude Code assets (user-wide, machine: sqrt121).

## Layout

```
skills/           # personal skills, symlinked into ~/.claude/skills/<name>
  codex-implement/  # Fable-only: delegate plan-determined implementation to GPT-5.5 xhigh via Codex CLI
```

## Install (new machine / after clone)

```bash
./install.sh
```

Creates one symlink per skill: `~/.claude/skills/<name>` -> `skills/<name>`.
Idempotent; refuses to overwrite a real (non-symlink) directory.

## Editing

Edit files here directly — `~/.claude/skills/*` are symlinks into this repo, so
changes are live immediately. Commit as you go.

## Design notes

The delegation workflow (why contracts, punch-list economics, escalation rules,
Fable-only gating) is documented inside `skills/codex-implement/SKILL.md` itself.
