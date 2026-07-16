#!/usr/bin/env bash
# warm-macbook-cache.sh — pre-build macbook's config on this host (ryzen) so
# the macbook's next nrb pulls from our /nix/store instead of spending compile
# time. Useful before a CachyOS kernel rotation that the v2 overlay rebuilds
# locally — see parts/_build/cachyos-v2.nix.
#
# Run on ryzen, any time. Macbook's SSH key + buildMachines reservation are
# irrelevant here — we're building WITHIN ryzen's own nix store, not sending
# anything. The derivations end up in /nix/store, cached. Next time macbook's
# nix-daemon asks ryzen for those paths (via ssh-ng), they're served
# immediately from cache.
#
# Usage:
#   ./scripts/warm-macbook-cache.sh
#
# Exit codes:
#   0 — build succeeded
#   1 — build failed (see stderr for nix output)
set -euo pipefail

cd "$(dirname "$0")/.."

echo "→ building macbook-pro-9-2 toplevel (cachyos-lto-v2)..."
nix build --no-link --print-build-logs \
  ".#nixosConfigurations.macbook-pro-9-2.config.system.build.toplevel"

echo "✓ pre-warm complete. Macbook's next nrb should be cache-hits for these paths."
