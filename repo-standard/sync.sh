#!/usr/bin/env bash
set -euo pipefail

# Sync canonical standard files into the repos/*-nix clones.
#
#   repo-standard/sync.sh            # sync all repos
#   repo-standard/sync.sh <repo>...  # sync named repos only
#   repo-standard/sync.sh --check    # report drift, change nothing, exit 1 if any
#
# Each repo commits + pushes its own changes. CI in each repo runs --check
# against its own copy so the per-repo files can never silently drift again.

STD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$STD/.." && pwd)"
cd "$ROOT"

# canonical file in repo-standard/  ->  destination path inside each repo
declare -A FILES=(
  ["update.sh"]="scripts/update.sh"
  ["update.yml"]=".github/workflows/update.yml"
)

CHECK=0
declare -a targets=()
for arg in "$@"; do
  case "$arg" in
  --check) CHECK=1 ;;
  *) targets+=("$arg") ;;
  esac
done
if [ ${#targets[@]} -eq 0 ]; then
  while IFS= read -r d; do targets+=("$(basename "$d")"); done \
    < <(find repos -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
fi

drift=0
for repo in "${targets[@]}"; do
  dir="repos/$repo"
  [ -e "$dir/.git" ] || {
    echo "skip   $repo (not a git clone)"
    continue
  }
  [ -f "$dir/.github/update.json" ] || {
    echo "skip   $repo (no update.json)"
    continue
  }
  # custom-type repos keep their own bespoke scripts/update.sh — sync only
  # the generic workflow into them, never the canonical update.sh.
  rtype=$(jq -r '.upstream.type // "none"' "$dir/.github/update.json" 2>/dev/null || echo none)
  for src in "${!FILES[@]}"; do
    if [ "$src" = "update.sh" ] && [ "$rtype" = "custom" ]; then
      echo "keep   $repo/scripts/update.sh (custom updater)"
      continue
    fi
    dst="$dir/${FILES[$src]}"
    if [ -f "$dst" ] && cmp -s "$STD/$src" "$dst"; then
      continue
    fi
    drift=1
    if [ "$CHECK" -eq 1 ]; then
      echo "DRIFT  $repo/${FILES[$src]}"
    else
      mkdir -p "$(dirname "$dst")"
      cp "$STD/$src" "$dst"
      echo "synced $repo/${FILES[$src]}"
    fi
  done
done

if [ "$CHECK" -eq 1 ]; then
  [ "$drift" -eq 0 ] && {
    echo "all repos in sync with repo-standard/"
    exit 0
  }
  echo "drift detected — run repo-standard/sync.sh to fix"
  exit 1
fi
echo
echo "Done. Review each repo's diff, then commit + push within that repo."
