# coolercontrol — CoolerControl fan and cooling device management daemon.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.hardware.coolercontrol;
    in
    {
      _class = "nixos";

      options.myModules.hardware.coolercontrol = {
        enable = lib.mkEnableOption "CoolerControl fan and cooling device management";
      };

      config = lib.mkIf cfg.enable {
        programs.coolercontrol.enable = true;
      };
    };
in
{
  flake.modules.nixos.hardware-coolercontrol = mod;
}
