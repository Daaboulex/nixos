# device-binding — VFIO PCI binding strategy (static vfio-pci.ids vs dynamic libvirt hooks).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.vfio;
    in
    {
      _class = "nixos";

      options.myModules.vfio = {
        bindMethod = lib.mkOption {
          type = lib.types.enum [
            "static"
            "dynamic"
          ];
          default = "dynamic";
          description = "static = vfio-pci.ids kernel param (GPU always captured at boot); dynamic = libvirt hooks bind/unbind on VM start/stop";
        };

        # PCI vendor:device IDs for static VFIO binding (only needed when bindMethod = static)
        # Dynamic binding uses PCI addresses from per-VM gpu config instead
        staticPciIds = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "PCI vendor:device IDs for static vfio-pci binding (e.g. [\"1002:7550\" \"1002:ab40\"])";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # Static binding: vfio-pci captures devices at boot
          (lib.mkIf (cfg.bindMethod == "static" && cfg.staticPciIds != [ ]) {
            boot.kernelParams = [
              "vfio-pci.ids=${lib.concatStringsSep "," cfg.staticPciIds}"
            ];
          })
        ]
      );
    };
in
{
  flake.modules.nixos.vfio-device-binding = mod;

}
