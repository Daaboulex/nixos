# steam — Steam with steam-devices udev rules; declarative GE-Proton floor + protontricks, extra Proton versions via ProtonPlus.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.gaming.steam;
    in
    {
      _class = "nixos";
      options.myModules.gaming.steam = {
        enable = lib.mkEnableOption "Steam with steam-devices (declarative GE-Proton floor; extra Protons via ProtonPlus)";
        gamescope = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Gamescope session for Steam";
        };
        protonGE = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Declarative GE-Proton (nixpkgs proton-ge-bin) in Steam's compatibility tool list";
        };
        protontricks = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "protontricks for winetricks verbs in Proton game prefixes";
        };
      };
      config = lib.mkIf cfg.enable {
        programs.steam = {
          enable = true;
          gamescopeSession.enable = cfg.gamescope && (config.myModules.gaming.gamescope.enable or false);
          extraCompatPackages = lib.optional cfg.protonGE pkgs.proton-ge-bin;
          protontricks.enable = cfg.protontricks;
        };
        hardware.steam-hardware.enable = true;
        environment.systemPackages = [ pkgs.steam-devices-udev-rules ];
      };
    };
in
{
  flake.modules.nixos.gaming-steam = mod;

}
