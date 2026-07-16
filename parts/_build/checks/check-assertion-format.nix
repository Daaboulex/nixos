# check-assertion-format — every assertion's message must name its option,
# starting with "myModules.<path>:". Single source for the pre-commit hook
# (staged) and the flake check (--all).
#
# Invocation: (none)=staged · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any assertion message missing the myModules.* prefix.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-assertion-format";
  runtimeInputs = with pkgs; [
    git
    gawk
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
      # _build = gate machinery + fixtures (which contain bad-assertion examples). Exempt.
      case "$f" in parts/_build/*) continue ;; esac
      bad=$(awk '
        /^[[:space:]]+assertion[[:space:]]*=/ { want_msg=1; line_num=NR }
        want_msg && /^[[:space:]]+message[[:space:]]*=/ {
          want_msg=0
          buf = $0
          for (i=1; i<=4 && getline nl > 0; i++) buf = buf " " nl
          if (buf !~ /myModules\./) {
            printf "  %d: assertion message does not start with myModules.*\n", line_num
          }
        }
      ' "$f")
      if [ -n "$bad" ]; then
        echo "VIOLATION ($f): assertion message must start with 'myModules.<path>:':"
        echo "$bad"
        failed=1
      fi
    done
    exit "$failed"
  '';
}
