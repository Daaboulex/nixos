# mkSessionVars -- set session variables on BOTH the login shell and the systemd
# user environment. A var set only in home.sessionVariables is not seen by
# systemd user services or graphically-launched apps (hm #5542), so IDE-spawned
# build tools and GUI apps miss it. Values must be Nix-resolved absolute strings,
# never a runtime "$VAR": home.sessionVariables emit alphabetically (hm #6027)
# and environment.d(5) expansion differs, so a runtime reference is unsafe across
# the two targets.
#
# Merge with a module's other config via lib.mkMerge:
#   config = lib.mkIf cfg.enable (
#     lib.mkMerge [ { home.packages = [ pkgs.x ]; } (myLib.mkSessionVars vars) ]
#   );
# or alone when the module sets nothing else:
#   config = lib.mkIf cfg.enable (myLib.mkSessionVars vars);
vars: {
  home.sessionVariables = vars;
  systemd.user.sessionVariables = vars;
}
