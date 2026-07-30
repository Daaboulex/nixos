# goxlr — declarative GoXLR/GoXLR Mini mixer configuration (EQ, denoise, routing).
{
  config,
  lib,
  options,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.goxlr;
in
{
  imports = [
    ./eq.nix
    ./denoise.nix
    ./toggle.nix
  ];

  options.myModules.home.goxlr = {
    enable = lib.mkEnableOption "GoXLR declarative mixer configuration";
    isMini = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the GoXLR is a Mini variant (affects PipeWire node names and routing).";
    };
    settings = myLib.mkSettingsOption {
      description = "GoXLR settings merged over module defaults. Set per-host for hardware specifics.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs (options.programs ? goxlr) {
      programs.goxlr = myLib.mergeSettings {
        defaults = {
          enable = true;
          faderMuteBehaviour = {
            a = lib.mkDefault "all";
            b = lib.mkDefault "all";
            c = lib.mkDefault "all";
            d = lib.mkDefault "all";
          };
          coughButton = {
            isHold = lib.mkDefault false;
            muteBehaviour = lib.mkDefault "all";
          };
          bleepVolume = lib.mkDefault 0;
          settings = {
            muteHoldDuration = lib.mkDefault 500;
            samplePreRecordBuffer = lib.mkDefault 0;
            monitorWithFx = lib.mkDefault false;
            deafenOnChatMute = lib.mkDefault true;
            lockFaders = lib.mkDefault false;
          };
          lighting.animation = {
            mode = lib.mkDefault "none";
            mod1 = lib.mkDefault 0;
            mod2 = lib.mkDefault 0;
            waterfall = lib.mkDefault "down";
          };
          submix.enabled = lib.mkDefault false;
        };
        overrides = cfg.settings;
      };
    }
  );
}
