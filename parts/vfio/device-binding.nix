# device-binding — how passed GPUs reach vfio-pci.
#
#   static  — vfio-pci captures the GPU at BOOT (vfio-pci.ids + initrd modules),
#             before any host driver. Domain hostdevs are managed='no'; libvirt
#             only verifies the device is already on vfio-pci. Bulletproof for a
#             GPU dedicated to passthrough in a dedicated boot entry: no unbind
#             race, no runtime PCI reset, no host-driver release dance.
#   dynamic — no boot capture; libvirt/hook handles binding at VM start/stop.
#
# NVMe/USB are NOT bound here — they are passed by address with managed='yes'
# (libvirt detaches them on start). NVMe especially MUST NOT use vfio-pci.ids:
# the two 9100 PROs share 144d:a810 with the host root disk.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.vfio;
      inherit
        (import ./_lib.nix {
          inherit
            lib
            config
            cfg
            pkgs
            myLib
            ;
        })
        mkStaticPciIds
        ;
      # Ids to capture: explicit staticPciIds plus those derived from the enabled
      # passthrough VMs' gpu.staticIds (single source — declare per VM, capture
      # automatically).
      staticIds = lib.unique (cfg.staticPciIds ++ mkStaticPciIds cfg.vms);
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
          description = "static = vfio-pci captures the GPU at boot (vfio-pci.ids + initrd); dynamic = libvirt/hook binds at VM start/stop. VFIO specialisations use static.";
        };

        # Extra vendor:device IDs to capture beyond those derived from the VMs.
        # Per-VM gpu.staticIds is the preferred source; this is an escape hatch.
        staticPciIds = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "1002:7550"
            "1002:ab40"
          ];
          description = "Additional GPU vendor:device IDs for static vfio-pci binding (merged with the per-VM gpu.staticIds of enabled VMs). GPUs only — never NVMe (shared 144d:a810).";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.bindMethod == "static" && staticIds != [ ]) {
        boot.kernelParams = [ "vfio-pci.ids=${lib.concatStringsSep "," staticIds}" ];
        # Pin vfio into the initramfs so capture is deterministic before any host
        # GPU driver (amdgpu for the iGPU, etc.) — the belt-and-suspenders form
        # the ArchWiki recommends when the host modesets a GPU driver.
        boot.initrd.kernelModules = [
          "vfio_pci"
          "vfio"
          "vfio_iommu_type1"
        ];
      };
    };
in
{
  flake.modules.nixos.vfio-device-binding = mod;

}
