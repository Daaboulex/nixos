# check-no-with-lib — forbid `with lib;` (qualify every lib helper instead).
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged .nix · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any hit.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-no-with-lib";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(find parts home lib ci -name '*.nix' 2>/dev/null | sort)
    else
      mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR -- '*.nix')
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # _build is the gate machinery + test fixtures — it contains the very
      # patterns these gates detect, as strings. Exempt (matches the other gates).
      case "$f" in parts/_build/*) continue ;; esac
      if grep -nE '^\s*with\s+lib\s*;' "$f" >/dev/null; then
        echo "VIOLATION ($f): 'with lib;' is forbidden — qualify each lib helper (lib.mkOption, lib.mkIf, …)."
        grep -nE '^\s*with\s+lib\s*;' "$f" | head -3
        failed=1
      fi
    done
    exit "$failed"
  '';
}
