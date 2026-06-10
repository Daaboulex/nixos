# check-no-dated-comments — the comment standard forbids dated change-logs /
# session narration in comments (git carries the history). Flags ISO dates
# (YYYY-MM-DD) in comments of .nix/.sh/.py. Bare-year source citations carry no
# ISO date and pass; stateVersion lines are exempt.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any hit.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-no-dated-comments";
  runtimeInputs = with pkgs; [
    git
    gnugrep
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(
        find parts home lib ci \( -name '*.nix' -o -name '*.sh' -o -name '*.py' \) 2>/dev/null | sort
      )
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(nix|sh|py)$' || true
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # _build = gate machinery + fixtures (which contain dated examples). Exempt.
      case "$f" in parts/_build/*) continue ;; esac
      hits=$(grep -nE '#.*[12][0-9]{3}-[01][0-9]-[0-3][0-9]' "$f" | grep -v 'stateVersion' || true)
      if [ -n "$hits" ]; then
        echo "check-no-dated-comments: $f"
        echo "$hits"
        failed=1
      fi
    done
    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "Dated comment(s) found. The comment standard forbids dated change-logs and"
      echo "session narration — git carries the history. Reword to timeless rationale."
      exit 1
    fi
    exit 0
  '';
}
