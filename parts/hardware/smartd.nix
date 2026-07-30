# smartd — SMART disk health monitoring with scheduled attribute checks.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.hardware.smartd;
    in
    {
      _class = "nixos";
      options.myModules.hardware.smartd = {
        enable = lib.mkEnableOption "smartd disk health monitoring (DEVICESCAN over SATA + NVMe; failures land in the journal and wall)";
      };

      config = lib.mkIf cfg.enable {
        services.smartd = {
          enable = true;
          # DEVICESCAN: monitor every SMART-capable disk without naming
          # devices, so a swapped or added drive is covered automatically.
          autodetect = true;
          # Desktop notifications via systembus-notify -- a SMART failure
          # must reach the session, not only the journal. Also co-defines
          # services.systembus-notify.enable = true, agreeing with earlyoom
          # (plain false here would conflict on hosts running both).
          notifications.systembus-notify.enable = true;
        };
      };
    };
in
{
  flake.modules.nixos.hardware-smartd = mod;

}
