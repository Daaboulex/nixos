# direnv — per-directory environment loader with nix-direnv integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.direnv;
in
{
  options.myModules.home.direnv = {
    enable = lib.mkEnableOption "direnv per-directory environments";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;
        config.global = {
          warn_timeout = lib.mkDefault "30s";
          hide_env_diff = lib.mkDefault true;
        };
      };
      overrides = cfg.settings;
    };
  };
}
