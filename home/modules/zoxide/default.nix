# zoxide — smart directory jumper (z/zi replacement for cd).
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.zoxide;
in
{
  options.myModules.home.zoxide = {
    enable = lib.mkEnableOption "zoxide smart directory jumper";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;
        options = lib.mkDefault [
          "--cmd"
          "cd"
        ]; # Replace cd with zoxide (cd = z, cdi = zi)
      };
      overrides = cfg.settings;
    };
  };
}
