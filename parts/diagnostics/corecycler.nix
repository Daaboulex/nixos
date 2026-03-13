# Thin wrapper around the upstream CoreCyclerLx NixOS module.
# Maps myModules.diagnostics.corecycler options to services.corecyclerlx.
{ inputs, ... }:
{
  flake.nixosModules.diagnostics-corecycler =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.diagnostics.corecycler;
    in
    {
      _class = "nixos";

      imports = [ inputs.linux-corecycler.nixosModules.default ];

      options.myModules.diagnostics.corecycler = {
        enable = lib.mkEnableOption "CoreCyclerLx per-core CPU stability tester and PBO Curve Optimizer tuner";
        unfreeBackends = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to include unfree backends (mprime). When false, only FOSS backends (stress-ng) are bundled.";
        };
        ryzenSmu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to load the ryzen_smu kernel module for Curve Optimizer read/write via SMU";
        };
        zenpower = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to use zenpower5 instead of k10temp for Vcore/Vsoc voltage monitoring via SVI2. Replaces k10temp (blacklisted).";
        };
        deviceAccess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to grant primaryUser access to MSR devices and SMU sysfs via a dedicated group and udev rules. No sudo required.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.corecyclerlx = {
          enable = true;
          inherit (cfg)
            unfreeBackends
            ryzenSmu
            zenpower
            deviceAccess
            ;
          deviceAccessUser = config.myModules.primaryUser;
        };
      };
    };
}
