# Motherboard sensor kernel modules — Super I/O chips for voltage, fan, and
# temperature monitoring. These are hardware concerns, not application-specific.
#
# Nuvoton NCT67xx: common on ASUS, MSI, ASRock boards (in-tree)
# ITE IT87xx: common on Gigabyte boards (out-of-tree — in-tree driver lags
#   behind on newer chip IDs like IT8686E, IT8689E)
{ inputs, ... }:
{
  flake.nixosModules.hardware-sensors =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.sensors;
      it87Pkg = pkgs.callPackage ./it87.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";

      options.myModules.hardware.sensors = {
        nct6775 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load the in-tree nct6775 module for Nuvoton Super I/O chips. Provides motherboard Vcore (in0), fan speeds, and temperatures. Common on ASUS, MSI, ASRock boards.";
        };
        it87 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load the out-of-tree it87 module (frankcrawford fork) for ITE Super I/O chips. Provides motherboard Vcore, fan speeds, and temperatures. Common on Gigabyte boards. Supports 38+ chip models.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.nct6775 {
          boot.kernelModules = [ "nct6775" ];
        })
        (lib.mkIf cfg.it87 {
          boot.kernelModules = [ "it87" ];
          boot.extraModulePackages = [ it87Pkg ];
        })
      ];
    };
}
