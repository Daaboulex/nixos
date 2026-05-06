# opencode — OpenCode AI coding agent (sst/opencode).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.opencode;
  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    export TMPDIR="''${TMPDIR:-$HOME/.cache/opencode/tmp}"
    mkdir -p "$TMPDIR"
    exec ${pkgs.llm-agents.opencode}/bin/opencode "$@"
  '';
in
{
  options.myModules.home.opencode.enable = lib.mkEnableOption "OpenCode AI coding agent (sst/opencode)";

  config = lib.mkIf cfg.enable {
    home.packages = [ opencodeWrapped ];
  };
}
