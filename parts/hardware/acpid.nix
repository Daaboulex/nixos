# acpid — ACPI event daemon for power button, lid, and hotkey handling.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.hardware.acpid;
    in
    {
      _class = "nixos";
      options.myModules.hardware.acpid = {
        enable = lib.mkEnableOption "ACPI event daemon";
      };

      config = lib.mkIf cfg.enable {
        services.acpid.enable = true;
      };
    };
in
{
  flake.modules.nixos.hardware-acpid = mod;

}
