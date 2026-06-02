# check-scrub-tokens — content-scrub gate.
#
# Pre-commit hook reading the canonical token catalog at
# $HOME/.ai-context/scripts/scrub-config.json (separate per-user repo,
# NOT the project submodule). Scans staged diff '+' lines against
# forbidden_tokens + forbidden_patterns, applies allow_in_docs +
# context_allowlist exemptions, exits 0 if config absent (fresh clone).
#
# Invocation modes:
#   - No args: scan `git diff --cached` (pre-commit default).
#   - `--from-file <patch>`: scan a unified-diff file (testability).
#
# Exit: 0 pass, 1 on hit (token + file + line + suggested rewrite from
# scrub-config.json `rewrites` map; falls back to `<token-placeholder>`).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-scrub-tokens";
  runtimeInputs = with pkgs; [
    python313
    git
    coreutils
  ];
  text = ''
    exec python3 ${./check-scrub-tokens.py} "$@"
  '';
}
