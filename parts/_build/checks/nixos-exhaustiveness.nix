# nixos-exhaustiveness — every host flake-module.nix references every
# parts/**/*.nix NixOS module. Single source for the pre-commit hook
# (git-hooks.nix, staged-gated) and the flake check (tests.nix, --all).
# Catches "added a module, forgot to wire it up".
#
# Invocation modes of the generated binary:
#   - (none) : gate on staged files only (pre-commit; exits 0 when nothing
#              under parts/ is staged).
#   - --all  : unconditional scan of the working tree (flake check / CI),
#              where no git index exists.
{ pkgs }:

let
  # Every parts/**/*.nix module declares 'flake.modules.nixos.<name> = mod;'.
  # Extract the <name>, excluding _build and host files themselves.
  moduleListCmd = "grep -rhE '^\\s*flake\\.modules\\.nixos\\.[a-zA-Z0-9_-]+' parts --include='*.nix' --exclude-dir=_build --exclude-dir=hosts | sed -E 's/^[[:space:]]*flake\\.modules\\.nixos\\.([a-zA-Z0-9_-]+).*/\\1/' | sort -u";
in
pkgs.writeShellApplication {
  name = "nixos-exhaustiveness";
  runtimeInputs = with pkgs; [
    git
    findutils
    gnugrep
    coreutils
  ];
  text = ''
    if [ "''${1:-}" != "--all" ]; then
      staged=$(git diff --cached --name-only -- 'parts/')
      [ -z "$staged" ] && exit 0
    fi

    echo "Checking NixOS module exhaustiveness..."
    failed=0

    modules=$(${moduleListCmd})

    # shellcheck disable=SC2066
    for host_cfg in parts/hosts/*/flake-module.nix; do
      hostname=$(basename "$(dirname "$host_cfg")")

      # Extract the per-host exclude list from a magic comment block at
      # the top of the host file:
      #
      #   # exhaustiveness-exclude:
      #   #   gaming-steam gaming-rocksmith
      #   #   vfio-session-gpu vfio-device-binding
      #
      # Comment block ends at the first non-comment or blank line.
      excludes=$(awk '
        /^[[:space:]]*#[[:space:]]*exhaustiveness-exclude:/ { in_block = 1; next }
        in_block {
          if (/^[[:space:]]*#/) {
            # Strip leading "# " and collapse whitespace
            line = $0
            sub(/^[[:space:]]*#[[:space:]]*/, "", line)
            print line
          } else {
            in_block = 0
          }
        }
      ' "$host_cfg" | tr -s '[:space:]' '\n' | grep -v '^$' || true)

      for mod in $modules; do
        # Pipe-free here-string, not `printf | grep -q`: under pipefail a
        # producer SIGPIPE on grep's early-exit match turns the match into a
        # non-zero pipeline (false "missing").
        if grep -qxF "$mod" <<< "$excludes"; then
          continue
        fi
        # Anchored: a prefix module name (nix-nix) must not be satisfied by a
        # longer one (nix-nix-ld).
        expected=$(printf 'inputs\.self\.modules\.nixos\.%s([^a-zA-Z0-9_-]|$)' "$mod")
        if ! grep -qE "$expected" "$host_cfg" 2>/dev/null; then
          echo "MISSING: $hostname is missing $expected"
          failed=1
        fi
      done
    done

    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "Host flake-module.nix files must reference every NixOS module under parts/. Add the missing inputs.self.modules.nixos.<name> import alphabetically."
      exit 1
    fi
    echo "All NixOS host configs are exhaustive."
  '';
}
