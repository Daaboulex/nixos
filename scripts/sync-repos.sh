#!/usr/bin/env bash
# sync-repos.sh — pull all repos/ subdirectories from their GitHub remotes.
# Use after Syncthing carries working tree changes, or after the other machine
# committed+pushed. Fast-forward only — won't create merge commits.
# Safe to run anytime: skips repos with local changes.

set -euo pipefail

REPOS_DIR="${1:-$(dirname "$(realpath "$0")")/../repos}"

if [[ ! -d $REPOS_DIR ]]; then
  echo "repos dir not found: $REPOS_DIR" >&2
  exit 1
fi

pulled=0
skipped=0
failed=0

for repo in "$REPOS_DIR"/*/; do
  [[ -d "$repo/.git" ]] || continue
  name=$(basename "$repo")

  if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
    echo "SKIP $name (dirty working tree)"
    ((skipped++))
    continue
  fi

  if git -C "$repo" pull --ff-only --quiet 2>/dev/null; then
    echo "  OK $name"
    ((pulled++))
  else
    echo "FAIL $name (not fast-forward or no remote)"
    ((failed++))
  fi
done

echo ""
echo "sync-repos: $pulled pulled, $skipped skipped, $failed failed"
