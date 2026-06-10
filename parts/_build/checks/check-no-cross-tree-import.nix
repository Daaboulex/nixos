# check-no-cross-tree-import — a module under parts/ must not reach into home/
# (or vice-versa) via a relative `../…` path, and the same for home/→parts/.
# Cross-tree references go through the flake (inputs.self.modules.* or
# ${inputs.self}/…), which survives the tree being moved. The host composition
# roots (parts/hosts/<host>/flake-module.nix) legitimately import the home tree
# and are exempt, as is the build/test infra under parts/_build/.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any cross-tree relative import.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-no-cross-tree-import";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(find parts home -name '*.nix' 2>/dev/null | sort)
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR -- 'parts/' 'home/' | grep -E '\.nix$' || true
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # Exempt: host composition roots (they wire the home tree by design) and
      # the build/test infra (fixtures reference the other tree under test).
      case "$f" in
        parts/hosts/*/flake-module.nix) continue ;;
        parts/_build/*) continue ;;
      esac
      case "$f" in
        parts/*) other="home" ;;
        home/*) other="parts" ;;
        *) continue ;;
      esac
      # A relative path with one or more `../` segments that lands in the OTHER
      # tree. Within-tree `../sibling/` never matches (different leading dir).
      hits=$(grep -nE "\\.\\.(/\\.\\.)*/$other/" "$f" || true)
      if [ -n "$hits" ]; then
        echo "check-no-cross-tree-import: $f"
        echo "$hits"
        echo "  reaches into the $other/ tree by relative path — use inputs.self.modules.* or \"\''${inputs.self}/$other/…\" instead."
        failed=1
      fi
    done
    exit "$failed"
  '';
}
