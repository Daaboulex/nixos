# pulsemixer — PipeWire/PulseAudio TUI mixer with theme integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.pulsemixer;
  inherit (myLib.themeCtx { inherit config; }) hasTheme;
in
{
  options.myModules.home.pulsemixer = {
    enable = lib.mkEnableOption "pulsemixer PipeWire/PulseAudio TUI mixer";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to pulsemixer.cfg.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      pulsemixer
    ];

    # Full-color mode (colors come from terminal palette = Breeze Dark)
    xdg.configFile."pulsemixer.cfg" = lib.mkIf hasTheme {
      text = ''
        [ui]
        color = 2
        mouse = yes
      ''
      + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";
    };
  };
}
