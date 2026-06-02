# steam — Steam with steam-devices udev rules (Proton managed via ProtonUp-Qt/ProtonPlus).
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
        enable = lib.mkEnableOption "Steam with steam-devices (Proton via ProtonPlus)";
        gamescope = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Gamescope session for Steam";
        };
      };
      config = lib.mkIf cfg.enable {
        programs.steam = {
          enable = true;
          gamescopeSession.enable = cfg.gamescope && (config.myModules.gaming.gamescope.enable or false);

        };
        hardware.steam-hardware.enable = true;
        environment.systemPackages = [ pkgs.steam-devices-udev-rules ];
      };
    };
in
{
  flake.modules.nixos.gaming-steam = mod;

}
