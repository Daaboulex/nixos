#!/usr/bin/env bash
set -e
echo "Updating documentation..."
nix-build scripts/generate-docs.nix -o docs/OPTIONS.md
echo "Documentation updated at docs/OPTIONS.md"
