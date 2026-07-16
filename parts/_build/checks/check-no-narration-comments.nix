# check-no-narration-comments — code is the source of truth; comments state
# constraints the next reader needs, never the history of how the file got here.
# This flags change-narration / AI-session-narration phrases that git already
# records and that go stale the moment the next edit lands. Distinct from
# check-no-dated-comments (ISO dates) — this catches the prose form.
#
# Flagged change-narration (the authoritative list is the `pat=` line below):
# relocation / rename notes, attributions ("as requested", "per the …"),
# session references, "(NEW)" markers, staleness claims, and the leftover task
# markers TODO/FIXME/XXX/HACK. Patterns use a leading word boundary so e.g.
# "removed from nixpkgs" (a real upstream constraint) is NOT a hit.
#
# Deliberate exception: trailing `# narration-ok: <reason>` on the line.
#
# Invocation:
#   - (no args) : scan staged .nix/.sh/.py (pre-commit).
#   - --all     : scan every tracked .nix/.sh/.py (flake check / CI).
#   - FILE...   : scan the given files (tests / manual).
# Exit: 0 clean, 1 on any hit.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-no-narration-comments";
  runtimeInputs = with pkgs; [
    git
    gnugrep
  ];
  text = ''
    # Leading (^|[^a-z]) boundary so "removed from"/"removed to" do not match "moved (from|to)".
    pat='(^|[^a-z])(moved (from|to)|renamed (from|to)|formerly|used to be|as requested|per the (audit|user|review|request)|this session|\(NEW\)|no longer (needed|used|required)|we now|TODO:|FIXME|XXX:| HACK )'

    if [ "$#" -gt 0 ] && [ "$1" != "--all" ]; then
      files=("$@")
    elif [ "''${1:-}" = "--all" ]; then
      mapfile -t files < <(git ls-files '*.nix' '*.sh' '*.py' | grep -vE 'tests/fixtures' || true)
    else
      mapfile -t files < <(
        git diff --cached --name-only --diff-filter=ACMR \
          | grep -E '\.(nix|sh|py)$' | grep -vE 'tests/fixtures' || true
      )
    fi
    [ "''${#files[@]}" -eq 0 ] && exit 0

    failed=0
    for f in "''${files[@]}"; do
      [ -f "$f" ] || continue
      # This gate's own source necessarily spells out every flagged phrase.
      case "$f" in *check-no-narration-comments*) continue ;; esac
      # Only comment lines; honor an inline `# narration-ok` waiver.
      hits=$(grep -niE "#.*$pat" "$f" | grep -viE '# *narration-ok' || true)
      if [ -n "$hits" ]; then
        echo "check-no-narration-comments: $f"
        echo "$hits"
        failed=1
      fi
    done

    if [ "$failed" -ne 0 ]; then
      echo ""
      echo "Change-narration in a comment — git records the history; the comment will"
      echo "go stale. State the current constraint instead, or drop the line. Deliberate"
      echo "keep: append '# narration-ok: <reason>'."
      exit 1
    fi
    exit 0
  '';
}
