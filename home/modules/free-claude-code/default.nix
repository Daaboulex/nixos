# free-claude-code — Anthropic-compatible local proxy with the fclaudec Claude Code launcher.
{
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.home.free-claude-code;
in
{
  options.myModules.home.free-claude-code = {
    enable = lib.mkEnableOption "free-claude-code proxy and fclaudec launcher";
  };

  config = lib.mkIf cfg.enable {
    services.free-claude-code.enable = true;
  };
}
