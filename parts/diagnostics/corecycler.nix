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
          description = "Whether to load the ryzen_smu kernel module for Curve Optimizer read/write via SMU. Supports Zen 1–5.";
        };
        zenpower = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to use zenpower5 instead of k10temp for AMD CPU monitoring (temps, SVI2 voltage, RAPL power). Replaces k10temp. Zen 1–5.";
        };
        coretemp = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to load the in-tree coretemp module for Intel CPU temperature monitoring.";
        };
        nct6775 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to load the in-tree nct6775 module for Nuvoton Super I/O chips (Vcore, fans, temps). Common on ASUS, MSI, ASRock.";
        };
        it87 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to load the out-of-tree it87 module for ITE Super I/O chips (Vcore, fans, temps). Common on Gigabyte. 38+ chips.";
        };
        cpuid = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to load the in-tree cpuid module for /dev/cpu/*/cpuid access.";
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
            coretemp
            nct6775
            it87
            cpuid
            deviceAccess
            ;
          deviceAccessUser = config.myModules.primaryUser;
        };
      };
    };
}
