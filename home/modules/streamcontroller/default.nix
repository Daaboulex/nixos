# streamcontroller — declarative Stream Deck page/key configuration via StreamController.
{
  config,
  lib,
  options,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.streamcontroller;
in
{
  options.myModules.home.streamcontroller = {
    enable = lib.mkEnableOption "StreamController Stream Deck page/key configuration";
    settings = myLib.mkSettingsOption {
      description = "StreamController settings merged over module defaults. Set per-host for hardware specifics.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs (options.programs ? streamcontroller) {
      home.packages = [ config.programs.streamcontroller.package ];
      programs.streamcontroller = {
        enable = true;
      }
      // cfg.settings;
    }
  );
}
