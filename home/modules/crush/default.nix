# crush — Crush AI coding agent (charmbracelet) with --data-dir wrapper.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.crush;
  crushWrapped = pkgs.writeShellScriptBin "crush" ''
    exec ${pkgs.llm-agents.crush}/bin/crush --data-dir "$HOME/.local/share/crush" "$@"
  '';
in
{
  options.myModules.home.crush.enable = lib.mkEnableOption "Crush AI coding agent (charmbracelet)";

  config = lib.mkIf cfg.enable {
    home.packages = [ crushWrapped ];
  };
}
