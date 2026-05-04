# geoclue — GeoClue2 location service for automatic timezone and night-light.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.services.geoclue;
    in
    {
      _class = "nixos";
      options.myModules.services.geoclue = {
        enable = lib.mkEnableOption "GeoClue2 location service";
      };

      config = lib.mkIf cfg.enable {
        services.geoclue2 = {
          enable = true;
          enableWifi = false;
          submitData = false;
        };
      };
    };
in
{
  flake.modules.nixos.services-geoclue = mod;

}
