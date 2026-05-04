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
      user = config.myModules.primaryUser;

      # Pure-function helpers (PCI parse, MAC gen, display probes, hugepage
      # sysfs path, enabledVms filter). Extracted to ./_vms-lib.nix to keep
      # this file focused on hook + domain generation.
      helpers = import ./_vms-lib.nix { inherit lib config cfg; };
      inherit (helpers)
        parsePciAddr
        generateMac
        enabledVms
        hugepageSysfsPath
        hasActiveDisplay
        hasFallbackDisplay
        ;

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
            ${lib.optionalString cfg.hugepages.enable ''
              # --- Allocate hugepages for VM memory ---
              log "[$GUEST_NAME] allocating ${toString cfg.hugepages.count} × ${cfg.hugepages.size} hugepages"
              # Drop caches and compact memory to maximize contiguous regions
              echo 3 > /proc/sys/vm/drop_caches
              echo 1 > /proc/sys/vm/compact_memory
              sleep 1
              echo ${toString cfg.hugepages.count} > ${hugepageSysfsPath}
              allocated=$(cat ${hugepageSysfsPath})
              if [ "$allocated" -lt "${toString cfg.hugepages.count}" ]; then
                log "[$GUEST_NAME] ABORT: only allocated $allocated/${toString cfg.hugepages.count} hugepages (not enough contiguous memory)"
                echo 0 > ${hugepageSysfsPath}
                exit 1
              fi
              log "[$GUEST_NAME] hugepages allocated: $allocated × ${cfg.hugepages.size}"
            ''}
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
              # --- Handle GPU stuck on vfio-pci from previous unclean shutdown ---
              # If the VM was shut down from within Windows, the release hook never runs
              # and the GPU stays bound to vfio-pci. Detect and recover before proceeding.
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                current_driver=$(basename "$(readlink "/sys/bus/pci/devices/$pci_addr/driver")" 2>/dev/null || echo "none")
                if [ "$current_driver" = "vfio-pci" ]; then
                  log "[$GUEST_NAME] $pci_addr stuck on vfio-pci from previous run, recovering..."
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
                  sleep 2
                  echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                  echo "$pci_addr" > /sys/bus/pci/drivers/${cfg.hostGpuDriver}/bind 2>/dev/null || true
                  sleep 2
                  log "[$GUEST_NAME] $pci_addr recovered to ${cfg.hostGpuDriver}"
                fi
              done

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
              sleep 1

              ${lib.optionalString cfg.restrictScxToHost ''
                # Restrict scx scheduler to host-only cores (CCD1) during VM.
                # Instead of stopping scx entirely (losing scheduler benefits on host),
                # restart with --primary-domain restricted to non-VM cores.
                if ${pkgs.systemd}/bin/systemctl is-active scx.service >/dev/null 2>&1; then
                  log "[$GUEST_NAME] restricting scx scheduler to host cores (mask ${cfg.hostCpuMask})"
                  ${pkgs.systemd}/bin/systemctl set-environment SCX_FLAGS_OVERRIDE="-m ${cfg.hostCpuMask}" 2>/dev/null || true
                  ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
                fi
              ''}

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # Single-GPU passthrough path: the host's one GPU owns both the
                # console and the passthrough target, so the console handles
                # must be released before the driver will unbind.
                # Dual-GPU iGPU-primary hosts set releaseConsole=false and skip
                # this entire block — the dGPU holds no vtcon/fb attachment and
                # a global unbind here would blank the iGPU display.
                log "[$GUEST_NAME] switching to VT3 for safe GPU unbind"
                ${pkgs.kbd}/bin/chvt 3
                sleep 2

                # --- Unbind VT consoles ---
                # VT consoles hold framebuffer references to the GPU that prevent clean unbind
                # Enumerate dynamically — number of vtconsoles varies by system
                log "[$GUEST_NAME] unbinding VT consoles"
                for vtcon in /sys/class/vtconsole/vtcon*/bind; do
                  [ -f "$vtcon" ] && echo 0 > "$vtcon" 2>/dev/null || true
                done

                # --- Unbind EFI/simpledrm framebuffer ---
                # The framebuffer keeps a reference to the GPU — must release before driver unbind
                if [ -d /sys/bus/platform/drivers/efi-framebuffer ]; then
                  log "[$GUEST_NAME] unbinding EFI framebuffer"
                  echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
                fi

                # --- Race condition avoidance ---
                # KWin, host GPU driver, and framebuffer need time to fully release DRM handles.
                # Newer GPU drivers (e.g. RDNA 4 amdgpu, current nouveau) may hold references longer.
                # 8s is conservative; tested values: 5s (original, too short), 10s (safe).
                # References: QaidVoid/Complete-Single-GPU-Passthrough, joeknock90/Single-GPU-Passthrough
                sleep 8
              ''}

              # Unbind GPU from host driver, bind to vfio-pci
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  log "[$GUEST_NAME] unbinding $pci_addr from host driver"
                  if [ -f "/sys/bus/pci/devices/$pci_addr/driver/unbind" ]; then
                    echo "$pci_addr" > "/sys/bus/pci/devices/$pci_addr/driver/unbind" || {
                      log "[$GUEST_NAME] ERROR: failed to unbind $pci_addr — attempting PCI remove/rescan fallback"
                      echo 1 > "/sys/bus/pci/devices/$pci_addr/remove" 2>/dev/null || true
                      sleep 2
                      echo 1 > /sys/bus/pci/rescan
                      sleep 2
                    }
                  fi

                  # Verify driver actually released — poll up to 10s
                  for _wait in $(seq 1 10); do
                    if [ ! -f "/sys/bus/pci/devices/$pci_addr/driver/unbind" ]; then
                      break
                    fi
                    log "[$GUEST_NAME] waiting for $pci_addr driver release... (''${_wait}s)"
                    sleep 1
                  done

                  echo "vfio-pci" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/bind || {
                    log "[$GUEST_NAME] ERROR: failed to bind $pci_addr to vfio-pci"
                    ${lib.optionalString vmCfg.gpu.releaseConsole "${pkgs.kbd}/bin/chvt 1"}
                    exit 1
                  }
                  log "[$GUEST_NAME] $pci_addr bound to vfio-pci"
                  sleep 2
                fi
              done

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # Wait for KWin to process GPU removal before switching to graphical VT.
                # Immediate chvt 1 can crash the compositor if it tries to access the
                # now-missing GPU. 5s lets KWin detect the DRM device removal and
                # fall back to the remaining GPU. Only runs when we chvt'd to 3
                # earlier — dual-GPU iGPU-primary never leaves VT1.
                sleep 5
                ${pkgs.kbd}/bin/chvt 1
              ''}

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

              # --- Wait for QEMU to fully release devices ---
              # QEMU needs time to close all PCI device handles after VM shutdown
              sleep 5

              # Stop PowerDevil before GPU rebind
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop plasma-powerdevil.service 2>/dev/null || true

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # Switch to text VT for safe GPU rebind (matches prepare-phase chvt 3).
                # Dual-GPU iGPU-primary (releaseConsole=false) keeps the host display
                # on the iGPU throughout — no VT switch needed.
                ${pkgs.kbd}/bin/chvt 3
                sleep 2
              ''}

              # Unbind from vfio-pci, clear override (with sleep between each device)
              for pci_addr in ${lib.concatStringsSep " " gpuAddrs}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  log "[$GUEST_NAME] unbinding $pci_addr from vfio-pci"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind || {
                    log "[$GUEST_NAME] WARNING: vfio-pci unbind failed for $pci_addr — attempting force"
                    echo 1 > "/sys/bus/pci/devices/$pci_addr/remove" 2>/dev/null || true
                    sleep 2
                    echo 1 > /sys/bus/pci/rescan
                    sleep 2
                  }
                  echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override" 2>/dev/null || true
                  sleep 2
                fi
              done

              log "[$GUEST_NAME] rescanning PCI bus"
              echo 1 > /sys/bus/pci/rescan
              # Host GPU driver needs time to reprobe after PCI rescan
              sleep 5

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # --- Rebind VT consoles ---
                # Restore VT console framebuffer bindings released during prepare.
                log "[$GUEST_NAME] rebinding VT consoles"
                for vtcon in /sys/class/vtconsole/vtcon*/bind; do
                  [ -f "$vtcon" ] && echo 1 > "$vtcon" 2>/dev/null || true
                done

                # --- Rebind EFI/simpledrm framebuffer ---
                if [ -d /sys/bus/platform/drivers/efi-framebuffer ]; then
                  log "[$GUEST_NAME] rebinding EFI framebuffer"
                  echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null || true
                fi

                # Wait for the host GPU driver to fully reprobe and KWin to detect new
                # outputs before switching back to graphical VT. Without this delay, KWin
                # may try to use the GPU before the driver is ready.
                sleep 5

                # Switch back to graphical VT — host driver reclaims GPU, KWin picks up outputs
                ${pkgs.kbd}/bin/chvt 1
              ''}

              # Restart PowerDevil (now sees both GPUs)
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true

              ${lib.optionalString cfg.restrictScxToHost ''
                # Restore scx scheduler to all cores now that VM cores are free
                log "[$GUEST_NAME] restoring scx scheduler to all cores"
                ${pkgs.systemd}/bin/systemctl unset-environment SCX_FLAGS_OVERRIDE 2>/dev/null || true
                ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
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
            ${lib.optionalString cfg.hugepages.enable ''
              # --- Free hugepages after VM shutdown ---
              log "[$GUEST_NAME] freeing hugepages"
              echo 0 > ${hugepageSysfsPath}
              log "[$GUEST_NAME] hugepages freed"
            ''}
          fi
        '';

      vfioHookScript = pkgs.writeShellApplication {
        name = "qemu-hook";
        # Body uses absolute `${pkgs.X}/bin/Y` interpolations already
        # (explicit pinning). runtimeInputs left empty on purpose —
        # writeShellApplication still provides shellcheck + `set -euo
        # pipefail` at build, which is the win over writeShellScript.
        runtimeInputs = [ ];
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
            echo "VFIO-HOOK: $*" | ${pkgs.systemd}/bin/logger -t vfio-hook
          }

          # Prevent sleep/shutdown during GPU bind/unbind — hardware left in
          # partial state if interrupted mid-operation is unrecoverable.
          inhibit() {
            ${pkgs.systemd}/bin/systemd-inhibit \
              --what=sleep:shutdown \
              --who="vfio-hook" \
              --why="GPU passthrough bind/unbind in progress for $GUEST_NAME" \
              --mode=block \
              "$@"
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
            releaseConsole = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Release host VT consoles + EFI framebuffer before the dGPU is
                unbound. Set `true` ONLY for SINGLE-GPU passthrough hosts where
                the one GPU owns the console AND is being passed through —
                those need `chvt 3`, global `vtcon*/bind` unbind, and
                `efi-framebuffer.0` unbind or the host driver never releases
                its DRM master.

                Leave `false` (default) for DUAL-GPU hosts where the iGPU
                drives the console and only a SEPARATE dGPU is being passed
                through. In that layout the dGPU holds no vtcon/framebuffer
                attachment, and running the single-GPU unbind dance would
                blank the iGPU display (global unbinds don't discriminate
                which GPU owns which vtcon/fb → iGPU console goes dark).

                When `true`: hook does `chvt 3`, unbinds all vtcons, unbinds
                `efi-framebuffer.0`, waits for DRM refs to release, unbinds
                the dGPU, `chvt 1`. Reverse on release. Matches the
                joeknock90 / QaidVoid single-GPU-passthrough pattern.

                When `false`: hook skips chvt + vtcon + efi-fb entirely and
                only unbinds the dGPU. Relies on `KWIN_DRM_DEVICES` keeping
                KWin off the dGPU (see `myModules.vfio.sessionGpuDevices`)
                plus the fallback-display + process-abort safety checks to
                guarantee the dGPU carries no open DRM contexts.
              '';
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
          # Stealth VM XML attributes from vfio-stealth repo
          stealth = inputs.vfio-stealth.lib.mkStealthFeatures {
            inherit (cfg.stealth) smbios;
            acpiTables = pkgs.acpi-ssdt-stealth;
            vmUuid = vmCfg.uuid;
            inherit (cfg.stealth) aperfMperf stripVirtio hypervVendorId;
            inherit (cfg.stealth) acpiSsdt;
            inherit (cfg.stealth.smbios) cache;
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
          sysinfo = if cfg.stealth.enable then stealth.sysinfo else null;

          os = {
            type = "hvm";
            arch = "x86_64";
            machine = cfg.machineType;
            firmware = if vmCfg.os.firmware == "uefi" then "efi" else null;
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
            smm.state = true;
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
            assertions = lib.concatLists (
              lib.mapAttrsToList (name: vmCfg: [
                {
                  assertion = lib.mod vmCfg.vcpu.count 2 == 0;
                  message = "myModules.vfio.vms.${name}.vcpu.count: must be even (SMT pairs). Got ${toString vmCfg.vcpu.count}.";
                }
              ]) enabledVms
            );
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
          })

          # ── Dynamic VFIO hook ──
          (lib.mkIf (cfg.bindMethod == "dynamic") {
            systemd.tmpfiles.rules = [
              "d /var/lib/libvirt/hooks 0755 root root -"
            ];

            environment.etc."libvirt/hooks/qemu" = {
              source = "${vfioHookScript}/bin/qemu-hook";
              mode = "0755";
            };
          })
        ]
      );
    };
in
{
  flake.modules.nixos.vfio-vms = mod;

}
