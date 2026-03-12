#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "Generating module documentation..."
result=$(nix-build scripts/generate-docs.nix --no-out-link)
cp -f "$result" docs/OPTIONS.md
echo "  OPTIONS.md updated ($(wc -l <docs/OPTIONS.md) lines)"

echo "Generating NixOS host template..."
result=$(nix-build scripts/generate-host-template.nix --no-out-link)
cp -f "$result" docs/host-template.nix.example
echo "  host-template.nix.example updated ($(wc -l <docs/host-template.nix.example) lines)"

echo "Generating Home Manager host template..."
result=$(nix-build scripts/generate-hm-template.nix --no-out-link)
cp -f "$result" docs/hm-host-template.nix.example
echo "  hm-host-template.nix.example updated ($(wc -l <docs/hm-host-template.nix.example) lines)"

echo "All documentation updated."
