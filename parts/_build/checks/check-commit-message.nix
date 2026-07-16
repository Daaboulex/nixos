# check-commit-message -- commit-msg gate: every commit subject reads
# type(scope): description and the message carries an Eval: trailer
# (gate-green | <suite>=<result> | n/a), so the ledger the change digest
# renders from git log stays systematic. Types mirror the repo's own
# vocabulary; git-generated subjects (Merge/Revert, fixup!/squash!) pass
# untouched. Argument: the commit-msg file.
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-commit-message";
  runtimeInputs = with pkgs; [
    gawk
    gnugrep
    coreutils
  ];
  text = ''
    msgfile="''${1:?usage: check-commit-message <commit-msg-file>}"

    # Git comment lines and the verbose-commit scissors section are not
    # part of the message.
    msg=$(awk '/^# -+ >8 -+/ { exit } !/^#/ { print }' "$msgfile")
    subject=$(head -n 1 <<< "$msg")

    case "$subject" in
      "Merge "* | "Revert "* | "fixup! "* | "squash! "*) exit 0 ;;
    esac

    status=0
    if ! grep -qE '^(feat|fix|chore|test|docs|refactor|perf|build|ci)\([a-z0-9-]+\): [^ ]' <<< "$subject"; then
      {
        echo "commit-msg: subject must read type(scope): description"
        echo "  types: feat fix chore test docs refactor perf build ci -- scope: kebab-case"
        echo "  got: $subject"
      } >&2
      status=1
    fi

    if ! grep -qE '^Eval: (gate-green|n/a|[a-z0-9][A-Za-z0-9._/^-]*=[^ ].*)$' <<< "$msg"; then
      {
        echo "commit-msg: missing or malformed Eval: trailer"
        echo "  one of: 'Eval: gate-green' | 'Eval: <suite>=<result>' | 'Eval: n/a'"
      } >&2
      status=1
    fi

    exit "$status"
  '';
}
