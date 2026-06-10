# nixos-exhaustiveness — every host flake-module.nix references every
# parts/**/*.nix NixOS module. Single source for the pre-commit hook
# (git-hooks.nix, staged-gated) and the flake check (tests.nix, --all).
{ pkgs }:

(import ./mkExhaustivenessCheck.nix { inherit pkgs; }) {
  kind = "NixOS";
  name = "nixos-exhaustiveness";
  hostGlob = "parts/hosts/*/flake-module.nix";
  # Every parts/**/*.nix module declares 'flake.modules.nixos.<name> = mod;'.
  # Extract the <name>, excluding _build and host files themselves.
  moduleListCmd = "grep -rhE '^\\s*flake\\.modules\\.nixos\\.[a-zA-Z0-9_-]+' parts --include='*.nix' --exclude-dir=_build --exclude-dir=hosts | sed -E 's/^[[:space:]]*flake\\.modules\\.nixos\\.([a-zA-Z0-9_-]+).*/\\1/' | sort -u";
  expectedPattern = "inputs\\.self\\.modules\\.nixos\\.%s";
  fixHint = "Host flake-module.nix files must reference every NixOS module under parts/. Add the missing inputs.self.modules.nixos.<name> import alphabetically.";
  stagedFilter = "'parts/'";
}
