# pi — Pi AI agent CLI (earendil-works).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.pi;
in
{
  options.myModules.home.pi.enable = lib.mkEnableOption "Pi AI agent CLI (earendil-works)";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.llm-agents.pi ];
  };
}
