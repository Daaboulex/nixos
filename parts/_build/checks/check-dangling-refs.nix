# check-dangling-refs — unguarded cross-module reference gate (AUDIT.md §19).
#
# Wraps check-dangling-refs.py. Flags a home/modules module that names another
# enable-gated module's RUNTIME resource (binary / `.desktop` id) without a
# guard on that provider's `config.myModules.home.<provider>.enable` — a
# reference that breaks at runtime if the provider is disabled. See the script
# header for detection rules, scope, and the `# dangling-ok:` suppression.
#
# Invocation modes (forwarded to the script):
#   - filenames : check those files (tests + manual).
#   - --all     : scan every home/modules/**/*.nix under cwd / $DANGLING_ROOT.
#   - (none)    : scan staged home/modules/**/*.nix (pre-commit default).
#
# Exit: 0 clean, 1 on any unguarded reference (each printed with reason + fix).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-dangling-refs";
  runtimeInputs = with pkgs; [
    python313
    git
    coreutils
  ];
  text = ''
    exec python3 ${./check-dangling-refs.py} "$@"
  '';
}
