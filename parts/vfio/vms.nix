# vms — per-VM NixVirt definitions with GPU passthrough and libvirt hook generation.
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

      # All shared VFIO logic lives in the single private ./_lib.nix — one
      # implementation + one style for every concern; this file stays focused on
      # hook + domain generation.
      helpers = import ./_lib.nix {
        inherit
          lib
          config
          cfg
          pkgs
          myLib
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

      # log2 of a power-of-two int (PCI BAR resize writes log2(size_in_MiB)).
      log2 = n: if n <= 1 then 0 else 1 + log2 (n / 2);

      mkVmHookSection =
        name: vmCfg:
        let
          pciAddrs = vmCfg.pciPassthrough;
          mounts = vmCfg.mountsToUnmount;
          # GPUs are captured by vfio-pci at boot (static binding) — the hook
          # only touches them when gpu.dynamicBind is set (it binds vfio-pci at VM
          # start, below). Otherwise it handles only host-side concerns: the disk
          # safety guard, unmounting the passed NVMe, hugepages, and scx. The
          # guard still loops the GPU addrs too as cheap defence (a mistyped GPU
          # address that actually backs a host disk is caught).
          guardAddrList = lib.concatStringsSep " " (gpuAddrsOf vmCfg ++ pciAddrs);
          # Dynamic CPU isolation (cfg.cpuPin.dynamic): the host-core set to confine host
          # tasks to while this VM runs = all threads minus the VM's pinned cores.
          dynPin = if vmCfg.vcpu.pinning == null then [ ] else vmCfg.vcpu.pinning;
          dynHostCpus = lib.concatMapStringsSep "," toString (
            lib.subtractLists dynPin (lib.range 0 (cfg.cpuPin.threads - 1))
          );
          dynAllCpus = "0-${toString (cfg.cpuPin.threads - 1)}";
          # Other enabled VMs that also pin vCPUs. Dynamic cpuPin is one VM at a time, so the
          # prepare guard refuses to start this VM while any of these is already running.
          otherDynVms = lib.filter (n: n != name) (
            lib.attrNames (lib.filterAttrs (_: v: v.vcpu.pinning != null) enabledVms)
          );
          otherDynVmsStr = lib.concatStringsSep " " otherDynVms;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            # ── Phase 1 — validate (no mutations, safe to abort) ──
            # SAFETY: refuse to pass any device backing a host-critical filesystem.
            for pci_addr in ${guardAddrList}; do
              if vfio_guard_protected_disk "$pci_addr"; then exit 1; fi
            done
            ${lib.optionalString (cfg.cpuPin.dynamic && vmCfg.vcpu.pinning != null && otherDynVms != [ ]) ''
              # Dynamic cpuPin is one VM at a time: a 2nd VM's confine would overwrite ours,
              # and its later stop would wrongly widen the host onto a still-running VM's
              # cores. Refuse to start while another dynamic-pinned VM runs.
              for other_vm in ${otherDynVmsStr}; do
                other_state="$(${pkgs.libvirt}/bin/virsh -c qemu:///system domstate "$other_vm" 2>/dev/null || true)"
                if grep -qxF running <<< "$other_state"; then
                  log "[$GUEST_NAME] ABORT: dynamic cpuPin is one VM at a time; $other_vm is already running -- stop it first"
                  exit 1
                fi
              done
            ''}
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
              ${lib.optionalString (cfg.cpuPin.dynamic && vmCfg.vcpu.pinning != null) ''
                for host_slice in system.slice user.slice init.scope; do
                  ${pkgs.systemd}/bin/systemctl set-property --runtime -- "$host_slice" "AllowedCPUs=${dynAllCpus}" 2>/dev/null || true
                done
              ''}
            }
            trap _vfio_cleanup EXIT

            ${lib.optionalString (vmCfg.gpu.mode == "passthrough" && vmCfg.gpu.dynamicBind) ''
              # Dynamic GPU bind: amdgpu cold-initialised the card at boot; hand every
              # GPU function to vfio-pci now, just before QEMU. Audio/aux first, VGA last.
              # On failure we abort but do NOT revert to amdgpu (that rebind can BUG the
              # kernel) -- vfio-pci is the safe resting state.
              ${pkgs.kmod}/bin/modprobe vfio-pci 2>/dev/null || true
              ${lib.optionalString (vmCfg.gpu.bar2ResizeMB != null) (
                let
                  wantBit = log2 vmCfg.gpu.bar2ResizeMB;
                in
                ''
                  # Resize BAR2 to ${toString vmCfg.gpu.bar2ResizeMB} MiB while NO driver is attached
                  # (the kernel refuses ReBAR writes with a driver bound), so it runs every VM start
                  # incl. the 2nd+ where the card is already on vfio-pci. The value written is
                  # log2(MiB) = ${toString wantBit}, verified against the device's supported mask.
                  # Clamp SMALL (e.g. 8) to avoid the Navi AMD-driver Code-43 that triggers when guest
                  # BAR2 > 8 MiB (L1T 9070 XT / 7900 XTX); the LARGEST advertised size (e.g. 256 for
                  # Navi 48) instead forces a ReBAR re-enumeration that clears a stuck FLR/SBR reset
                  # (github.com/michaelheichler/vfio-9070xt-reset).
                  bar2_dev="${vmCfg.gpu.pciAddress}"
                  bar2_path="/sys/bus/pci/devices/$bar2_dev"
                  if [ -L "$bar2_path/driver" ]; then
                    echo "$bar2_dev" > "$bar2_path/driver/unbind" 2>/dev/null || true
                  fi
                  bar2_node="$bar2_path/resource2_resize"
                  if [ -w "$bar2_node" ]; then
                    bar2_mask_hex="$(cat "$bar2_node" 2>/dev/null || true)"
                    case "$bar2_mask_hex" in
                      "" | *[!0-9a-fA-F]*)
                        log "[$GUEST_NAME] BAR2 resize: resource2_resize unreadable; skipping"
                        ;;
                      *)
                        bar2_mask=$(( 16#$bar2_mask_hex ))
                        if [ $(( (bar2_mask >> ${toString wantBit}) & 1 )) -eq 1 ]; then
                          log "[$GUEST_NAME] BAR2 resize to ${toString vmCfg.gpu.bar2ResizeMB} MiB (value ${toString wantBit}) on $bar2_dev"
                          echo ${toString wantBit} > "$bar2_node" 2>/dev/null || log "[$GUEST_NAME] BAR2 resize: write failed (continuing)"
                          sleep 1
                        else
                          log "[$GUEST_NAME] BAR2 resize: ${toString vmCfg.gpu.bar2ResizeMB} MiB (value ${toString wantBit}) not in device mask $bar2_mask_hex; skipping"
                        fi
                        ;;
                    esac
                  else
                    log "[$GUEST_NAME] BAR2 resize: $bar2_node not writable; skipping"
                  fi
                ''
              )}
              for gpu_dev in ${lib.concatStringsSep " " (lib.reverseList (gpuAddrsOf vmCfg))}; do
                dev_path="/sys/bus/pci/devices/$gpu_dev"
                if [ ! -e "$dev_path" ]; then
                  log "[$GUEST_NAME] ABORT: dynamicBind GPU $gpu_dev not present"
                  exit 1
                fi
                cur=""
                if [ -L "$dev_path/driver" ]; then
                  cur="$(basename "$(readlink "$dev_path/driver")")"
                fi
                if [ "$cur" = "vfio-pci" ]; then
                  log "[$GUEST_NAME] $gpu_dev already on vfio-pci"
                  continue
                fi
                log "[$GUEST_NAME] binding $gpu_dev (host driver ''${cur:-none}) to vfio-pci"
                if ! echo vfio-pci > "$dev_path/driver_override" 2>/dev/null; then
                  log "[$GUEST_NAME] ABORT: cannot set driver_override for $gpu_dev"
                  exit 1
                fi
                if [ -n "$cur" ]; then
                  if ! echo "$gpu_dev" > "$dev_path/driver/unbind" 2>/dev/null; then
                    log "[$GUEST_NAME] ABORT: failed to unbind $gpu_dev from $cur"
                    exit 1
                  fi
                fi
                echo "$gpu_dev" > /sys/bus/pci/drivers_probe 2>/dev/null || true
                bound=""
                if [ -L "$dev_path/driver" ]; then
                  bound="$(basename "$(readlink "$dev_path/driver")")"
                fi
                if [ "$bound" != "vfio-pci" ]; then
                  log "[$GUEST_NAME] ABORT: $gpu_dev failed to bind vfio-pci (now ''${bound:-none})"
                  exit 1
                fi
              done
            ''}

            ${lib.optionalString (cfg.hugepages.enable && !cfg.hugepages.bootStatic) ''
              # Allocate hugepages for VM memory (dynamic profiles only; bootStatic
              # profiles like vfio-both reserve the whole pool at boot — a single hook
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
            ${lib.optionalString (cfg.cpuPin.dynamic && vmCfg.vcpu.pinning != null) ''
              # Dynamic CPU isolation: confine host tasks to the cores this VM does NOT use,
              # so the host runs full-power when idle and is squeezed off the VM's cores only
              # while it runs (no boot isolcpus). The VM's QEMU lives in machine.slice and is
              # untouched. Restored on VM stop.
              log "[$GUEST_NAME] confining host tasks to cores ${dynHostCpus}"
              for host_slice in system.slice user.slice init.scope; do
                ${pkgs.systemd}/bin/systemctl set-property --runtime -- "$host_slice" "AllowedCPUs=${dynHostCpus}" 2>/dev/null || log "[$GUEST_NAME] WARN: could not confine $host_slice"
              done
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
          dynAllCpus = "0-${toString (cfg.cpuPin.threads - 1)}";
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            : # no-op: keeps the block valid when nothing needs restoring (bootStatic + no mounts)
            ${lib.optionalString (cfg.cpuPin.dynamic && vmCfg.vcpu.pinning != null) ''
              # Restore host tasks to all cores on VM stop (undo the dynamic confinement).
              log "[$GUEST_NAME] restoring host tasks to all cores (${dynAllCpus})"
              for host_slice in system.slice user.slice init.scope; do
                ${pkgs.systemd}/bin/systemctl set-property --runtime -- "$host_slice" "AllowedCPUs=${dynAllCpus}" 2>/dev/null || true
              done
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
            ${lib.optionalString
              (vmCfg.gpu.mode == "passthrough" && vmCfg.gpu.dynamicBind && vmCfg.gpu.rebindHostOnStop)
              ''
                # Opt-in: rebind the GPU to its host driver on VM stop. WARNING: the
                # vfio-pci -> amdgpu rebind BUGs some kernels (7.1-cachyos / Navi 48).
                for gpu_dev in ${lib.concatStringsSep " " (gpuAddrsOf vmCfg)}; do
                  dev_path="/sys/bus/pci/devices/$gpu_dev"
                  [ -e "$dev_path" ] || continue
                  log "[$GUEST_NAME] rebinding $gpu_dev to host driver"
                  echo "$gpu_dev" > "$dev_path/driver/unbind" 2>/dev/null || true
                  echo > "$dev_path/driver_override" 2>/dev/null || true
                  echo "$gpu_dev" > /sys/bus/pci/drivers_probe 2>/dev/null || true
                done
              ''
            }
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
              type = lib.types.ints.positive;
              default = 16;
              description = "RAM allocation in GiB";
            };
          };
          vcpu = {
            count = lib.mkOption {
              type = lib.types.ints.positive;
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
            romBar = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable ROM BAR on the GPU hostdev. RDNA 4 (Navi 48) requires this OFF -- the AMD driver misreads the ROM BAR and produces framebuffer corruption (green/red artifacts).";
            };
            dynamicBind = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Bind this GPU to vfio-pci at VM START via the qemu prepare hook instead of capturing it at boot with vfio-pci.ids. The host driver (amdgpu) cold-initialises the card at boot, then the hook unbinds it and binds vfio-pci just before the domain starts -- use when the card needs a clean host POST before passthrough (some RDNA 4 / Navi 48 boards). When true the GPU's staticIds are NOT added to vfio-pci.ids and passthrough no longer requires bindMethod=static. The card is NOT rebound to the host driver on VM stop unless rebindHostOnStop is set; reboot to reclaim it on the host.";
            };
            rebindHostOnStop = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "With dynamicBind, also rebind the GPU (and audio) to their host drivers when the VM stops. Default OFF: the vfio-pci -> amdgpu rebind triggers a kernel BUG on some kernels (observed on 7.1-cachyos / Navi 48 at amdgpu_device_mm_access). Enable only on a kernel proven to survive the rebind; otherwise reboot to reclaim the card.";
            };
            bar2ResizeMB = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Resize this GPU's BAR2 to N MiB in the no-driver window between the host-driver unbind and the vfio-pci bind (requires dynamicBind). N must be a power of 2 that the device advertises in resource2_resize. Two uses: (1) clamp SMALL (e.g. 8) -- the Windows AMD driver Code-43s on Navi when the guest BAR2 is larger than 8 MiB (source: L1T 9070 XT / 7900 XTX VFIO threads); (2) set the LARGEST advertised size (e.g. 256 for Navi 48) to force a PCI ReBAR re-enumeration that clears the stuck reset state FLR/SBR leave on Navi 48, without which the 2nd+ VM start in a host-boot has no display (source: github.com/michaelheichler/vfio-9070xt-reset). null = leave BAR2 untouched (rely on libvirt's FLR/SBR).";
            };
            libvirtManaged = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Use libvirt managed='yes' for this GPU: libvirt unbinds the host driver (amdgpu/nvidia), binds vfio-pci, and resets the card before the domain starts, then REBINDS the host driver on stop -- the recommended dynamic mechanism (no boot vfio-pci.ids capture, no prepare-hook bind race). Mutually exclusive with dynamicBind. NOTE: the rebind-on-stop reattaches amdgpu, which can BUG some kernels (CachyOS 7.1 / Navi 48); on those prefer dynamicBind (no rebind) or reboot to reclaim.";
            };
            extraFunctions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Additional PCI functions in the GPU's IOMMU group (USB, USB-C controllers for multi-function GPUs like NVIDIA). Bound alongside VGA + Audio -- by the prepare hook under dynamicBind, or by libvirt under libvirtManaged (managed='yes').";
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
            description = "Mount points to unmount before PCI passthrough and remount after VM stop. The hook also discovers mounts from sysfs as a safety net, but this ensures specific paths like '/mnt/Windows-SSD' are handled explicitly.";
            example = [ "/mnt/Windows-SSD" ];
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
            assocL1 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "SMBIOS Type 7 L1 associativity byte (null = host-wide). 7 = 8-way (AMD Zen 4/5 L1d).";
            };
            assocL2 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "SMBIOS Type 7 L2 associativity byte (null = host-wide). 7 = 8-way (AMD Zen 4/5 L2).";
            };
            assocL3 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "SMBIOS Type 7 L3 associativity byte (null = host-wide). 9 = 16-way V-Cache; 7 = 8-way non-V-Cache CCD.";
            };
            ecc = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "SMBIOS Type 7 error correction type (null = host-wide). 3 = None (consumer Ryzen); 4 = Parity (server EPYC).";
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
          kvmPvEnforceCpuid = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Per-VM kvm-pv-enforce-cpuid override (null = inherit myModules.vfio.stealth.kvmPvEnforceCpuid). Off for Windows guests (AutoVirt's flipped-on default faults Win HAL/HvLoader KVM paravirt MSR range with #GP); on for Linux guests that use KVM paravirt features.";
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
          # set (vfio-both, two VMs at once); otherwise the faithful host serials.
          smbios =
            if cfg.perVmStealthSerials then perVmSmbios cfg.stealth.smbios name else cfg.stealth.smbios;

          stealth = inputs.vfio-stealth.lib.mkStealthFeatures {
            inherit smbios;
            acpiTables = pkgs.acpi-ssdt-stealth;
            vmUuid = vmCfg.uuid;
            inherit (cfg.stealth)
              aperfMperf
              stripVirtio
              hypervVendorId
              pciMmio64Mb
              ;
            inherit (cfg.stealth) acpiSsdt;
            hypervMode = if vmCfg.hypervMode != null then vmCfg.hypervMode else cfg.stealth.hypervMode;
            kvmPvEnforceCpuid =
              if vmCfg.kvmPvEnforceCpuid != null then vmCfg.kvmPvEnforceCpuid else cfg.stealth.kvmPvEnforceCpuid;
            smbiosTables = pkgs.smbios-stealth-tables.override {
              # Per-VM cache (CCD-specific L3) overrides the host-wide default when set.
              cacheL1 = if vmCfg.cache.l1 != null then vmCfg.cache.l1 else cfg.stealth.smbios.cache.l1;
              cacheL2 = if vmCfg.cache.l2 != null then vmCfg.cache.l2 else cfg.stealth.smbios.cache.l2;
              cacheL3 = if vmCfg.cache.l3 != null then vmCfg.cache.l3 else cfg.stealth.smbios.cache.l3;
              cacheAssocL1 =
                if vmCfg.cache.assocL1 != null then vmCfg.cache.assocL1 else cfg.stealth.smbios.cache.assocL1;
              cacheAssocL2 =
                if vmCfg.cache.assocL2 != null then vmCfg.cache.assocL2 else cfg.stealth.smbios.cache.assocL2;
              cacheAssocL3 =
                if vmCfg.cache.assocL3 != null then vmCfg.cache.assocL3 else cfg.stealth.smbios.cache.assocL3;
              cacheEcc = if vmCfg.cache.ecc != null then vmCfg.cache.ecc else cfg.stealth.smbios.cache.ecc;
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
                managed = vmCfg.gpu.libvirtManaged;
                source.address = parsePciAddr vmCfg.gpu.pciAddress;
                rom = {
                  bar = vmCfg.gpu.romBar;
                }
                // lib.optionalAttrs (vmCfg.gpu.romFile != null) { file = vmCfg.gpu.romFile; };
              }
            ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [
              {
                mode = "subsystem";
                type = "pci";
                managed = vmCfg.gpu.libvirtManaged;
                source.address = parsePciAddr vmCfg.gpu.audioAddress;
              }
            ]
            ++ lib.map (addr: {
              mode = "subsystem";
              type = "pci";
              managed = vmCfg.gpu.libvirtManaged;
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
            # profile switches. SMM + secure pflash (required for SB enforcement) are
            # injected via qemu:commandline when ovmf.secureBoot is true.
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
            ]
            ++ lib.genList (i: {
              type = "pci";
              index = i + 1;
              model = "pcie-root-port";
            }) (lib.length gpuHostdevs + lib.length extraPciHostdevs + 2)
            ++ [
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
              ++ (lib.optionals cfg.evdev.enable (
                lib.concatLists (
                  lib.imap0 (i: path: [
                    { value = "-object"; }
                    { value = "input-linux,id=kbd${toString (i + 1)},evdev=${path},grab_all=on"; }
                  ]) cfg.evdev.extraKeyboardPaths
                )
              ))
              ++ (lib.optionals (cfg.evdev.enable && cfg.evdev.mousePath != null) [
                { value = "-object"; }
                { value = "input-linux,id=mouse,evdev=${cfg.evdev.mousePath}"; }
              ])
              ++ (lib.map (a: { value = a; }) vmCfg.extraQemuArgs)
              ++ (lib.optionals (vmCfg.os.firmware == "uefi" && cfg.ovmf.secureBoot) [
                { value = "-machine"; }
                { value = "smm=on"; }
                { value = "-global"; }
                { value = "driver=cfi.pflash01,property=secure,value=on"; }
              ]);
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
                  ++ lib.optional (vmCfg.gpu.dynamicBind && vmCfg.gpu.libvirtManaged) {
                    assertion = false;
                    message = "myModules.vfio.vms.${name}.gpu: dynamicBind and libvirtManaged are mutually exclusive — dynamicBind binds vfio-pci in the qemu prepare hook (managed='no'), libvirtManaged lets libvirt bind/rebind it (managed='yes'). Pick one.";
                  }
                  ++
                    lib.optional
                      (vmCfg.gpu.mode == "passthrough" && !vmCfg.gpu.dynamicBind && !vmCfg.gpu.libvirtManaged)
                      {
                        assertion = cfg.bindMethod == "static";
                        message = "myModules.vfio.vms.${name}: gpu.mode=\"passthrough\" requires myModules.vfio.bindMethod=\"static\" — set gpu.dynamicBind=true to bind it at VM start via the qemu hook, gpu.libvirtManaged=true to let libvirt bind/rebind it, or bindMethod=\"static\" to capture it at boot via vfio-pci.ids.";
                      }
                  ++
                    lib.optional
                      (
                        vmCfg.gpu.mode == "passthrough"
                        && !vmCfg.gpu.dynamicBind
                        && !vmCfg.gpu.libvirtManaged
                        && cfg.bindMethod == "static"
                      )
                      {
                        assertion = vmCfg.gpu.staticIds != [ ];
                        message = "myModules.vfio.vms.${name}.gpu.staticIds: must be non-empty under bindMethod=\"static\" — these vendor:device IDs are captured at boot via vfio-pci.ids (e.g. [\"1002:7550\" \"1002:ab40\"]). Without them the GPU is never bound to vfio-pci and the VM fails to start.";
                      }
                  ++ lib.optional (vmCfg.gpu.bar2ResizeMB != null) {
                    assertion = vmCfg.gpu.dynamicBind;
                    message = "myModules.vfio.vms.${name}.gpu.bar2ResizeMB requires gpu.dynamicBind=true -- the resize runs in the no-driver window between the host-driver unbind and the vfio-pci bind, which only the dynamic prepare hook provides.";
                  }
                  ++
                    lib.optional
                      (
                        vmCfg.gpu.bar2ResizeMB != null
                        && builtins.bitAnd vmCfg.gpu.bar2ResizeMB (vmCfg.gpu.bar2ResizeMB - 1) != 0
                      )
                      {
                        assertion = false;
                        message = "myModules.vfio.vms.${name}.gpu.bar2ResizeMB=${toString vmCfg.gpu.bar2ResizeMB} must be a power of 2 (PCI BAR sizes are 2^n MiB; e.g. 8 or 256).";
                      }
                ) enabledVms
              )
              ++ mkProtectedDiskAssertions cfg.protectedDiskAddrs
              ++ lib.optional (cfg.cpuPin.dynamic && cfg.cpuPin.threads <= 0) {
                assertion = false;
                message = "myModules.vfio.cpuPin.dynamic requires cpuPin.threads > 0 -- it computes each VM's host-core confinement as [0..threads-1] minus that VM's vcpu.pinning. Set cpuPin.threads to the host's total hardware thread count.";
              }
              # Cross-VM invariants for a profile where >1 VM can run AT ONCE. cpuPin.dynamic
              # carries the one-VM-at-a-time prepare-hook guard, so it EXEMPTS these (vfio-dynamic
              # enables both VMs but only ever runs one). A both-at-once profile (no dynamic guard)
              # must reserve per-VM hugepages + distinct serials + disjoint cores up front.
              ++
                lib.optional
                  (
                    !cfg.cpuPin.dynamic
                    && cfg.hugepages.enable
                    && !cfg.hugepages.bootStatic
                    && lib.length (lib.attrNames enabledVms) > 1
                  )
                  {
                    assertion = false;
                    message = "myModules.vfio: ${toString (lib.length (lib.attrNames enabledVms))} VMs are enabled and can run at once (no cpuPin.dynamic one-at-a-time guard), but hugepages.bootStatic=false -- the per-VM dynamic hook shares ONE sysfs pool, so a second VM's start resizes it and the first VM's stop frees it under the still-running guest. Set hugepages.bootStatic=true (count = the sum of every VM's pages).";
                  }
              ++
                lib.optional
                  (
                    !cfg.cpuPin.dynamic
                    && cfg.stealth.enable
                    && !cfg.perVmStealthSerials
                    && lib.length (lib.attrNames enabledVms) > 1
                  )
                  {
                    assertion = false;
                    message = "myModules.vfio: ${toString (lib.length (lib.attrNames enabledVms))} VMs can run at once under stealth but perVmStealthSerials=false -- both domains present identical SMBIOS system + baseboard serials, a fidelity tell for co-running guests. Set perVmStealthSerials=true.";
                  }
              ++ (
                let
                  coRunPins = lib.concatLists (
                    lib.mapAttrsToList (_: v: if v.vcpu.pinning != null then v.vcpu.pinning else [ ]) enabledVms
                  );
                in
                lib.optional (!cfg.cpuPin.dynamic && lib.length coRunPins != lib.length (lib.unique coRunPins)) {
                  assertion = false;
                  message = "myModules.vfio: two enabled VMs that can run at once pin the same host CPU core in vcpu.pinning -- co-running VMs must own disjoint cores. Give each a non-overlapping set.";
                }
              )
              ++ lib.optionals cfg.cpuPin.dynamic (
                lib.concatLists (
                  lib.mapAttrsToList (
                    vmName: vmCfg:
                    lib.optionals (vmCfg.vcpu.pinning != null) [
                      {
                        assertion = cfg.cpuPin.threads > lib.foldl' lib.max 0 vmCfg.vcpu.pinning;
                        message = "myModules.vfio.cpuPin.threads (${toString cfg.cpuPin.threads}) must exceed the highest core in ${vmName}.vcpu.pinning -- otherwise the dynamic host-core complement silently drops real cores.";
                      }
                      {
                        assertion = lib.subtractLists vmCfg.vcpu.pinning (lib.range 0 (cfg.cpuPin.threads - 1)) != [ ];
                        message = "${vmName}.vcpu.pinning leaves no host cores under cpuPin.dynamic (it pins every core in [0..threads-1]); the host would be confined to an empty CPU set. Leave at least one core unpinned.";
                      }
                    ]
                  ) enabledVms
                )
              );
          }

          # ── NixVirt declarative VM definitions ──
          (lib.mkIf (enabledVms != { }) {
            virtualisation.libvirt = {
              enable = true;
              swtpm.enable = true;
              # active=true ⇒ NixVirt starts the domain (autostart profiles, vfio-both).
              # null ⇒ leave it defined-but-stopped (single-VM profiles: the user
              # starts it by hand after login).
              connections."qemu:///system".domains = lib.mapAttrsToList (name: vmCfg: {
                definition = inputs.NixVirt.lib.domain.writeXML (mkDomainDef name vmCfg);
                active = if cfg.autostart then true else null;
              }) enabledVms;
            };

            # Set the per-domain libvirt autostart flag to match cfg.autostart: enabled
            # so libvirtd brings both VMs up at boot (vfio-both), disabled otherwise so a
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
