#!/usr/bin/env bash
# Symlink versioned Claude Code assets into ~/.claude. Idempotent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.claude/skills"

for skill in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill")"
  target="$HOME/.claude/skills/$name"
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    echo "SKIP $name: $target exists and is not a symlink — resolve manually" >&2
    continue
  fi
  ln -s "${skill%/}" "$target"
  echo "linked $name"
done

# User-global CLAUDE.md
target="$HOME/.claude/CLAUDE.md"
if [ -L "$target" ]; then
  rm "$target"
elif [ -e "$target" ]; then
  echo "SKIP CLAUDE.md: $target exists and is not a symlink — resolve manually" >&2
  exit 0
fi
ln -s "$REPO_DIR/claude-home/CLAUDE.md" "$target"
echo "linked CLAUDE.md"
