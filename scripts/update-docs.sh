#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
echo "Generating module documentation..."
result=$(nix-build scripts/generate-docs.nix --no-out-link)
cp -f "$result" docs/OPTIONS.md
echo "Documentation updated at docs/OPTIONS.md ($(wc -l <docs/OPTIONS.md) lines)"
