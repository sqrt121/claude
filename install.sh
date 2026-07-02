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
