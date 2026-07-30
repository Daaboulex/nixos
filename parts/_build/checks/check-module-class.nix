# check-module-class — every parts NixOS module export (flake.modules.nixos.X)
# declares `_class = "nixos"` in its mod lambda, so a direct import (not via the
# modules-hierarchy _class wrapper) can never be silently accepted as the wrong
# class. Exempts parts/_build/ (gate + test infra) and parts/flake-module.nix
# (the aggregator). Single source for the pre-commit hook (staged) and the
# flake check (--all).
#
# Invocation: (none)=staged - --all=whole tree - FILE...=given files.
# Exit: 0 clean, 1 on any module export missing `_class = "nixos"`.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-module-class";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(find parts -name '*.nix' 2>/dev/null | sort)
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR | grep -E '^parts/.*\.nix$' || true
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      case "$f" in
        parts/_build/* | parts/flake-module.nix) continue ;;
      esac
      # Only files that export a NixOS module.
      grep -q 'flake\.modules\.nixos\.' "$f" || continue
      if ! grep -q '_class = "nixos"' "$f"; then
        echo "VIOLATION ($f): module export missing '_class = \"nixos\";' in its mod lambda."
        failed=1
      fi
    done
    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "Every parts NixOS module must declare _class = \"nixos\" so a direct import"
      echo "(not through the modules-hierarchy _class wrapper) is never silently miscast."
      exit 1
    fi
    exit 0
  '';
}
