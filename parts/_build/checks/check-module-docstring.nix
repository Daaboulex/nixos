# check-module-docstring — every module >10 lines starts with a one-line
# docstring (`# <name> — <purpose>.`). Exempts lib/, parts/_build/, sensor
# drivers, hardware-configuration.nix, and mkSimplePackage wrappers.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged · --all=whole tree · FILE…=given files.
# Exit: 0 clean, 1 on any module missing its docstring.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-module-docstring";
  runtimeInputs = with pkgs; [
    git
    coreutils
    gnugrep
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(
        find parts home/modules -name '*.nix' 2>/dev/null | sort
      )
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR -- \
          'home/modules/*.nix' 'home/modules/**/*.nix' 'parts/*.nix' 'parts/**/*.nix'
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    warned=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      case "$f" in
        lib/* | parts/_build/*) continue ;;
        parts/sensors/drivers/*) continue ;;
        parts/hosts/*/hardware-configuration.nix) continue ;;
      esac
      if grep -q 'mkSimplePackage' "$f"; then continue; fi
      lines=$(wc -l < "$f")
      [ "$lines" -lt 10 ] && continue
      first=$(grep -m1 -vE '^\s*$' "$f" || true)
      if [ -z "$first" ] || [ "''${first###}" = "$first" ]; then
        echo "VIOLATION ($f): missing module docstring — prepend '# <name> — <one-line purpose>.'"
        warned=1
      fi
    done
    [ "$warned" -ne 0 ] && exit 1
    exit 0
  '';
}
