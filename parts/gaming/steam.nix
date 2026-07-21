# steam — Steam with steam-devices udev rules and protontricks; the Proton tool set lives in gaming/proton.
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
        enable = lib.mkEnableOption "Steam with steam-devices and protontricks";
        gamescope = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Gamescope session for Steam";
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
