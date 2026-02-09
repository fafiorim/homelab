#!/bin/sh
# Install git hooks from scripts/git-hooks/ into .git/hooks/
# Run from repo root. Ensures Co-authored-by: Cursor is never kept in commits.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SRC="$ROOT/scripts/git-hooks"
HOOKS_DST="$ROOT/.git/hooks"
[ -d "$HOOKS_SRC" ] || { echo "Missing $HOOKS_SRC"; exit 1; }
[ -d "$HOOKS_DST" ] || { echo "Missing $HOOKS_DST (not a git repo?)"; exit 1; }
for f in "$HOOKS_SRC"/*; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  cp "$f" "$HOOKS_DST/$name"
  chmod +x "$HOOKS_DST/$name"
  echo "Installed .git/hooks/$name"
done
