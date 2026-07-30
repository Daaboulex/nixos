# check-portmaster-chain-ownership — Portmaster's iptables chains are touched
# through lib/mkPortmasterChainKeeper.nix ONLY. A module hand-rolling
# `iptables ... PORTMASTER-...` bypasses the lifecycle keeper (its rule
# silently dies on Portmaster's pause/resume) and re-copies the very pattern
# the helper extracts. Detector: an ip(6)tables invocation and a PORTMASTER-
# chain name on the SAME line — chain names as plain data (a keeper rules
# list) sit on their own lines and pass.
#
# Invocation: (none)=staged .nix · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any hit.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-portmaster-chain-ownership";
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
      # The keeper implements the pattern; _build holds the gate machinery
      # and its fixtures, which spell the pattern as strings. Exempt.
      case "$f" in
        lib/mkPortmasterChainKeeper.nix | parts/_build/*) continue ;;
      esac
      if grep -nE 'ip6?tables.*PORTMASTER-' "$f" >/dev/null; then
        echo "VIOLATION ($f): direct ip(6)tables surgery on a PORTMASTER- chain — use myLib.mkPortmasterChainKeeper (lib/mkPortmasterChainKeeper.nix) so the rule survives Portmaster's pause/resume."
        grep -nE 'ip6?tables.*PORTMASTER-' "$f" | head -3
        failed=1
      fi
    done
    exit "$failed"
  '';
}
