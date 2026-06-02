# upower — UPower battery and power monitoring daemon.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.hardware.upower;
    in
    {
      _class = "nixos";
      options.myModules.hardware.upower = {
        enable = lib.mkEnableOption "UPower (battery/power monitoring)";
      };

      config = lib.mkIf cfg.enable {
        services.upower.enable = true;
      };
    };
in
{
  flake.modules.nixos.hardware-upower = mod;

}
