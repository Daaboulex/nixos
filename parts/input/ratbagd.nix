# ratbagd — Piper mouse configuration tool and ratbagd service for programmable mice.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.input.ratbagd;
    in
    {
      _class = "nixos";
      options.myModules.input.ratbagd.enable =
        lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";

      config = lib.mkIf cfg.enable {
        services.ratbagd.enable = true;
      };
    };
in
{
  flake.modules.nixos.input-ratbagd = mod;

}
