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
          description = "Hugepage backing for VM memory. Domains get memoryBacking.hugepages; allocation is dynamic (per-VM hook) unless bootStatic is set.";
        };
        bootStatic = lib.mkEnableOption "allocate the whole hugepage pool at boot (vm.nr_hugepages) instead of per-VM in the hook. Required for vfio-all: two VMs start in parallel and a single dynamic hook pool can't be sized for both. count must cover the SUM of every autostarted VM's memory";
        count = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = "Number of hugepages to allocate. Dynamic mode: per single VM. bootStatic mode: the SUM across all VMs that run at once (e.g. 2×28 GB of 2M pages = 28672).";
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

      config = lib.mkIf (cfg.enable && cfg.hugepages.enable) (
        lib.mkMerge [
          # Register the 1G hugepage size with the kernel (no-op for 2M, the default size).
          {
            boot.kernelParams = lib.mkIf (cfg.hugepages.size == "1G") [ "hugepagesz=1G" ];
          }

          # Boot-static allocation: reserve the full pool at boot via the kernel param
          # (contiguous memory is plentiful at boot — the only reliable time to get a
          # large pool), then assert it actually materialised before any VM starts.
          (lib.mkIf cfg.hugepages.bootStatic {
            boot.kernelParams =
              if cfg.hugepages.size == "1G" then
                [ "hugepages=${toString cfg.hugepages.count}" ]
              else
                [
                  "hugepagesz=2M"
                  "hugepages=${toString cfg.hugepages.count}"
                ];

            systemd.services.vfio-hugepages-assert = {
              description = "Assert the boot-static hugepage pool was fully allocated";
              before = [ "libvirt-guests.service" ];
              requiredBy = [ "libvirt-guests.service" ];
              after = [ "sysinit.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              # Fail LOUD on the headless host (R7): if the pool didn't materialise,
              # block VM autostart rather than silently fall back to non-huge memory.
              script = ''
                want=${toString cfg.hugepages.count}
                path=${
                  if cfg.hugepages.size == "1G" then
                    "/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"
                  else
                    "/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"
                }
                have=$(cat "$path")
                if [ "$have" -lt "$want" ]; then
                  echo "VFIO boot-static hugepages: only $have/$want allocated — refusing to autostart VMs" >&2
                  exit 1
                fi
              '';
            };
          })
        ]
      );
    };
in
{
  flake.modules.nixos.vfio-hugepages = mod;

}
