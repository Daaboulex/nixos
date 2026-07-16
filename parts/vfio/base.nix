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

        passthrough.enable = lib.mkEnableOption "the GPU-passthrough machinery (static vfio-pci capture, pcie_aspm=off, root QEMU). OFF in the normal profile — libvirtd stays up for emulated VMs; the VFIO specialisations force it on. IOMMU + the host-wide stealth kernel patch are independent and stay on regardless";

        perVmStealthSerials = lib.mkEnableOption "name-derived per-VM SMBIOS system + baseboard serials instead of the shared host serials. OFF when only one VM runs at a time (the faithful host serial is correct). ON for vfio-both, which runs both VMs at once where identical board/BIOS serials are a fidelity tell. An eval assertion requires it when >1 co-running VM is enabled under stealth";

        autostart = lib.mkEnableOption "autostart every enabled VM at boot (NixVirt active=true + libvirt autostart flag) and let libvirt-guests gracefully ACPI-shut them on host poweroff. OFF for interactive profiles (VMs are started by hand after login). ON for vfio-both, the thin headless host that boots straight into both guests. OFF for vfio-dynamic, which starts its one VM by hand after login";

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
        ananicyOverride = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Override CachyOS ananicy-cpp rules for QEMU. Default rules classify QEMU as Heavy_CPU (nice=9, ionice=7) which deprioritizes VM performance. This adds custom rules that give QEMU and libvirt high priority instead.";
        };

        cpuPin = {
          dynamic = lib.mkEnableOption "confining host tasks to the cores a VM does NOT use at RUNTIME (cgroup AllowedCPUs on system.slice/user.slice/init.scope) while the VM runs, restoring all cores on stop -- instead of boot-time isolcpus. The host keeps every core when no VM runs. Trade-off: no nohz_full/rcu_nocbs/managed_irq boot tuning, so VM frametimes are slightly worse than full boot isolation. Built for one passthrough VM at a time -- the prepare hook refuses to start a second dynamic-pinned VM while one runs. The profile must NOT also set isolcpus (this replaces it; combining them double-restricts the host). Emulator/IO-thread cores are shared with the host, not VM-exclusive";
          threads = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Host total hardware threads (e.g. 32 for a 16c/32t Zen 5). Required when cpuPin.dynamic is set -- the host-core set confined while a VM runs is [0..threads-1] minus that VM's vcpu.pinning. 0 = unset.";
          };
        };

        acsOverride = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "downstream,multifunction";
          description = ''
            Value for the `pcie_acs_override=` kernel parameter. CachyOS/zen
            kernels carry the patch; mainline does NOT (the param is silently
            ignored there). Splits IOMMU groups that the chipset bundles
            together, so a device sharing a group with others (e.g. a
            chipset-attached NVMe grouped with the onboard NICs) can be passed
            on its own.

            SECURITY WARNING: this FAKES PCIe ACS isolation — a passed-through
            device's DMA can reach the OTHER devices in the same PHYSICAL group
            unmediated by the IOMMU (CPU/RAM isolation via AMD-V/NPT is NOT
            affected). Only set this when the device cannot be physically moved
            to a clean group, and keep nothing sensitive on any host-data
            device left in the faked-split group. Verify after reboot:
            `dmesg | grep "Overriding ACS"`.
          '';
        };

        protectedDiskAddrs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "0000:04:00.0" ];
          description = "PCI addresses of host-critical disks (root/boot/nix/home/swap). An eval-time assertion refuses any VM that lists one in pciPassthrough — a typo-catcher complementing the runtime protectedDiskGuard (which resolves live findmnt and survives a BDF renumber). GPUs use vfio-pci.ids; disks are passed by address, so this is the disk safety net.";
        };

        criticalMounts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/"
            "/boot"
            "/nix"
            "/nix/store"
            "/home"
          ];
          description = "Host mount points whose backing block devices the runtime protectedDiskGuard refuses to pass through (swap is always checked too). Default = the FHS-critical set; a host with a different layout overrides it — keeps the guard generic, with no mount paths baked into the module.";
        };

        ovmf.package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.ovmf-stealth.fd;
          defaultText = lib.literalExpression "pkgs.ovmf-stealth.fd";
          description = "OVMF firmware for UEFI guests. Its FV/ dir must carry OVMF_CODE.ms.fd + the Microsoft-keys-enrolled OVMF_VARS.ms.fd, used as the Secure-Boot loader + nvram template (so the guest boots with SB on at first boot — a Win11 requirement). Defaults to the stealth OVMF (the SB-capable variant); a host may point this at a different OVMF build (e.g. pkgs.OVMFFull.ms for vanilla, un-stealthed SB OVMF).";
        };
        ovmf.secureBoot = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable SMM + secure pflash for SecureBoot enforcement. Injects -machine smm=on and the cfi.pflash01 secure property into every UEFI guest. Required for SecureBoot to function (NixVirt cannot express <smm/> or <loader secure='yes'/> natively).";
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

            # video=efifb:off is deliberately NOT set — the iGPU framebuffer is the
            # console / LUKS-passphrase fallback during early boot.
            boot.kernelParams =
              # ASPM off only under passthrough (device stability); a needless idle-power
              # + latency cost in the normal profile, so gated on passthrough.enable.
              lib.optional cfg.passthrough.enable "pcie_aspm=off"
              ++ lib.optional (cfg.acsOverride != null) "pcie_acs_override=${cfg.acsOverride}";
          }

          # ── No sleep under passthrough ──
          # A passed-through GPU on vfio-pci + DMA-locked hugepages cannot survive a host
          # sleep/resume — resume hangs the host and the running guests die. Hard-block every
          # path: mask the sleep targets (nothing can start them) and tell logind to ignore
          # the idle/key triggers so it never even tries. All gated on passthrough (off in normal).
          (lib.mkIf cfg.passthrough.enable {
            systemd.targets = {
              sleep.enable = false;
              suspend.enable = false;
              hibernate.enable = false;
              hybrid-sleep.enable = false;
              suspend-then-hibernate.enable = false;
            };
            services.logind.settings.Login = {
              IdleAction = "ignore";
              HandleSuspendKey = "ignore";
              HandleHibernateKey = "ignore";
            };
          })

          # ── Libvirt + QEMU ──
          {
            virtualisation.libvirtd = {
              enable = true;
              qemu = {
                package =
                  if cfg.stealth.enable then
                    pkgs.qemu-stealth.override {
                      edidManufacturer = cfg.stealth.edid.manufacturer;
                      edidSerial = cfg.stealth.edid.serial;
                      edidProductCode = cfg.stealth.edid.productCode;
                      edidDpi = cfg.stealth.edid.dpi;
                      edidWeek = cfg.stealth.edid.week;
                      edidYear = cfg.stealth.edid.year;
                      acpiOemId = cfg.stealth.acpiOem.id;
                      acpiOemTableId = cfg.stealth.acpiOem.tableId;
                      diskModel = cfg.stealth.disk.model;
                      diskSerial = cfg.stealth.disk.serial;
                      inherit (cfg.stealth.disk) opticalModel;
                    }
                  else
                    pkgs.qemu;
                # Root QEMU only for passthrough (PCI detach / hugepages); emulated
                # VMs in the normal profile run unprivileged.
                runAsRoot = cfg.passthrough.enable;
                swtpm = {
                  enable = true;
                  # Why: the module closure carries a second equal-priority
                  # definition of swtpm.package (it surfaces inside the VFIO
                  # specialisations as "defined multiple times"); mkForce makes
                  # the stealth-aware choice win instead of conflicting.
                  package = lib.mkForce (
                    if cfg.stealth.enable && cfg.stealth.tpm.harden then
                      pkgs.swtpm.override {
                        libtpms = pkgs.libtpms.overrideAttrs (old: {
                          postPatch = (old.postPatch or "") + config.myModules.vfio.stealth._libtpmsIdentityPatch;
                        });
                      }
                    else
                      pkgs.swtpm
                  );
                };
                verbatimConfig =
                  let
                    # Gate on evdev.enable so a disabled feature leaves no
                    # residue: vms.nix already gates the -object input-linux
                    # args on enable, so without this the cgroup ACL would still
                    # whitelist the device nodes under e.g. the vfio-both
                    # specialisation (evdev.enable = mkForce false).
                    evdevPaths = lib.optionals cfg.evdev.enable (
                      lib.filter (p: p != null) [
                        cfg.evdev.keyboardPath
                        cfg.evdev.mousePath
                      ]
                      ++ cfg.evdev.extraKeyboardPaths
                    );
                    quotedPaths = map (p: ''"${p}"'') evdevPaths;
                    evdevEntries = lib.concatStringsSep ", " quotedPaths;
                  in
                  ''
                    cgroup_device_acl = [
                      "/dev/null", "/dev/full", "/dev/zero",
                      "/dev/random", "/dev/urandom",
                      "/dev/ptmx", "/dev/kvm",
                      "/dev/vfio/vfio"${lib.optionalString cfg.kvmfr.enable ",\n      \"/dev/kvmfr0\""}${
                        lib.optionalString (evdevPaths != [ ]) ",\n      ${evdevEntries}"
                      }
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

            # virt-manager/virt-viewer GUI packages live in HM modules
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

            systemd.services.libvirt-guests.serviceConfig = lib.mkIf (!cfg.autostart) {
              # Why: libvirt-guests upstream auto-starts/resumes flagged VMs at boot.
              # In the single-VM profiles the user starts the VM by hand AFTER login
              # (passthrough claims the dGPU before login, so an auto-resumed VM in a
              # profile that renders on a passed GPU would be wrong) → neuter the start
              # phase (empty + /bin/true) without masking the unit, so ExecStop still
              # runs the graceful ACPI shutdown on host poweroff. Under autostart
              # (vfio-both) the unit's normal lifecycle is kept (see the block below).
              ExecStart = lib.mkForce [
                ""
                "${pkgs.coreutils}/bin/true"
              ];
            };
          }

          # ── Autostart power model (vfio-both) ──
          # The unit's normal lifecycle is kept: ON_BOOT=ignore (the per-domain
          # autostart flag + NixVirt active=true do the starting), ON_SHUTDOWN=shutdown
          # gives a parallel ACPI-first poweroff of both guests on host shutdown.
          (lib.mkIf cfg.autostart {
            virtualisation.libvirtd = {
              onBoot = "ignore";
              onShutdown = "shutdown";
              parallelShutdown = 2;
            };
          })

          # ── Ananicy-cpp override: promote QEMU from Heavy_CPU to high priority ──
          (lib.mkIf cfg.ananicyOverride {
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
