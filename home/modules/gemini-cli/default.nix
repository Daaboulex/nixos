# gemini-cli — Google Gemini terminal AI assistant with pinned-version selection.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.gemini-cli;
  pkg = pkgs."gemini-cli-${cfg.version}";
in
{
  options.myModules.home.gemini-cli = {
    enable = lib.mkEnableOption "Gemini CLI AI assistant";
    version = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "preview"
        "nightly"
      ];
      default = "stable";
      description = "Which release channel to use";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkg ];
  };
}
