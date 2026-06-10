# check-helper-naming — a .nix file sitting DIRECTLY under parts/<domain>/ is
# either a flake-parts module (declares `flake.modules.*`) or a domain-private
# helper (`_`-prefixed). Anything else is an un-categorised file that erodes the
# convention — name it `_foo.nix` (private helper) or make it a real module.
#
# Out of scope (by construction, not flagged):
#   - parts/<domain>/<subdir>/*.nix  — callPackage derivation sets (sensors/
#     drivers, host specialisations); deeper than one level.
#   - parts/_build/*, parts/hosts/*  — build infra and host composition roots.
#   - parts/*.nix (host.nix, users.nix, flake-module.nix) — documented flat
#     top-level files; this gate only governs the domain level.
#
# Invocation:
#   - (no args) : staged parts/<domain>/*.nix (pre-commit).
#   - --all     : every parts/<domain>/*.nix in the tree (flake check / CI).
#   - FILE...   : the given files (tests / manual).
# Exit: 0 clean, 1 on any un-categorised file.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-helper-naming";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    coreutils
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(find parts -mindepth 2 -maxdepth 2 -name '*.nix' | sort)
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR -- 'parts/' \
          | grep -E '^parts/[^/]+/[^/]+\.nix$' || true
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0

    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # Only the domain level: parts/<domain>/<file>.nix, nothing deeper.
      case "$f" in
        parts/*/*/*) continue ;;
        parts/*/*.nix) ;;
        *) continue ;;
      esac
      dom=$(basename "$(dirname "$f")")
      base=$(basename "$f")
      case "$dom" in _* | hosts) continue ;; esac
      case "$base" in _*.nix) continue ;; esac
      if grep -qE '^[[:space:]]*flake\.modules\.' "$f"; then
        continue
      fi
      echo "check-helper-naming: $f"
      echo "  not a module (declares no flake.modules.*) and not '_'-prefixed."
      echo "  fix: rename to parts/$dom/_$base (domain-private helper), or make it a"
      echo "       module that declares flake.modules.nixos.<name>."
      failed=1
    done
    exit "$failed"
  '';
}
