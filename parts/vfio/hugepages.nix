# hugepages — hugepage allocation for VM memory (allocated on VM start, freed on stop).
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

      options.myModules.vfio.hugepages = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Hugepage allocation for VM memory (allocated on VM start, freed on VM stop)";
        };
        count = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = "Number of hugepages to allocate";
        };
        size = lib.mkOption {
          type = lib.types.enum [
            "2M"
            "1G"
          ];
          default = "2M";
          description = "Hugepage size (1G = fewer TLB misses, best for gaming VMs)";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.hugepages.enable) {
        # Register the hugepage size with the kernel but don't allocate any at boot.
        # Allocation happens dynamically in the libvirt qemu hook (prepare/begin).
        boot.kernelParams = lib.mkIf (cfg.hugepages.size == "1G") [
          "hugepagesz=1G"
        ];
      };
    };
in
{
  flake.modules.nixos.vfio-hugepages = mod;

}
