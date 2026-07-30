# check-no-foreign-config — dendritic-invariant gate (AUDIT.md §19).
#
# Wraps check-no-foreign-config.py. Fails when a module assigns config into
# ANOTHER module's `myModules.*` namespace ("a module owns its whole domain;
# no other module may modify it"). Covers both home/modules and parts. Reads
# (assertions, guarded consumption) are fine — only LHS writes are flagged.
# See the script header for the ownership model and `# foreign-ok:` suppression.
#
# Invocation modes (forwarded):
#   - filenames : check those files.
#   - --all     : scan home/modules + parts under cwd / $FOREIGN_ROOT.
#   - (none)    : scan staged home/modules + parts (pre-commit default).
#
# Exit: 0 clean, 1 on any foreign-namespace write (each printed with the owner,
# the target namespace, and the fix).
{ pkgs }:

pkgs.writeShellApplication {
  name = "check-no-foreign-config";
  runtimeInputs = with pkgs; [
    python313
    git
    coreutils
  ];
  text = ''
    exec python3 ${./check-no-foreign-config.py} "$@"
  '';
}
