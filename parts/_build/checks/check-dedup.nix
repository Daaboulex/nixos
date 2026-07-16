# check-dedup — copy-paste backstop to the structural single-source discipline.
#
# Wraps check-dedup.py. Flags module-level near-duplicate LOGIC blocks (>= 50
# aligned tokens) that should be extracted into a shared helper / _lib. Hosts and
# test fixtures are exempt (their repetition is the deliberate granular manifest),
# and idiomatic boilerplate / the per-tool manifest is suppressed by construction
# (its token sequences occur in too many files to seed). Suppress a reviewed,
# deliberate near-duplicate with a `# dedup-ok` comment in the block.
#
# Invocation (forwarded to the script):
#   - (none)  : scan tracked *.nix, exit 1 on any block (pre-commit default).
#   - --audit : same scan, verbose, always exit 0 (one-off audit / tuning).
#   - FILE... : restrict to these files (manual use / tests).
#
# Exit: 0 clean, 1 on any near-duplicate block (printed as A:lines <-> B:lines).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-dedup";
  runtimeInputs = with pkgs; [
    python313
    git
  ];
  text = ''
    exec python3 ${./check-dedup.py} "$@"
  '';
}
