# vms — per-VM NixVirt definitions with GPU passthrough and libvirt hook generation.
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

      # All shared VFIO logic lives in the single private ./_lib.nix — one
      # implementation + one style for every concern; this file stays focused on
      # hook + domain generation.
      helpers = import ./_lib.nix {
        inherit
          lib
          config
          cfg
          pkgs
          ;
      };
      inherit (helpers)
        parsePciAddr
        isValidPciAddr
        generateMac
        perVmSmbios
        enabledVms
        disabledVms
        gpuAddrsOf
        hugepageSysfsPath
        protectedDiskGuard
        mkProtectedDiskAssertions
        usbIdHex
        ;

      mkVmHookSection =
        name: vmCfg:
        let
          pciAddrs = vmCfg.pciPassthrough;
          mounts = vmCfg.mountsToUnmount;
          # GPUs are captured by vfio-pci at boot (static binding) — the hook
          # never touches them. It only handles host-side concerns: the disk
          # safety guard, unmounting the passed NVMe, hugepages, and scx. The
          # guard still loops the GPU addrs too as cheap defence (a mistyped GPU
          # address that actually backs a host disk is caught).
          guardAddrList = lib.concatStringsSep " " (gpuAddrsOf vmCfg ++ pciAddrs);
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            # ── Phase 1 — validate (no mutations, safe to abort) ──
            # SAFETY: refuse to pass any device backing a host-critical filesystem.
            for pci_addr in ${guardAddrList}; do
              if vfio_guard_protected_disk "$pci_addr"; then exit 1; fi
            done
            ${lib.optionalString (mounts != [ ]) ''
              # Abort BEFORE mutating if files are open on a mount we must unmount.
              mount_blocked=""
              ${lib.concatMapStringsSep "\n" (mp: ''
                if ${pkgs.util-linux}/bin/findmnt -n "${mp}" >/dev/null 2>&1; then
                  open_files=$(${pkgs.psmisc}/bin/fuser -mv "${mp}" 2>&1 || true)
                  real_procs=$(echo "$open_files" | grep -v "^$" | grep -v "COMMAND" | grep -v "kernel" || true)
                  if [ -n "$real_procs" ]; then
                    mount_blocked="$mount_blocked\n  ${mp}:\n$real_procs"
                  fi
                fi
              '') mounts}
              if [ -n "$mount_blocked" ]; then
                log "[$GUEST_NAME] ABORT: files are open on mount points that need unmounting"
                echo -e "$mount_blocked" | while read -r line; do
                  [ -n "$line" ] && log "[$GUEST_NAME]   $line"
                done
                log "[$GUEST_NAME] Close all files/apps using these paths, then try again"
                exit 1
              fi
            ''}

            # ── Phase 2 — mutate (trap reverses on failure) ──
            _vfio_cleanup() {
              log "[$GUEST_NAME] CLEANUP: prepare hook failed, reversing mutations..."
              ${lib.optionalString (cfg.hugepages.enable && !cfg.hugepages.bootStatic) ''
                echo 0 > ${hugepageSysfsPath} 2>/dev/null || true
              ''}
              ${lib.optionalString (mounts != [ ]) ''
                ${lib.concatMapStringsSep "\n" (
                  mp: ''${pkgs.util-linux}/bin/mount "${mp}" 2>/dev/null || true''
                ) mounts}
              ''}
              ${lib.optionalString cfg.restrictScxToHost ''
                ${pkgs.systemd}/bin/systemctl unset-environment SCX_FLAGS_OVERRIDE 2>/dev/null || true
                ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
              ''}
            }
            trap _vfio_cleanup EXIT

            ${lib.optionalString (cfg.hugepages.enable && !cfg.hugepages.bootStatic) ''
              # Allocate hugepages for VM memory (dynamic profiles only; bootStatic
              # profiles like vfio-all reserve the whole pool at boot — a single hook
              # pool can't be sized for two parallel VMs).
              log "[$GUEST_NAME] allocating ${toString cfg.hugepages.count} × ${cfg.hugepages.size} hugepages"
              echo 3 > /proc/sys/vm/drop_caches
              echo 1 > /proc/sys/vm/compact_memory
              sleep 1
              echo ${toString cfg.hugepages.count} > ${hugepageSysfsPath}
              allocated=$(cat ${hugepageSysfsPath})
              if [ "$allocated" -lt "${toString cfg.hugepages.count}" ]; then
                log "[$GUEST_NAME] ABORT: only allocated $allocated/${toString cfg.hugepages.count} hugepages (not enough contiguous memory)"
                exit 1
              fi
              log "[$GUEST_NAME] hugepages allocated: $allocated × ${cfg.hugepages.size}"
            ''}
            ${lib.optionalString cfg.restrictScxToHost ''
              # Restrict scx to host-only cores while the VM owns its CCD.
              if ${pkgs.systemd}/bin/systemctl is-active scx.service >/dev/null 2>&1; then
                log "[$GUEST_NAME] restricting scx scheduler to host cores (mask ${cfg.hostCpuMask})"
                ${pkgs.systemd}/bin/systemctl set-environment SCX_FLAGS_OVERRIDE="-m ${cfg.hostCpuMask}" 2>/dev/null || true
                ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
              fi
            ''}
            ${lib.optionalString (mounts != [ ] || pciAddrs != [ ]) ''
              # Unmount host filesystems on the passed NVMe before libvirt detaches
              # it (libvirt cannot detach a PCI device whose block devices are mounted).
              ${pkgs.coreutils}/bin/sync
              ${lib.concatMapStringsSep "\n" (mp: ''
                if ${pkgs.util-linux}/bin/findmnt -n "${mp}" >/dev/null 2>&1; then
                  log "[$GUEST_NAME] unmounting ${mp}"
                  ${pkgs.util-linux}/bin/umount "${mp}" || {
                    log "[$GUEST_NAME] ABORT: failed to unmount ${mp} — files may still be open"
                    exit 1
                  }
                fi
              '') mounts}
              # Safety net: unmount any remaining partitions on the passed NVMe(s).
              for pci_addr in ${lib.concatStringsSep " " pciAddrs}; do
                for nvme_dev in /sys/bus/pci/devices/"$pci_addr"/nvme/nvme*/nvme*n*; do
                  if [ -e "$nvme_dev" ]; then
                    blk_dev="/dev/$(basename "$nvme_dev")"
                    log "[$GUEST_NAME] scanning $blk_dev for remaining mounts"
                    for part in ''${blk_dev}p*; do
                      if ${pkgs.util-linux}/bin/findmnt -n "$part" >/dev/null 2>&1; then
                        log "[$GUEST_NAME] unmounting $part"
                        ${pkgs.util-linux}/bin/umount "$part" || {
                          log "[$GUEST_NAME] WARNING: failed to unmount $part"
                        }
                      fi
                    done
                  fi
                done
              done
            ''}

            # Success — disarm cleanup trap.
            trap - EXIT
          fi
        '';

      mkVmReleaseSection =
        name: vmCfg:
        let
          mounts = vmCfg.mountsToUnmount;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            : # no-op: keeps the block valid when nothing needs restoring (bootStatic + no mounts + no scx)
            ${lib.optionalString cfg.restrictScxToHost ''
              log "[$GUEST_NAME] restoring scx scheduler to all cores"
              ${pkgs.systemd}/bin/systemctl unset-environment SCX_FLAGS_OVERRIDE 2>/dev/null || true
              ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
            ''}
            ${lib.optionalString (mounts != [ ]) ''
              # Remount host filesystems after the VM releases the NVMe.
              sleep 1
              ${lib.concatMapStringsSep "\n" (mp: ''
                log "[$GUEST_NAME] remounting ${mp}"
                ${pkgs.util-linux}/bin/mount "${mp}" 2>/dev/null || {
                  log "[$GUEST_NAME] WARNING: failed to remount ${mp} — run 'mount -a' manually"
                }
              '') mounts}
            ''}
            ${lib.optionalString (cfg.hugepages.enable && !cfg.hugepages.bootStatic) ''
              log "[$GUEST_NAME] freeing hugepages"
              echo 0 > ${hugepageSysfsPath}
            ''}
          fi
        '';

      vfioHookScript = pkgs.writeShellApplication {
        name = "qemu-hook";
        # libvirt runs this hook with a restricted PATH, so bundle every runtime
        # dep — the body uses bare grep/sort/readlink/cat/basename (not only the
        # explicit ${pkgs.X}/bin/Y pins), which must never depend on ambient PATH.
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.util-linux
          pkgs.psmisc
          pkgs.systemd
        ];
        # SC2043: single-iteration loop — PCI addr count is host-dependent at Nix eval time
        # SC2231: glob quoting style in `${blk_dev}p*` — intentional word-split on block devs
        excludeShellChecks = [
          "SC2043"
          "SC2231"
        ];
        text = ''
          GUEST_NAME="$1"
          HOOK_NAME="$2"
          STATE_NAME="$3"

          # Log helper — all output goes to systemd journal: journalctl -t vfio-hook
          log() {
            echo "VFIO-HOOK: $*" | ${pkgs.util-linux}/bin/logger -t vfio-hook
          }

          # Disk-safety guard (refuses passthrough of host-critical disks).
          ${protectedDiskGuard}

          if [ "$HOOK_NAME" = "prepare" ] && [ "$STATE_NAME" = "begin" ]; then
            log "[$GUEST_NAME] prepare/begin"
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmHookSection enabledVms)}
          fi

          if [ "$HOOK_NAME" = "release" ] && [ "$STATE_NAME" = "end" ]; then
            log "[$GUEST_NAME] release/end"
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmReleaseSection enabledVms)}
          fi
        '';
      };

      # Smart USB re-attach helper: libvirt does NOT auto-reattach a usbPassthrough device
      # that is unplugged + replugged while the domain runs (RedHat RFE #508645). This
      # re-attaches the device to its running VM on hot-plug (invoked async by the udev rule
      # below). $1=domain $2=idVendor(hex) $3=idProduct(hex).
      usbReattachScript = pkgs.writeShellApplication {
        name = "vfio-usb-reattach";
        runtimeInputs = [
          pkgs.libvirt
          pkgs.coreutils
          pkgs.util-linux
        ];
        text = ''
          vm="$1"
          vid="$2"
          pid="$3"
          state="$(virsh domstate "$vm" 2>/dev/null || true)"
          [ "$state" = "running" ] || exit 0
          sleep 1
          printf '<hostdev mode="subsystem" type="usb"><source><vendor id="0x%s"/><product id="0x%s"/></source></hostdev>' "$vid" "$pid" \
            | virsh attach-device "$vm" /dev/stdin --live >/dev/null 2>&1 || true
          logger -t vfio-usb-reattach "[$vm] ensured 0x$vid:0x$pid attached after USB hotplug"
        '';
      };

      # Per-VM submodule type
      vmSubmodule = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to define this VM";
          };
          uuid = lib.mkOption {
            type = lib.types.str;
            description = "Libvirt domain UUID (generate with `uuidgen`)";
          };
          memory = {
            count = lib.mkOption {
              type = lib.types.int;
              default = 16;
              description = "RAM allocation in GiB";
            };
          };
          vcpu = {
            count = lib.mkOption {
              type = lib.types.int;
              default = 16;
              description = "Number of virtual CPUs";
            };
            pinning = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.int);
              default = null;
              description = "List of host CPU cores to pin vCPUs to (null = no pinning)";
            };
            emulatorPin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "8-9";
              description = "Host cores for QEMU emulator threads (e.g. \"8-9\"). Should be on a different CCD than the VM's vCPU cores to avoid contention. null = no pinning.";
            };
            iothreadPin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "10";
              description = "Host core for IO thread (e.g. \"10\"). Should be on the host CCD, not the VM's vCPU CCD. null = no pinning.";
            };
          };
          os = {
            firmware = lib.mkOption {
              type = lib.types.enum [
                "uefi"
                "bios"
              ];
              default = "uefi";
              description = "Firmware type";
            };
            tpm = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Emulated TPM 2.0 via swtpm";
            };
          };
          disk = {
            path = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to qcow2/raw disk image (null = no virtual disk, use PCI passthrough instead)";
            };
            format = lib.mkOption {
              type = lib.types.enum [
                "qcow2"
                "raw"
              ];
              default = "raw";
              description = "Disk image format (raw for best performance)";
            };
            bus = lib.mkOption {
              type = lib.types.enum [
                "virtio"
                "sata"
                "scsi"
              ];
              default = "virtio";
              description = "Disk bus type";
            };
          };
          iso = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to install ISO (null = no CD-ROM)";
          };
          gpu = {
            mode = lib.mkOption {
              type = lib.types.enum [
                "passthrough"
                "emulated"
              ];
              default = "passthrough";
              description = "GPU mode: passthrough = dGPU via VFIO (production); emulated = QXL/SPICE in virt-manager (testing)";
            };
            pciAddress = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "GPU PCI address (e.g. '0000:03:00.0')";
            };
            audioAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "GPU audio function PCI address (e.g. '0000:03:00.1')";
            };
            romFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to GPU VBIOS ROM file (null = no ROM override)";
            };
            extraFunctions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Additional PCI functions in the GPU's IOMMU group (USB, USB-C controllers for multi-function GPUs like NVIDIA). Unbound/rebound alongside VGA + Audio by the hook.";
              example = [
                "0000:05:00.2"
                "0000:05:00.3"
              ];
            };
            staticIds = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "GPU vendor:device IDs captured at boot via vfio-pci.ids when this VM is enabled under bindMethod=static (e.g. [\"10de:21c4\" \"10de:1aeb\"]). GPUs only — NVMe shares 144d:a810 with the host root disk and must be passed by address (managed='yes'), never by id.";
              example = [
                "1002:7550"
                "1002:ab40"
              ];
            };
          };
          network = {
            type = lib.mkOption {
              type = lib.types.enum [
                "nat"
                "bridge"
              ];
              default = "nat";
              description = "Network type";
            };
            bridge = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Bridge name (required if type = bridge)";
            };
            mac = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "MAC address (null = auto-generated from stealth prefix + VM name)";
            };
          };
          pciPassthrough = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional PCI addresses to pass through (e.g. NVMe controllers, USB controllers)";
            example = [
              "0000:05:00.0"
            ];
          };
          usbPassthrough = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  vendorId = lib.mkOption {
                    type = lib.types.int;
                    description = "USB vendor ID as hex int literal (e.g. 0x0b05). NixVirt schema requires int, not string.";
                  };
                  productId = lib.mkOption {
                    type = lib.types.int;
                    description = "USB product ID as hex int literal (e.g. 0x1b7c). NixVirt schema requires int, not string.";
                  };
                };
              }
            );
            default = [ ];
            description = "USB devices to pass through by vendor:product ID. Devices are hotplugged — no need to unbind from host driver.";
            example = [
              {
                vendorId = 2821; # 0x0b05
                productId = 7036; # 0x1b7c
              }
            ];
          };
          mountsToUnmount = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Mount points to unmount before PCI passthrough and remount after VM stop. The hook also discovers mounts from sysfs as a safety net, but this ensures specific paths like '/mnt/Windows SSD' are handled explicitly.";
            example = [ "/mnt/Windows SSD" ];
          };
          # CPU identity spoofing (per-VM — different VMs on different CCDs can spoof different CPUs)
          cpuIdentity = {
            modelId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CPUID brand string override (null = use real host CPU name). E.g. 'AMD Ryzen 7 9850X3D 8-Core Processor' for CCD0 V-Cache, 'AMD Ryzen 7 9700X 8-Core Processor' for CCD1";
              example = "AMD Ryzen 7 9850X3D 8-Core Processor";
            };
            maxSpeed = lib.mkOption {
              type = lib.types.int;
              default = 5600;
              description = "SMBIOS Type 4 max speed in MHz (boost clock of spoofed CPU)";
            };
            currentSpeed = lib.mkOption {
              type = lib.types.int;
              default = 4700;
              description = "SMBIOS Type 4 current speed in MHz (base clock of spoofed CPU)";
            };
          };
          # Per-VM SMBIOS cache (Type 7) sizes in KB. Per-VM because different CCDs
          # carry different L3: CCD0 = 96 MB V-Cache (98304), CCD1 = 32 MB (32768).
          # null = fall back to the host-wide myModules.vfio.stealth.smbios.cache.
          cache = {
            l1 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "L1 cache KB (null = host-wide stealth.smbios.cache.l1).";
            };
            l2 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "L2 cache KB (null = host-wide stealth.smbios.cache.l2).";
            };
            l3 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              example = 32768;
              description = "L3 cache KB (null = host-wide). 98304 for CCD0 V-Cache, 32768 for CCD1 (no V-Cache).";
            };
          };
          hypervMode = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "enlightened"
                "hidden"
              ]
            );
            default = null;
            description = "Per-VM Hyper-V enlightenment mode (null = inherit myModules.vfio.stealth.hypervMode).";
          };
          extraQemuArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra QEMU command-line arguments";
          };
        };
      };

      # Build NixVirt domain definition for a VM
      mkDomainDef =
        name: vmCfg:
        let
          # Stealth VM XML attributes from vfio-stealth repo. mkStealthFeatures
          # takes a prebuilt `smbiosTables` derivation (SMBIOS types
          # 7/8/9/11/17/26/27/28/29 as binary `-smbios file=` tables); build it
          # from the host's real cache topology so Win32_CacheMemory isn't an
          # empty-VM tell. (Replaces the old `cache` arg of mkStealthFeatures.)
          # Per-VM unique system + baseboard serials when perVmStealthSerials is
          # set (vfio-all, two VMs at once); otherwise the faithful host serials.
          smbios =
            if cfg.perVmStealthSerials then perVmSmbios cfg.stealth.smbios name else cfg.stealth.smbios;

          stealth = inputs.vfio-stealth.lib.mkStealthFeatures {
            inherit smbios;
            acpiTables = pkgs.acpi-ssdt-stealth;
            vmUuid = vmCfg.uuid;
            inherit (cfg.stealth) aperfMperf stripVirtio hypervVendorId;
            inherit (cfg.stealth) acpiSsdt;
            hypervMode = if vmCfg.hypervMode != null then vmCfg.hypervMode else cfg.stealth.hypervMode;
            smbiosTables = pkgs.smbios-stealth-tables.override {
              # Per-VM cache (CCD-specific L3) overrides the host-wide default when set.
              cacheL1 = if vmCfg.cache.l1 != null then vmCfg.cache.l1 else cfg.stealth.smbios.cache.l1;
              cacheL2 = if vmCfg.cache.l2 != null then vmCfg.cache.l2 else cfg.stealth.smbios.cache.l2;
              cacheL3 = if vmCfg.cache.l3 != null then vmCfg.cache.l3 else cfg.stealth.smbios.cache.l3;
            };
          };

          mac =
            if vmCfg.network.mac != null then
              vmCfg.network.mac
            else if cfg.stealth.spoofMac then
              generateMac cfg.stealth.macPrefix name
            else
              null;

          cpuPinning =
            if vmCfg.vcpu.pinning != null then
              {
                vcpupin = lib.imap0 (i: core: {
                  vcpu = i;
                  cpuset = toString core;
                }) vmCfg.vcpu.pinning;
              }
              // lib.optionalAttrs (vmCfg.vcpu.emulatorPin != null) {
                emulatorpin.cpuset = vmCfg.vcpu.emulatorPin;
              }
              // lib.optionalAttrs (vmCfg.vcpu.iothreadPin != null) {
                iothreadpin = [
                  {
                    iothread = 1;
                    cpuset = vmCfg.vcpu.iothreadPin;
                  }
                ];
              }
            else
              null;

          gpuHostdevs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [
              {
                mode = "subsystem";
                type = "pci";
                managed = false;
                source.address = parsePciAddr vmCfg.gpu.pciAddress;
                rom = {
                  bar = true;
                }
                // lib.optionalAttrs (vmCfg.gpu.romFile != null) { file = vmCfg.gpu.romFile; };
              }
            ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [
              {
                mode = "subsystem";
                type = "pci";
                managed = false;
                source.address = parsePciAddr vmCfg.gpu.audioAddress;
              }
            ]
            ++ lib.map (addr: {
              mode = "subsystem";
              type = "pci";
              managed = false;
              source.address = parsePciAddr addr;
            }) vmCfg.gpu.extraFunctions
          );

          # Extra PCI passthrough devices (NVMe, USB controllers, etc.)
          extraPciHostdevs = lib.map (addr: {
            mode = "subsystem";
            type = "pci";
            managed = true;
            source.address = parsePciAddr addr;
          }) vmCfg.pciPassthrough;
        in
        {
          type = "kvm";
          inherit name;
          inherit (vmCfg) uuid;

          memory = {
            inherit (vmCfg.memory) count;
            unit = "GiB";
          };
          currentMemory = {
            inherit (vmCfg.memory) count;
            unit = "GiB";
          };

          vcpu = {
            placement = "static";
            inherit (vmCfg.vcpu) count;
          };

          cputune = cpuPinning;
          iothreads.count = 1;

          # SMBIOS injection via sysinfo (stealth)
          sysinfo = if cfg.stealth.enable then stealth.sysinfo else null;

          os = {
            type = "hvm";
            arch = "x86_64";
            machine = cfg.machineType;
            smbios.mode = if cfg.stealth.enable then "sysinfo" else null;
            boot = [ { dev = "hd"; } ] ++ lib.optionals (vmCfg.iso != null) [ { dev = "cdrom"; } ];
          }
          // lib.optionalAttrs (vmCfg.os.firmware == "uefi") {
            # Explicit Secure Boot firmware: secboot OVMF code + a Microsoft-keys-enrolled
            # vars template, so the guest boots with SB ON at first boot (Win11 requires it).
            # Per-VM nvram; the prune's --keep-nvram preserves the enrolled vars across
            # profile switches. SMM (which write-protects the secboot varstore) is not
            # expressible in this NixVirt rev's features schema, so it falls back to QEMU's
            # q35 smm=auto default — verify SB is actually enforced at the live boot (#10).
            loader = {
              readonly = true;
              type = "pflash";
              path = "${cfg.ovmf.package}/FV/OVMF_CODE.ms.fd";
            };
            nvram = {
              template = "${cfg.ovmf.package}/FV/OVMF_VARS.ms.fd";
              path = "/var/lib/libvirt/qemu/nvram/${name}_VARS.fd";
            };
          };

          cpu = {
            mode = "host-passthrough";
            check = "none";
            migratable = false;
            topology = {
              sockets = 1;
              dies = 1;
              cores = vmCfg.vcpu.count / 2;
              threads = 2;
            };
            cache.mode = "passthrough";
            feature =
              if cfg.stealth.enable then
                stealth.cpuFeatures
              else
                [
                  {
                    policy = "require";
                    name = "topoext";
                  }
                  {
                    policy = "require";
                    name = "invtsc";
                  }
                ];
          };

          features = {
            acpi = { };
            apic = { };
            ioapic.driver = "kvm";
          }
          // lib.optionalAttrs cfg.stealth.enable stealth.features;

          clock =
            if cfg.stealth.enable then
              stealth.clock
            else
              {
                offset = "localtime";
                timer = [
                  {
                    name = "rtc";
                    tickpolicy = "catchup";
                  }
                  {
                    name = "pit";
                    tickpolicy = "delay";
                  }
                ];
              };

          on_poweroff = "destroy";
          on_reboot = "restart";
          on_crash = "destroy";

          memoryBacking =
            if (cfg.hugepages.enable || cfg.kvmfr.enable) then
              {
                source.type = "memfd";
                access.mode = "shared";
              }
              // lib.optionalAttrs cfg.hugepages.enable {
                hugepages =
                  { }
                  // lib.optionalAttrs (cfg.hugepages.size == "1G") {
                    page = [
                      {
                        size = 1;
                        unit = "GiB";
                      }
                    ];
                  };
                nosharepages = { };
                locked = { };
              }
            else
              null;

          devices = {
            emulator = "${config.virtualisation.libvirtd.qemu.package}/bin/qemu-system-x86_64";

            disk =
              lib.optionals (vmCfg.disk.path != null) [
                {
                  type = "file";
                  device = "disk";
                  driver = {
                    name = "qemu";
                    type = vmCfg.disk.format;
                    cache = "none";
                    io = "native";
                    discard = "unmap";
                  };
                  source.file = vmCfg.disk.path;
                  target = {
                    dev = "vda";
                    inherit (vmCfg.disk) bus;
                  };
                  boot.order = 1;
                }
              ]
              ++ lib.optionals (vmCfg.iso != null) [
                {
                  type = "file";
                  device = "cdrom";
                  driver = {
                    name = "qemu";
                    type = "raw";
                  };
                  source.file = vmCfg.iso;
                  target = {
                    dev = "sda";
                    bus = "sata";
                  };
                  readonly = true;
                  boot.order = 2;
                }
              ];

            hostdev =
              gpuHostdevs
              ++ extraPciHostdevs
              ++ lib.map (usb: {
                mode = "subsystem";
                type = "usb";
                managed = true;
                source = {
                  vendor.id = usb.vendorId;
                  product.id = usb.productId;
                };
              }) vmCfg.usbPassthrough;

            # Looking Glass shared memory
            shmem = lib.optionals cfg.kvmfr.enable [
              {
                name = "looking-glass";
                model.type = "ivshmem-plain";
                size = {
                  unit = "M";
                  count = cfg.kvmfr.memoryMB;
                };
              }
            ];

            controller = [
              {
                type = "pci";
                index = 0;
                model = "pcie-root";
              }
              {
                type = "pci";
                index = 1;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 2;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 3;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 4;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 5;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 6;
                model = "pcie-root-port";
              }
              {
                type = "pci";
                index = 7;
                model = "pcie-root-port";
              }
              {
                type = "usb";
                index = 0;
                model = "qemu-xhci";
              }
            ]
            ++ lib.optionals (!cfg.stealth.enable) [
              {
                type = "scsi";
                index = 0;
                model = "virtio-scsi";
              }
            ];

            interface =
              (
                if vmCfg.network.type == "nat" then
                  {
                    type = "network";
                    source.network = "default";
                    model.type = "e1000e";
                  }
                else
                  {
                    type = "bridge";
                    source.bridge = vmCfg.network.bridge;
                    model.type = "e1000e";
                  }
              )
              // lib.optionalAttrs (mac != null) { mac.address = mac; };

            input =
              if cfg.stealth.enable then
                [
                  {
                    type = "mouse";
                    bus = "ps2";
                  }
                  {
                    type = "keyboard";
                    bus = "ps2";
                  }
                ]
              else
                [
                  {
                    type = "mouse";
                    bus = "virtio";
                  }
                  {
                    type = "keyboard";
                    bus = "virtio";
                  }
                ];

            # Emulated video + SPICE when not using GPU passthrough (for virt-manager display)
            video = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                model = {
                  type = "qxl";
                  ram = 65536;
                  vram = 65536;
                  vgamem = 16384;
                };
              }
            ];
            graphics = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                type = "spice";
                autoport = true;
                listen = {
                  type = "address";
                  address = "127.0.0.1";
                };
              }
            ];
            # Audio for SPICE when not using GPU passthrough
            sound = lib.optionals (vmCfg.gpu.mode == "emulated") [
              { model = "ich9"; }
            ];
            channel = lib.optionals (vmCfg.gpu.mode == "emulated") [
              {
                type = "spicevmc";
                target = {
                  type = "virtio";
                  name = "com.redhat.spice.0";
                };
              }
            ];

            tpm = lib.optionals vmCfg.os.tpm [
              {
                model = "tpm-tis";
                backend = {
                  type = "emulator";
                  version = "2.0";
                };
              }
            ];

            memballoon.model = "none";
          };

          # QEMU command-line passthrough for stealth args and evdev
          qemu-commandline = {
            arg =
              # Stealth QEMU args (SMBIOS, ACPI SSDT, cpu-pm, CPU identity)
              (lib.optionals cfg.stealth.enable (
                lib.map (a: { value = a; }) (stealth.qemuArgs vmCfg.cpuIdentity)
              ))
              # Evdev input passthrough
              ++ (lib.optionals (cfg.evdev.enable && cfg.evdev.keyboardPath != null) [
                { value = "-object"; }
                {
                  value = "input-linux,id=kbd,evdev=${cfg.evdev.keyboardPath},grab_all=on,repeat=on";
                }
              ])
              ++ (lib.optionals (cfg.evdev.enable && cfg.evdev.mousePath != null) [
                { value = "-object"; }
                { value = "input-linux,id=mouse,evdev=${cfg.evdev.mousePath}"; }
              ])
              ++ (lib.map (a: { value = a; }) vmCfg.extraQemuArgs);
          };
        };
    in
    {
      _class = "nixos";

      # ── VM Definitions Option ──
      options.myModules.vfio.vms = lib.mkOption {
        type = lib.types.lazyAttrsOf vmSubmodule;
        default = { };
        description = "Per-VM definitions";
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # ── Assertions ──
          {
            assertions =
              lib.concatLists (
                lib.mapAttrsToList (
                  name: vmCfg:
                  [
                    {
                      assertion = lib.mod vmCfg.vcpu.count 2 == 0;
                      message = "myModules.vfio.vms.${name}.vcpu.count: must be even (SMT pairs). Got ${toString vmCfg.vcpu.count}.";
                    }
                    {
                      assertion = !(vmCfg.network.type == "bridge" && vmCfg.network.bridge == null);
                      message = "myModules.vfio.vms.${name}.network.bridge: must be set when network.type = \"bridge\".";
                    }
                  ]
                  ++ lib.optional (vmCfg.gpu.mode == "passthrough") {
                    assertion = isValidPciAddr vmCfg.gpu.pciAddress;
                    message = "myModules.vfio.vms.${name}.gpu.pciAddress: must be a valid PCI address DDDD:BB:DD.F (e.g. \"0000:03:00.0\"). Run the inspection script to confirm the device. Got \"${vmCfg.gpu.pciAddress}\".";
                  }
                  ++ lib.optional (vmCfg.gpu.mode == "passthrough" && vmCfg.gpu.audioAddress != null) {
                    assertion = isValidPciAddr vmCfg.gpu.audioAddress;
                    message = "myModules.vfio.vms.${name}.gpu.audioAddress: must be a valid PCI address DDDD:BB:DD.F or null. Got \"${toString vmCfg.gpu.audioAddress}\".";
                  }
                  ++ lib.imap0 (i: addr: {
                    assertion = isValidPciAddr addr;
                    message = "myModules.vfio.vms.${name}.pciPassthrough[${toString i}]: must be a valid PCI address DDDD:BB:DD.F. Run the inspection script and confirm the device is in its own IOMMU group and is NOT a host disk. Got \"${addr}\".";
                  }) vmCfg.pciPassthrough
                  ++ lib.optional (vmCfg.gpu.mode == "passthrough") {
                    assertion = cfg.bindMethod == "static";
                    message = "myModules.vfio.vms.${name}: gpu.mode=\"passthrough\" requires myModules.vfio.bindMethod=\"static\" — dynamic GPU binding was removed; the GPU is captured by vfio-pci at boot. Set bindMethod=\"static\" in this profile.";
                  }
                  ++ lib.optional (vmCfg.gpu.mode == "passthrough" && cfg.bindMethod == "static") {
                    assertion = vmCfg.gpu.staticIds != [ ];
                    message = "myModules.vfio.vms.${name}.gpu.staticIds: must be non-empty under bindMethod=\"static\" — these vendor:device IDs are captured at boot via vfio-pci.ids (e.g. [\"1002:7550\" \"1002:ab40\"]). Without them the GPU is never bound to vfio-pci and the VM fails to start.";
                  }
                ) enabledVms
              )
              ++ mkProtectedDiskAssertions cfg.protectedDiskAddrs;
          }

          # ── NixVirt declarative VM definitions ──
          (lib.mkIf (enabledVms != { }) {
            virtualisation.libvirt = {
              enable = true;
              swtpm.enable = true;
              # active=true ⇒ NixVirt starts the domain (autostart profiles, vfio-all).
              # null ⇒ leave it defined-but-stopped (single-VM profiles: the user
              # starts it by hand after login).
              connections."qemu:///system".domains = lib.mapAttrsToList (name: vmCfg: {
                definition = inputs.NixVirt.lib.domain.writeXML (mkDomainDef name vmCfg);
                active = if cfg.autostart then true else null;
              }) enabledVms;
            };

            # Set the per-domain libvirt autostart flag to match cfg.autostart: enabled
            # so libvirtd brings both VMs up at boot (vfio-all), disabled otherwise so a
            # VM never auto-resumes in a profile that renders on a passed GPU.
            systemd.services.vfio-set-autostart = {
              description = "Set libvirt VM autostart flag for this profile";
              after = [
                "libvirtd.service"
                "nixvirt.service"
              ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = lib.concatMapStringsSep "\n" (name: ''
                ${pkgs.libvirt}/bin/virsh autostart ${
                  lib.optionalString (!cfg.autostart) "--disable "
                }${name} 2>/dev/null || true
              '') (lib.attrNames enabledVms);
            };
          })

          # ── Cross-profile domain hygiene ──
          # libvirt domain definitions are persistent daemon state, so a VM defined
          # under one boot profile (e.g. win11-amd in vfio-amd) lingers in the others.
          # Undefine any VM this module declares but does NOT enable here — targeted by
          # name to our own VMs, so hand-made / emulated VMs are never touched (unlike
          # NixVirt's blanket prune, which undefines every domain not in its list).
          # --keep-nvram preserves the guest's UEFI boot vars; runs in every profile.
          (lib.mkIf (disabledVms != { }) {
            systemd.services.vfio-prune-inactive-vms = {
              description = "Undefine VFIO VMs not enabled in this profile";
              after = [
                "libvirtd.service"
                "nixvirt.service"
              ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = lib.concatMapStringsSep "\n" (name: ''
                if ${pkgs.libvirt}/bin/virsh dominfo "${name}" >/dev/null 2>&1; then
                  ${pkgs.libvirt}/bin/virsh undefine "${name}" --managed-save --keep-nvram --keep-tpm 2>/dev/null \
                    || ${pkgs.libvirt}/bin/virsh undefine "${name}" --keep-nvram 2>/dev/null \
                    || true
                fi
              '') (lib.attrNames disabledVms);
            };
          })

          # ── libvirt qemu hook (NVMe unmount + hugepages + scx) ──
          # Installed whenever VMs are defined — needed under static binding too:
          # the GPU is captured at boot, so the hook only does host-side concerns.
          (lib.mkIf (enabledVms != { }) {
            # libvirt reads hooks from /etc/libvirt/hooks (provided via environment.etc
            # below) — no /var/lib/libvirt/hooks dir needed.
            environment.etc."libvirt/hooks/qemu" = {
              source = "${vfioHookScript}/bin/qemu-hook";
              mode = "0755";
            };
          })

          # ── Smart USB re-attach (udev → systemd-run → virsh attach-device) ──
          # libvirt does not auto-reattach a replugged hostdev USB device; re-attach each
          # declared surgical device to its running VM on hot-plug. Async via systemd-run so
          # udev isn't blocked. Whole-controller passthrough (GREATHTEK) hotplugs natively
          # in the guest and needs none of this.
          (lib.mkIf (enabledVms != { }) {
            services.udev.extraRules = lib.concatStrings (
              lib.concatLists (
                lib.mapAttrsToList (
                  vmName: vmCfg:
                  map (
                    dev:
                    let
                      v = usbIdHex dev.vendorId;
                      p = usbIdHex dev.productId;
                    in
                    ''ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${v}", ATTR{idProduct}=="${p}", RUN+="${pkgs.systemd}/bin/systemd-run --no-block --collect ${usbReattachScript}/bin/vfio-usb-reattach ${vmName} ${v} ${p}"''
                    + "\n"
                  ) vmCfg.usbPassthrough
                ) enabledVms
              )
            );
          })
        ]
      );
    };
in
{
  flake.modules.nixos.vfio-vms = mod;

}
