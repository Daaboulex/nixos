# base — VFIO GPU passthrough base (libvirt, qemu, iommu, stealth VM management).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.vfio;
      user = config.myModules.primaryUser;
    in
    {
      _class = "nixos";

      options.myModules.vfio = {
        enable = lib.mkEnableOption "VFIO GPU passthrough with stealth VM management";

        # --- Machine Configuration ---
        machineType = lib.mkOption {
          type = lib.types.str;
          default = "pc-q35-10.0";
          description = "QEMU machine type for VM definitions";
        };

        vmDiskPath = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/vfio";
          description = "Directory for VM disk images and state files";
        };

        # --- Scheduler & Priority Integration ---
        anancyOverride = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Override CachyOS ananicy-cpp rules for QEMU. Default rules classify QEMU as Heavy_CPU (nice=9, ionice=7) which deprioritizes VM performance. This adds custom rules that give QEMU and libvirt high priority instead.";
        };

        restrictScxToHost = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Restrict the scx scheduler to host-only cores while a VM is running. When true, the hook restarts scx_bpfland with --primary-domain set to hostCpuMask (NOT stopped — keeps scheduling benefits on host cores). Restored to full CPU set on VM stop.";
        };
        hostCpuMask = lib.mkOption {
          type = lib.types.str;
          default = "0xffffffff";
          description = "Hex bitmask of host-only CPUs (CCD1 cores). Used to restrict scx scheduler during VM runtime. Example: 0xff00ff00 for cores 8-15 + threads 24-31 on a dual-CCD Zen 5.";
        };
        hostGpuDriver = lib.mkOption {
          type = lib.types.str;
          default = "amdgpu";
          example = "nouveau";
          description = "Host GPU driver used for recovery rebinding when a passthrough device is stuck on vfio-pci from a prior run. Set to 'nouveau' or 'nvidia' for NVIDIA hosts, 'i915' for Intel. Defaults to 'amdgpu'.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # ── Core VFIO kernel setup ──
          {
            boot.kernelModules = [
              "vfio"
              "vfio_iommu_type1"
              "vfio-pci"
            ];

            boot.extraModprobeConfig = ''
              # Prevent NVMe devices from entering D3 power state while claimed by vfio-pci.
              # Without this, Samsung NVMe drives may fail with "Unable to change power
              # state from D0 to D3hot" and disappear from the PCI bus.
              options vfio-pci disable_idle_d3=1

              # Prevent snd_hda_intel from claiming the GPU's HDMI/DP audio function.
              # If snd_hda_intel is holding the dGPU audio controller, it keeps a
              # device reference that blocks clean VFIO unbind — the host GPU driver
              # (amdgpu/nouveau/i915) cannot release the card until audio is released.
              # softdep ensures vfio-pci claims GPU audio before snd_hda_intel.
              softdep snd_hda_intel pre: vfio-pci
            '';

            boot.kernelParams = [
              # video=efifb:off REMOVED — kills iGPU fallback framebuffer during
              # GPU unbind transitions, causing unrecoverable black screens.
              # The iGPU needs its framebuffer for VT console fallback.
              "pcie_aspm=off" # Disable ASPM for passthrough devices (stability)
            ];
          }

          # ── Libvirt + QEMU ──
          {
            virtualisation.libvirtd = {
              enable = true;
              qemu = {
                package =
                  if cfg.stealth.enable then
                    pkgs.qemu-stealth.override {
                      edidManufacturer = cfg.stealth.edid.manufacturer;
                      edidModelAbbrev = cfg.stealth.edid.modelAbbrev;
                      edidModel = cfg.stealth.edid.model;
                      edidSerial = cfg.stealth.edid.serial;
                      edidProductCode = cfg.stealth.edid.productCode;
                      edidDpi = cfg.stealth.edid.dpi;
                      edidWeek = cfg.stealth.edid.week;
                      edidYear = cfg.stealth.edid.year;
                      acpiOemId = cfg.stealth.acpiOem.id;
                      acpiOemTableId = cfg.stealth.acpiOem.tableId;
                      diskModel = cfg.stealth.disk.model;
                      inherit (cfg.stealth.disk) opticalModel;
                    }
                  else
                    pkgs.qemu;
                runAsRoot = true;
                swtpm.enable = true;
                verbatimConfig =
                  let
                    evdevPaths = lib.filter (p: p != null) [
                      cfg.evdev.keyboardPath
                      cfg.evdev.mousePath
                    ];
                    quotedPaths = map (p: ''"${p}"'') evdevPaths;
                    evdevEntries = lib.concatStringsSep ", " quotedPaths;
                  in
                  ''
                    cgroup_device_acl = [
                      "/dev/null", "/dev/full", "/dev/zero",
                      "/dev/random", "/dev/urandom",
                      "/dev/ptmx", "/dev/kvm",
                      "/dev/kvmfr0",
                      "/dev/vfio/vfio"${lib.optionalString (evdevPaths != [ ]) ",\n      ${evdevEntries}"}
                    ]
                  '';
              };
            };

            # User access to libvirt and KVM
            users.users.${user}.extraGroups = [
              "libvirtd"
              "kvm"
              "input"
            ];

            # virt-manager/virt-viewer GUI packages moved to HM modules
            # System-level: auto-connect polkit policy for virt-manager
            programs.virt-manager.enable = true;
            # dconf settings for virt-manager (auto-connect, console settings)
            programs.dconf.enable = true;

            # Default NAT network — ensure it's started and set to autostart
            networking.firewall.trustedInterfaces = [ "virbr0" ];

            systemd.services.libvirt-default-network = {
              description = "Ensure libvirt default NAT network is active";
              after = [ "libvirtd.service" ];
              requires = [ "libvirtd.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true
                ${pkgs.libvirt}/bin/virsh net-autostart default 2>/dev/null || true
              '';
            };

            systemd.services.libvirt-guests.serviceConfig = {
              # Why: libvirt-guests upstream auto-starts/resumes flagged VMs at
              # boot. VFIO passthrough claims the GPU before the user logs in,
              # so an auto-resumed VM would leave the host with no display.
              # Empty + /bin/true disables the start phase without masking the
              # unit.
              ExecStart = lib.mkForce [
                ""
                "${pkgs.coreutils}/bin/true"
              ];
            };
          }

          # ── Ananicy-cpp override: promote QEMU from Heavy_CPU to high priority ──
          (lib.mkIf cfg.anancyOverride {
            services.ananicy.extraRules = [
              # QEMU vCPU threads — high priority for gaming/interactive VMs
              {
                name = "qemu-system-x86_64";
                nice = -5;
                ioclass = "best-effort";
                ionice = 1;
                latency_nice = -7;
              }
              {
                name = "qemu-system-x86";
                nice = -5;
                ioclass = "best-effort";
                ionice = 1;
                latency_nice = -7;
              }
              # Libvirt management — moderate priority (not latency-sensitive)
              {
                name = "libvirtd";
                nice = -2;
                ioclass = "best-effort";
                ionice = 3;
              }
              {
                name = "virtqemud";
                nice = -2;
                ioclass = "best-effort";
                ionice = 3;
              }
              # Looking Glass client — low latency for frame relay display
              {
                name = "looking-glass-client";
                nice = -10;
                ioclass = "best-effort";
                ionice = 0;
                latency_nice = -10;
              }
              # swtpm — TPM emulation, low priority
              {
                name = "swtpm";
                nice = 5;
                ioclass = "best-effort";
                ionice = 5;
              }
            ];
          })

          # ── VM disk directory ──
          {
            systemd.tmpfiles.rules = [
              "d ${cfg.vmDiskPath} 0770 ${user} libvirtd -"
            ];
          }
        ]
      );
    };
in
{
  flake.modules.nixos.vfio-base = mod;

}
