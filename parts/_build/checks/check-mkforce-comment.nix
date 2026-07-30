# check-mkforce-comment — every `lib.mkForce` needs a `# Why:` rationale on the
# same line or in the comment block just above it. Host files (parts/hosts/*,
# home/hosts/*) are the final authority and are exempt.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any unjustified mkForce.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-mkforce-comment";
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
      # Host files are the final authority; _build is gate machinery + fixtures
      # (which contain bare mkForce examples). Both exempt.
      case "$f" in
        parts/hosts/* | home/hosts/* | parts/_build/*) continue ;;
      esac
      # "Why:" covers every mkForce that follows it before the next non-comment,
      # non-blank, non-mkForce line.
      missing=$(awk '
        /^[[:space:]]*#/ {
          if ($0 ~ /# *Why:/) pending_why = 1
          next
        }
        /^[[:space:]]*$/ { next }
        /lib\.mkForce/ {
          if ($0 ~ /# *Why:/) { pending_why = 0; next }
          if (pending_why) next
          printf "  %d: %s\n", NR, $0
          next
        }
        { pending_why = 0 }
      ' "$f")
      if [ -n "$missing" ]; then
        echo "VIOLATION ($f): lib.mkForce without adjacent '# Why:' comment:"
        echo "$missing"
        failed=1
      fi
    done
    exit "$failed"
  '';
}
