{ inputs, ... }:
{
  flake.nixosModules.vfio =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.vfio;
      user = config.myModules.primaryUser;

      # Parse PCI address string "0000:03:00.0" into integers for NixVirt
      # Nix has no hex parsing, so we convert manually
      hexToInt =
        s:
        let
          hexChars = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
          chars = lib.stringToCharacters s;
        in
        lib.foldl (acc: c: acc * 16 + hexChars.${c}) 0 chars;

      parsePciAddr =
        addr:
        let
          parts = builtins.match "([0-9a-fA-F]+):([0-9a-fA-F]+):([0-9a-fA-F]+)\\.([0-9]+)" addr;
        in
        {
          type = "pci";
          domain = 0;
          bus = hexToInt (builtins.elemAt parts 1);
          slot = hexToInt (builtins.elemAt parts 2);
          function = lib.toInt (builtins.elemAt parts 3);
        };

      # Generate MAC address from prefix + VM name hash
      generateMac =
        prefix: name:
        let
          hash = builtins.hashString "sha256" name;
          hexChars = lib.stringToCharacters hash;
          b1 = lib.concatStrings (lib.sublist 0 2 hexChars);
          b2 = lib.concatStrings (lib.sublist 2 2 hexChars);
          b3 = lib.concatStrings (lib.sublist 4 2 hexChars);
        in
        "${prefix}:${b1}:${b2}:${b3}";

      # Dynamic VFIO bind/unbind hook script
      enabledVms = lib.filterAttrs (_: v: v.enable) cfg.vms;

      # Collect all GPU PCI addresses from VMs that use passthrough
      # Used for: hook script (bind/unbind), static binding (vfio-pci.ids)

      # Collect all PCI passthrough addresses (NVMe, USB controllers, etc.)

      # --- Safe VFIO hook helpers ---

      # Check if a PCI device has active DRM connectors (displays attached and enabled)
      # Returns 0 if the device has at least one active connector
      hasActiveDisplay = ''
        vfio_has_active_display() {
          local pci_addr="$1"
          for card_dir in /sys/bus/pci/devices/"$pci_addr"/drm/card*; do
            [ -d "$card_dir" ] || continue
            for conn_dir in "$card_dir"/card*-*; do
              [ -f "$conn_dir/status" ] || continue
              if [ "$(cat "$conn_dir/status")" = "connected" ]; then
                # Check if connector is enabled (has a valid mode)
                if [ -f "$conn_dir/enabled" ] && [ "$(cat "$conn_dir/enabled")" = "enabled" ]; then
                  return 0
                fi
              fi
            done
          done
          return 1
        }
      '';

      # Find any OTHER GPU (not the one being passed through) that has active displays
      hasFallbackDisplay = ''
        vfio_has_fallback_display() {
          local passthrough_addrs="$*"
          for gpu_dir in /sys/class/drm/card*/device; do
            [ -L "$gpu_dir" ] || continue
            local this_addr
            this_addr="$(basename "$(readlink -f "$gpu_dir")")"
            # Skip the GPU(s) being passed through
            local is_passthrough=0
            for pt_addr in $passthrough_addrs; do
              if [ "$this_addr" = "$pt_addr" ]; then
                is_passthrough=1
                break
              fi
            done
            [ "$is_passthrough" = "1" ] && continue
            # Check if this other GPU has active displays
            if vfio_has_active_display "$this_addr"; then
              return 0
            fi
          done
          return 1
        }
      '';

      # Per-VM hook: prepare (bind devices for passthrough) and release (return to host)
      mkVmHookSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
          );
          pciAddrs = vmCfg.pciPassthrough;
          mounts = vmCfg.mountsToUnmount;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            ${lib.optionalString (mounts != [ ] || pciAddrs != [ ]) ''
              # --- Check for open files on mount points before unmounting ---
              mount_blocked=""
              ${lib.concatMapStringsSep "\n" (mp: ''
                if ${pkgs.util-linux}/bin/findmnt -n "${mp}" >/dev/null 2>&1; then
                  open_files=$(${pkgs.psmisc}/bin/fuser -mv "${mp}" 2>&1 || true)
                  # fuser -m lists all processes using files on the mount
                  # Filter out kernel threads (PID 1, 2) and the fuser process itself
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

              # --- Unmount filesystems before PCI passthrough ---
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
              # Also unmount any remaining partitions discovered from sysfs (safety net)
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
            ${lib.optionalString (gpuAddrs != [ ]) ''
              # --- Safety check: verify fallback display exists ---
              if ! vfio_has_fallback_display ${lib.concatStringsSep " " gpuAddrs}; then
                log "[$GUEST_NAME] ABORT: no fallback display found on another GPU"
                log "[$GUEST_NAME] Connect a monitor to the iGPU (motherboard HDMI) before starting the VM"
                exit 1
              fi
              log "[$GUEST_NAME] fallback display verified on another GPU"

              # --- Check for processes using the dGPU ---
              # GPU contexts CANNOT be migrated between GPUs. Any app with an open
              # render context on the dGPU will crash when it's unbound. Instead of
              # silently killing them (fuser -k), check and abort if non-compositor
              # processes are found so the user can close them first.
              blocking_procs=""
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                for drm_node in /sys/bus/pci/devices/"$pci_addr"/drm/card* /sys/bus/pci/devices/"$pci_addr"/drm/renderD*; do
                  [ -d "$drm_node" ] || continue
                  node_name=$(basename "$drm_node")
                  # List processes using this DRM device (without killing)
                  procs=$(${pkgs.psmisc}/bin/fuser "/dev/dri/$node_name" 2>/dev/null || true)
                  for pid in $procs; do
                    comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "unknown")
                    # KWin holds output-only handles when KWIN_DRM_DEVICES has iGPU first — safe to lose
                    # PowerDevil holds i2c handles — we stop it explicitly below
                    case "$comm" in
                      kwin_wayland|kwin_x11|sddm*|Xwayland|powerdevil) ;;
                      *) blocking_procs="$blocking_procs  PID $pid ($comm) on /dev/dri/$node_name\n" ;;
                    esac
                  done
                done
              done
              if [ -n "$blocking_procs" ]; then
                log "[$GUEST_NAME] ABORT: processes still using the dGPU (close them first):"
                echo -e "$blocking_procs" | while read -r line; do
                  [ -n "$line" ] && log "[$GUEST_NAME]   $line"
                done
                exit 1
              fi
              log "[$GUEST_NAME] no blocking processes on dGPU"

              # --- Stop services that hold GPU file descriptors ---
              # PowerDevil binds to GPU i2c bus (DDC brightness) and blocks driver unbind
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop plasma-powerdevil.service 2>/dev/null || true
              sleep 0.5

              ${lib.optionalString cfg.stopScxOnVm ''
                # Stop scx scheduler — with pinned vCPUs, the host scheduler competing
                # over those cores adds overhead. BORE (compiled into kernel) handles
                # pinned threads well as fallback.
                if ${pkgs.systemd}/bin/systemctl is-active scx.service >/dev/null 2>&1; then
                  log "[$GUEST_NAME] stopping scx scheduler for VM duration"
                  ${pkgs.systemd}/bin/systemctl stop scx.service 2>/dev/null || true
                fi
              ''}

              # Switch to text VT — forces KWin to release DRM master on the dGPU
              log "[$GUEST_NAME] switching to VT3 for safe GPU unbind"
              ${pkgs.kbd}/bin/chvt 3
              sleep 2

              # Unbind GPU from host driver, bind to vfio-pci
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  log "[$GUEST_NAME] unbinding $pci_addr from host driver"
                  if [ -f "/sys/bus/pci/devices/$pci_addr/driver/unbind" ]; then
                    echo "$pci_addr" > "/sys/bus/pci/devices/$pci_addr/driver/unbind" || {
                      log "[$GUEST_NAME] ERROR: failed to unbind $pci_addr"
                      ${pkgs.kbd}/bin/chvt 1
                      exit 1
                    }
                  fi
                  echo "vfio-pci" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/bind || {
                    log "[$GUEST_NAME] ERROR: failed to bind $pci_addr to vfio-pci"
                    ${pkgs.kbd}/bin/chvt 1
                    exit 1
                  }
                  log "[$GUEST_NAME] $pci_addr bound to vfio-pci"
                fi
              done

              # Switch back to graphical VT — KWin continues on iGPU
              sleep 1
              ${pkgs.kbd}/bin/chvt 1

              # Restart PowerDevil (now on iGPU)
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true
              log "[$GUEST_NAME] GPU passthrough complete, compositor on iGPU"
            ''}
          fi
        '';

      mkVmReleaseSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
          );
          mounts = vmCfg.mountsToUnmount;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            ${lib.optionalString (gpuAddrs != [ ]) ''
              log "[$GUEST_NAME] releasing GPU back to host"

              # Stop PowerDevil before GPU rebind
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop plasma-powerdevil.service 2>/dev/null || true

              # Switch to text VT for safe GPU rebind
              ${pkgs.kbd}/bin/chvt 3
              sleep 1

              # Unbind from vfio-pci, clear override
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  log "[$GUEST_NAME] unbinding $pci_addr from vfio-pci"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
                  echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                fi
              done

              log "[$GUEST_NAME] rescanning PCI bus"
              echo 1 > /sys/bus/pci/rescan
              sleep 2

              # Switch back to graphical VT — host driver reclaims GPU, KWin picks up outputs
              ${pkgs.kbd}/bin/chvt 1

              # Restart PowerDevil (now sees both GPUs)
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true

              ${lib.optionalString cfg.stopScxOnVm ''
                # Restart scx scheduler now that VM cores are free
                log "[$GUEST_NAME] restarting scx scheduler"
                ${pkgs.systemd}/bin/systemctl start scx.service 2>/dev/null || true
              ''}
              log "[$GUEST_NAME] GPU returned to host"
            ''}
            ${lib.optionalString (mounts != [ ]) ''
              # Remount filesystems after PCI devices return to host
              sleep 1
              ${lib.concatMapStringsSep "\n" (mp: ''
                log "[$GUEST_NAME] remounting ${mp}"
                ${pkgs.util-linux}/bin/mount "${mp}" 2>/dev/null || {
                  log "[$GUEST_NAME] WARNING: failed to remount ${mp} — run 'mount -a' manually"
                }
              '') mounts}
            ''}
          fi
        '';

      vfioHookScript = pkgs.writeShellScript "qemu-hook" ''
        set -euo pipefail

        GUEST_NAME="$1"
        HOOK_NAME="$2"
        STATE_NAME="$3"

        # Log helper — all output goes to systemd journal: journalctl -t vfio-hook
        log() {
          echo "VFIO-HOOK: $*" | ${pkgs.systemd}/bin/logger -t vfio-hook
        }

        # Display detection helpers
        ${hasActiveDisplay}
        ${hasFallbackDisplay}

        if [ "$HOOK_NAME" = "prepare" ] && [ "$STATE_NAME" = "begin" ]; then
          log "[$GUEST_NAME] prepare/begin"
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmHookSection enabledVms)}
        fi

        if [ "$HOOK_NAME" = "release" ] && [ "$STATE_NAME" = "end" ]; then
          log "[$GUEST_NAME] release/end"
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkVmReleaseSection enabledVms)}
        fi
      '';

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
                managed = true;
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
                managed = true;
                source.address = parsePciAddr vmCfg.gpu.audioAddress;
              }
            ]
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
          sysinfo =
            if cfg.stealth.enable then
              {
                type = "smbios";
                bios.entry = [
                  {
                    name = "vendor";
                    value = cfg.stealth.smbios.biosVendor;
                  }
                  {
                    name = "version";
                    value = cfg.stealth.smbios.biosVersion;
                  }
                ];
                system.entry = [
                  {
                    name = "manufacturer";
                    value = cfg.stealth.smbios.manufacturer;
                  }
                  {
                    name = "product";
                    value = cfg.stealth.smbios.product;
                  }
                  {
                    name = "serial";
                    value = cfg.stealth.smbios.serial;
                  }
                  {
                    name = "uuid";
                    value = vmCfg.uuid;
                  }
                  {
                    name = "family";
                    value = "To be filled by O.E.M.";
                  }
                ];
                baseBoard.entry = [
                  {
                    name = "manufacturer";
                    value = cfg.stealth.smbios.manufacturer;
                  }
                  {
                    name = "product";
                    value = cfg.stealth.smbios.product;
                  }
                ];
              }
            else
              null;

          os = {
            type = "hvm";
            arch = "x86_64";
            machine = cfg.machineType;
            smbios.mode = if cfg.stealth.enable then "sysinfo" else null;
            boot = [ { dev = "hd"; } ] ++ lib.optionals (vmCfg.iso != null) [ { dev = "cdrom"; } ];
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
              (lib.optionals cfg.stealth.enable [
                {
                  policy = "disable";
                  name = "hypervisor";
                }
              ])
              ++ [
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
            smm.state = true;
          }
          // lib.optionalAttrs cfg.stealth.enable {
            hyperv = {
              mode = "custom";
              relaxed.state = true;
              vapic.state = true;
              spinlocks = {
                state = true;
                retries = 8191;
              };
              vpindex.state = true;
              runtime.state = true;
              synic.state = true;
              stimer = {
                state = true;
                direct.state = true;
              };
              reset.state = true;
              vendor_id = {
                state = true;
                value = "AMDisbetter!";
              };
              frequencies.state = true;
              reenlightenment.state = true;
              tlbflush.state = true;
              ipi.state = true;
            };
            kvm = {
              hidden.state = true;
              hint-dedicated.state = true;
              poll-control.state = true;
            };
            vmport.state = false;
          };

          clock = {
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
              {
                name = "hpet";
                present = false;
              }
              {
                name = "kvmclock";
                present = false;
              }
              {
                name = "hypervclock";
                present = true;
              }
              {
                name = "tsc";
                present = true;
                mode = "native";
              }
            ];
          };

          on_poweroff = "destroy";
          on_reboot = "restart";
          on_crash = "destroy";

          memoryBacking =
            if (cfg.hugepages.enable || cfg.lookingGlass.enable) then
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
            emulator = "${if cfg.stealth.enable then pkgs.qemu-stealth else pkgs.qemu}/bin/qemu-system-x86_64";

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

            hostdev = gpuHostdevs ++ extraPciHostdevs;

            # Looking Glass shared memory
            shmem = lib.optionals cfg.lookingGlass.enable [
              {
                name = "looking-glass";
                model.type = "ivshmem-plain";
                size = {
                  unit = "M";
                  count = cfg.lookingGlass.memoryMB;
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

            input = [
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
                listen.type = "address";
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

            memballoon.model = "none";
          };

          # QEMU command-line passthrough for stealth args and evdev
          qemu-commandline = {
            arg =
              # CPUID brand string override — guest sees spoofed CPU model in /proc/cpuinfo
              (lib.optionals (cfg.stealth.enable && vmCfg.cpuIdentity.modelId != null) [
                { value = "-global"; }
                { value = "cpu.model-id=${vmCfg.cpuIdentity.modelId}"; }
              ])
              # SMBIOS type 4 (processor) — matches spoofed CPU in dmidecode
              ++ (lib.optionals (cfg.stealth.enable && vmCfg.cpuIdentity.modelId != null) [
                { value = "-smbios"; }
                {
                  value = "type=4,sock_pfx=${cfg.stealth.smbios.socketPrefix},manufacturer=Advanced Micro Devices\\, Inc.,version=${vmCfg.cpuIdentity.modelId},max-speed=${toString vmCfg.cpuIdentity.maxSpeed},current-speed=${toString vmCfg.cpuIdentity.currentSpeed}";
                }
              ])
              # SMBIOS type 3 (chassis) — prevents empty WMI Win32_SystemEnclosure
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                {
                  value = "type=3,manufacturer=${cfg.stealth.smbios.manufacturer},version=1.0,serial=Default string,asset=Default string,sku=Default string";
                }
              ])
              # SMBIOS type 27 (cooling device) — prevents empty WMI Win32_Fan (2025 detection vector)
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                { value = "type=27,type=32,status=3,speed=3200"; }
              ])
              # SMBIOS type 28 (temperature probe) — prevents empty WMI Win32_TemperatureProbe
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-smbios"; }
                { value = "type=28,description=CPU Thermal Probe,type=3,status=3,max=1000,min=100"; }
              ])
              # CPU power management hint (stealth)
              ++ (lib.optionals cfg.stealth.enable [
                { value = "-overcommit"; }
                { value = "cpu-pm=on"; }
              ])
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

      # ========================================================================
      # Options
      # ========================================================================
      options.myModules.vfio = {
        enable = lib.mkEnableOption "VFIO GPU passthrough with stealth VM management";

        # --- Session GPU Management ---
        # Force KWin to use iGPU as primary render device so the dGPU can be
        # safely unbound without crashing the compositor. KWin treats the first
        # device as its primary render GPU; remaining devices are output-only.
        # When the dGPU is removed for passthrough, KWin loses those outputs
        # but keeps rendering on the iGPU. On return, KWin reclaims the dGPU.
        sessionGpuDevices = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          example = [
            "/dev/dri/card0"
            "/dev/dri/card1"
          ];
          description = "DRM device paths for KWIN_DRM_DEVICES. First device becomes the primary render GPU — set your iGPU first for safe GPU passthrough. null = KWin auto-detects (unsafe for passthrough).";
        };

        # --- Machine & VM Configuration ---
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

        # --- VFIO Device Binding ---
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

        # --- Stealth ---
        stealth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Build patched QEMU with anti-detection + KVM kernel patches for RDTSC spoofing";
          };
          smbios = {
            manufacturer = lib.mkOption {
              type = lib.types.str;
              default = "ASUSTeK COMPUTER INC.";
              description = "SMBIOS system manufacturer";
            };
            product = lib.mkOption {
              type = lib.types.str;
              default = "ROG CROSSHAIR X870E HERO";
              description = "SMBIOS product name";
            };
            biosVendor = lib.mkOption {
              type = lib.types.str;
              default = "American Megatrends Inc.";
              description = "SMBIOS BIOS vendor";
            };
            biosVersion = lib.mkOption {
              type = lib.types.str;
              default = "2101";
              description = "SMBIOS BIOS version";
            };
            serial = lib.mkOption {
              type = lib.types.str;
              default = "System Serial Number";
              description = "SMBIOS system serial number";
            };
            socketPrefix = lib.mkOption {
              type = lib.types.str;
              default = "AM5";
              description = "SMBIOS Type 4 socket prefix (e.g. AM5, AM4, LGA1700)";
            };
          };
          maxCState = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Maximum CPU C-state (1 = C1, ~1us wake latency — good stealth/power trade-off). Lower = lower latency but higher power.";
          };
          spoofMac = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate realistic MAC addresses with a real vendor OUI prefix";
          };
          macPrefix = lib.mkOption {
            type = lib.types.str;
            default = "04:42:1a";
            description = "MAC address OUI prefix (default: ASUS)";
          };
        };

        # --- Looking Glass ---
        lookingGlass = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "KVMFR shared memory for Looking Glass frame relay";
          };
          memoryMB = lib.mkOption {
            type = lib.types.int;
            default = 64;
            description = "KVMFR shared memory size in MB (32=1440p SDR, 64=4K SDR, 128=4K HDR)";
          };
        };

        # --- Evdev Input ---
        evdev = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Evdev input passthrough for keyboard/mouse";
          };
          keyboardPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to keyboard event device (e.g. /dev/input/by-id/...)";
          };
          mousePath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to mouse event device (e.g. /dev/input/by-id/...)";
          };
        };

        # --- Hugepages ---
        hugepages = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Static hugepage allocation for VM memory";
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

        # --- Scheduler & Priority Integration ---
        anancyOverride = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Override CachyOS ananicy-cpp rules for QEMU. Default rules classify QEMU as Heavy_CPU (nice=9, ionice=7) which deprioritizes VM performance. This adds custom rules that give QEMU and libvirt high priority instead.";
        };

        stopScxOnVm = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Stop the scx scheduler service while a VM with pinned vCPUs is running. With CPU pinning, the sched-ext scheduler competing over pinned cores can add overhead. The BORE fallback scheduler handles pinned threads well. Restarted on VM stop.";
        };

        # --- VM Definitions ---
        vms = lib.mkOption {
          type = lib.types.lazyAttrsOf vmSubmodule;
          default = { };
          description = "Per-VM definitions";
        };
      };

      # ========================================================================
      # Config
      # ========================================================================
      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # ── Core VFIO kernel setup ──
          {
            boot.kernelModules = [
              "vfio"
              "vfio_iommu_type1"
              "vfio-pci"
            ];

            boot.kernelParams = [
              "video=efifb:off" # Prevent host claiming passthrough GPU framebuffer
              "pcie_aspm=off" # Disable ASPM for passthrough devices (stability)
            ]
            # Static binding: vfio-pci captures devices at boot
            ++ lib.optionals (cfg.bindMethod == "static" && cfg.staticPciIds != [ ]) [
              "vfio-pci.ids=${lib.concatStringsSep "," cfg.staticPciIds}"
            ];
          }

          # ── KWin GPU device order (safe passthrough) ──
          (lib.mkIf (cfg.sessionGpuDevices != null) {
            # Set KWIN_DRM_DEVICES so KWin uses iGPU as primary render device.
            # The first device in the list becomes the primary — when the dGPU
            # is removed for passthrough, KWin loses those outputs but keeps
            # rendering on the iGPU. Without this, KWin crashes on GPU removal.
            environment.variables.KWIN_DRM_DEVICES = lib.concatStringsSep ":" cfg.sessionGpuDevices;
          })

          # ── Ananicy-cpp override: promote QEMU from Heavy_CPU to high priority ──
          # CachyOS default rules set qemu-system-x86_64 as Heavy_CPU (nice=9, ionice=7,
          # latency_nice=9) which deprioritizes VM threads. For GPU passthrough gaming VMs,
          # QEMU vCPU threads need low latency. Custom rules override this.
          (lib.mkIf cfg.anancyOverride {
            # Override CachyOS default rules that classify QEMU as Heavy_CPU (nice=9,
            # ionice=7, latency_nice=9). For gaming VMs, vCPU threads need low latency.
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

          # ── KVM kernel patches for RDTSC spoofing (stealth) ──
          (lib.mkIf cfg.stealth.enable {
            boot.kernelPatches = [
              {
                name = "kvm-anti-detection-svm";
                patch = "${inputs.hypervisor-phantom}/patches/Kernel/linux-6.18.8-svm.patch";
              }
            ];

            # Stealth kernel params (idle=poll removed: wastes 100-150W, max_cstate=1 is sufficient on Zen 5)
            boot.kernelParams = [
              "processor.max_cstate=${toString cfg.stealth.maxCState}" # Limit C-states for timer stability
            ];
          })

          # ── Libvirt + QEMU ──
          {
            virtualisation.libvirtd = {
              enable = true;
              qemu = {
                package = if cfg.stealth.enable then pkgs.qemu-stealth else pkgs.qemu;
                runAsRoot = true;
                swtpm.enable = true;
                verbatimConfig = ''
                  cgroup_device_acl = [
                    "/dev/null", "/dev/full", "/dev/zero",
                    "/dev/random", "/dev/urandom",
                    "/dev/ptmx", "/dev/kvm",
                    "/dev/kvmfr0",
                    "/dev/vfio/vfio"
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

            # Virsh and virt-manager
            environment.systemPackages = with pkgs; [
              virt-manager
              virt-viewer
            ];

            # virt-manager auto-connects to local QEMU/KVM
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
              # Start the default network if it exists but isn't active, and enable autostart
              script = ''
                ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true
                ${pkgs.libvirt}/bin/virsh net-autostart default 2>/dev/null || true
              '';
            };

            # Never auto-start or auto-resume VMs — only manual launch via virt-manager
            systemd.services.libvirt-guests.serviceConfig = {
              ExecStart = lib.mkForce "${pkgs.coreutils}/bin/true";
            };

            # Ensure autostart is disabled for all defined VMs after NixVirt defines them
            systemd.services.vfio-disable-autostart = {
              description = "Disable libvirt VM autostart";
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
                ${pkgs.libvirt}/bin/virsh autostart --disable ${name} 2>/dev/null || true
              '') (lib.attrNames enabledVms);
            };
          }

          # ── NixVirt declarative VM definitions ──
          (lib.mkIf (enabledVms != { }) {
            virtualisation.libvirt = {
              enable = true;
              swtpm.enable = true;
              connections."qemu:///system".domains = lib.mapAttrsToList (name: vmCfg: {
                definition = inputs.NixVirt.lib.domain.writeXML (mkDomainDef name vmCfg);
                active = null;
              }) enabledVms;
            };
          })

          # ── Dynamic VFIO hook ──
          (lib.mkIf (cfg.bindMethod == "dynamic") {
            systemd.tmpfiles.rules = [
              "d /var/lib/libvirt/hooks 0755 root root -"
            ];

            environment.etc."libvirt/hooks/qemu" = {
              source = vfioHookScript;
              mode = "0755";
            };
          })

          # ── Looking Glass ──
          (lib.mkIf cfg.lookingGlass.enable {
            boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
            boot.kernelModules = [ "kvmfr" ];
            boot.extraModprobeConfig = ''
              options kvmfr static_size_mb=${toString cfg.lookingGlass.memoryMB}
            '';

            services.udev.extraRules = ''
              SUBSYSTEM=="kvmfr", OWNER="${user}", GROUP="kvm", MODE="0660"
            '';

            environment.systemPackages = [ pkgs.looking-glass-client ];
          })

          # ── Evdev input permissions ──
          (lib.mkIf cfg.evdev.enable {
            services.udev.extraRules = ''
              SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="input"
            '';
          })

          # ── Hugepages ──
          (lib.mkIf cfg.hugepages.enable {
            boot.kernelParams = [
              "default_hugepagesz=${cfg.hugepages.size}"
              "hugepagesz=${cfg.hugepages.size}"
              "hugepages=${toString cfg.hugepages.count}"
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
}
