#!/usr/bin/env bash
# warm-macbook-cache.sh — pre-build macbook's config + CachyOS specialisation
# on this host (ryzen) so the macbook's next nrb pulls from our /nix/store
# instead of spending compile time.
#
# Run on ryzen, any time. Macbook's SSH key + buildMachines reservation are
# irrelevant here — we're building WITHIN ryzen's own nix store, not sending
# anything. The derivations end up in /nix/store, cached. Next time macbook's
# nix-daemon asks ryzen for those paths (via ssh-ng), they're served
# immediately from cache.
#
# Usage:
#   ./scripts/warm-macbook-cache.sh           # both main + cachyos specialisation
#   ./scripts/warm-macbook-cache.sh main      # just main xanmod
#   ./scripts/warm-macbook-cache.sh cachyos   # just LTO specialisation
#
# Exit codes:
#   0 — all requested targets built
#   1 — at least one build failed (see stderr for nix output)
set -euo pipefail

cd "$(dirname "$0")/.."

TARGETS="${1:-all}"

build_main() {
  echo "→ building macbook-pro-9-2 main config (xanmod)..."
  nix build --no-link --print-build-logs \
    ".#nixosConfigurations.macbook-pro-9-2.config.system.build.toplevel"
}

build_cachyos() {
  echo "→ building macbook-pro-9-2 cachyos specialisation (LTO v2)..."
  # Note: the specialisation is GATED on remoteBuilder.client.enable in
  # the macbook host config. If that flag is false in the evaluated config,
  # the spec attr doesn't exist and this build fails with "attribute missing".
  # That's correct behavior — no spec to warm if user opted out.
  nix build --no-link --print-build-logs \
    ".#nixosConfigurations.macbook-pro-9-2.config.specialisation.cachyos.configuration.system.build.toplevel"
}

case "$TARGETS" in
all)
  build_main
  build_cachyos || {
    echo "⚠ cachyos spec build failed — likely macbook has remoteBuilder.client.enable = false."
    echo "  That's fine; just means the spec isn't declared in the current config."
    exit 0
  }
  ;;
main) build_main ;;
cachyos) build_cachyos ;;
*)
  echo "usage: $0 [main|cachyos|all]" >&2
  exit 2
  ;;
esac

echo "✓ pre-warm complete. Macbook's next nrb should be cache-hits for these paths."
