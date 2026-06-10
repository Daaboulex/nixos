# check-secrets-leak — nothing secret belongs in this public repo. All secret
# material (agenix rules + encrypted *.age) lives in the private `site`
# registry. Blocks any secrets/ path, *.age, and private-key material.
# Single source for the pre-commit hook (staged) and the flake check (--all).
#
# Invocation: (none)=staged adds · --all=whole tree · FILE…=given paths.
# Exit: 0 clean, 1 if any forbidden path is present.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-secrets-leak";
  runtimeInputs = with pkgs; [
    git
    findutils
  ];
  text = ''
    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      # Whole tree, minus the git-ignored repos/ (private inputs, never pushed).
      mapfile -t files < <(find . -type f -not -path './repos/*' -not -path './.git/*' 2>/dev/null)
    else
      mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM)
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0
    failed=0
    for f in "''${files[@]}"; do
      case "$f" in
        ./secrets/* | secrets/* | *.age | *.key | *.pem | *_rsa | *_ed25519 | *_ecdsa)
          echo "BLOCKED: $f — secrets live in the private site registry, not this public repo"
          failed=1
          ;;
      esac
    done
    exit "$failed"
  '';
}
