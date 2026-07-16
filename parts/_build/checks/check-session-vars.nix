# check-session-vars — home modules must route session variables through
# myLib.mkSessionVars (which writes BOTH home.sessionVariables and
# systemd.user.sessionVariables), never a raw assignment to either -- otherwise a
# var silently misses the systemd/GUI environment (hm #5542). A justified
# exception (e.g. a value using runtime ${XDG_RUNTIME_DIR}, which the login shell
# and environment.d(5) expand differently) is marked with `# session-vars-ok:
# <reason>` on the assignment line or the comment block just above it.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged - --all=whole home/modules tree - FILE... =given files.
# Exit: 0 clean, 1 on any raw session-variable assignment.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-session-vars";
  runtimeInputs = with pkgs; [
    git
    gawk
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(find home/modules -name '*.nix' 2>/dev/null | sort)
    else
      mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR -- 'home/modules/*.nix' 'home/modules/**/*.nix')
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # lib/ holds the helper itself; hosts are the final authority; _build is
      # gate machinery + fixtures. All exempt.
      case "$f" in
        lib/* | */hosts/* | parts/_build/*) continue ;;
      esac
      # A raw assignment is a line starting with home.sessionVariables or
      # systemd.user.sessionVariables. `# session-vars-ok` on that line or in the
      # comment block directly above it justifies the exception (gamescope).
      missing=$(awk '
        /^[[:space:]]*#/ {
          if ($0 ~ /# *session-vars-ok/) pending_ok = 1
          next
        }
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*(home\.sessionVariables|systemd\.user\.sessionVariables)/ {
          if ($0 ~ /# *session-vars-ok/) { pending_ok = 0; next }
          if (pending_ok) { pending_ok = 0; next }
          printf "  %d: %s\n", NR, $0
          next
        }
        { pending_ok = 0 }
      ' "$f")
      if [ -n "$missing" ]; then
        echo "VIOLATION ($f): raw session-variable assignment -- use myLib.mkSessionVars (sets home + systemd.user), or justify with '# session-vars-ok: <reason>':"
        echo "$missing"
        failed=1
      fi
    done
    exit "$failed"
  '';
}
