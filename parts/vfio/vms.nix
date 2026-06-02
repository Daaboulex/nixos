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
        isValidPciAddr
        generateMac
        enabledVms
        hugepageSysfsPath
        hasActiveDisplay
        hasFallbackDisplay
        ;

      # Runtime safety guard injected into the hook: refuses to pass a PCI
      # device whose block devices back a critical host filesystem
      # (/, /boot, /nix, or swap — resolved through LUKS/dm). Prevents handing
      # the live host disk to a guest if a PCI address is wrong or stale
      # (e.g. after a bus renumber from adding a card).
      protectedDiskGuard = ''
        vfio_guard_protected_disk() {
          local pci_addr="$1" crit src cand target
          # Physical disks backing host-critical filesystems + disk swap.
          # --nofsroot strips btrfs subvol suffixes (e.g. cryptroot[/@]) that
          # would otherwise make lsblk fail and silently empty the list.
          crit=$(
            {
              for m in / /boot /nix /nix/store /home; do
                src=$(${pkgs.util-linux}/bin/findmnt -no SOURCE --nofsroot "$m" 2>/dev/null) || continue
                [ -n "$src" ] && ${pkgs.util-linux}/bin/lsblk -nso NAME "$src" 2>/dev/null
              done
              ${pkgs.util-linux}/bin/swapon --show=NAME --noheadings 2>/dev/null | while read -r sw; do
                ${pkgs.util-linux}/bin/lsblk -nso NAME "$sw" 2>/dev/null
              done
            } | grep -oE 'nvme[0-9]+n[0-9]+|sd[a-z]+|mmcblk[0-9]+' | sort -u
          )
          # / always resolves on a booted host; if it doesn't, the resolver is
          # broken — fail closed rather than trust a partial critical-disk set.
          if ! ${pkgs.util-linux}/bin/findmnt -no SOURCE --nofsroot / >/dev/null 2>&1; then
            log "[$GUEST_NAME] SAFETY ABORT: cannot resolve root filesystem — refusing passthrough of $pci_addr."
            return 0
          fi
          # Fail closed: if critical disks can't be resolved, refuse rather than
          # risk handing the host disk to a guest.
          if [ -z "$crit" ]; then
            log "[$GUEST_NAME] SAFETY ABORT: could not determine host-critical disks — refusing passthrough of $pci_addr."
            return 0
          fi
          # Every block device behind this PCI address (NVMe, SATA, eMMC, …).
          for blk in /sys/block/*; do
            [ -e "$blk/device" ] || continue
            target="$(readlink -f "$blk/device" 2>/dev/null)"
            case "$target" in
              *"/$pci_addr/"*)
                cand="$(basename "$blk")"
                if echo "$crit" | grep -qx "$cand"; then
                  log "[$GUEST_NAME] SAFETY ABORT: $pci_addr ($cand) backs a critical host filesystem (/, /boot, /nix, /home, or swap) — refusing passthrough. Re-verify the device with the inspection script."
                  return 0
                fi
                ;;
            esac
          done
          return 1
        }
      '';

      mkVmHookSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
            ++ vmCfg.gpu.extraFunctions
          );
          pciAddrs = vmCfg.pciPassthrough;
          mounts = vmCfg.mountsToUnmount;
          gpuAddrList = lib.concatStringsSep " " gpuAddrs;
          allAddrList = lib.concatStringsSep " " (gpuAddrs ++ pciAddrs);
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            # ══════════════════════════════════════════════════════════════
            # Phase 1 — Validate (no mutations, safe to abort)
            # ══════════════════════════════════════════════════════════════

            # --- SAFETY: refuse to pass any device backing a host filesystem ---
            for pci_addr in ${allAddrList}; do
              if vfio_guard_protected_disk "$pci_addr"; then exit 1; fi
            done

            ${lib.optionalString (gpuAddrs != [ ]) ''
              # --- Safety check: verify fallback display exists ---
              if ! vfio_has_fallback_display ${gpuAddrList}; then
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
              for pci_addr in ${gpuAddrList}; do
                for drm_node in /sys/bus/pci/devices/"$pci_addr"/drm/card* /sys/bus/pci/devices/"$pci_addr"/drm/renderD*; do
                  [ -d "$drm_node" ] || continue
                  node_name=$(basename "$drm_node")
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
            ''}
            ${lib.optionalString (mounts != [ ] || pciAddrs != [ ]) ''
              # --- Check for open files on mount points (check only, no unmount) ---
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

            # ══════════════════════════════════════════════════════════════
            # Phase 2 — Mutate (cleanup trap active, inhibit wrapping)
            # ══════════════════════════════════════════════════════════════

            # --- Vendor-aware driver lookup (4-tier) ---
            # Used by cleanup trap and stuck recovery. Resolves the correct host
            # driver for a PCI address without depending on a single global option.
            _vfio_resolve_host_driver() {
              local pci_addr="$1"
              local safe_addr
              safe_addr="$(echo "$pci_addr" | tr ':.' '_')"
              # Tier 1: state file persisted before unbind
              if [ -f "/run/vfio-hook/${name}/$safe_addr.driver" ]; then
                cat "/run/vfio-hook/${name}/$safe_addr.driver"
                return
              fi
              # Tier 2: per-VM hostDriver option (if set)
              ${lib.optionalString (vmCfg.gpu.hostDriver != null) ''
                echo "${vmCfg.gpu.hostDriver}"
                return
              ''}
              # Tiers 3+4 are emitted ONLY when no per-VM hostDriver is set.
              # Otherwise Tier 2 above ends in an unconditional `return`, which makes
              # these unreachable — and shellcheck (SC2317) correctly fails the build.
              # Emitting them conditionally keeps both generated variants dead-code-free
              # rather than suppressing the check.
              ${lib.optionalString (vmCfg.gpu.hostDriver == null) ''
                # Tier 3: PCI vendor ID heuristic
                if [ -f "/sys/bus/pci/devices/$pci_addr/vendor" ]; then
                  local vendor
                  vendor="$(cat "/sys/bus/pci/devices/$pci_addr/vendor")"
                  case "$vendor" in
                    0x10de) echo "nouveau"; return ;;
                    0x1002) echo "amdgpu"; return ;;
                    0x8086) echo "i915"; return ;;
                  esac
                fi
                # Tier 4: global fallback
                echo "${cfg.hostGpuDriver}"
              ''}
            }

            # --- Cleanup trap: reverses all Phase 2 mutations on failure ---
            _vfio_cleanup() {
              log "[$GUEST_NAME] CLEANUP: prepare hook failed, reversing mutations..."
              # Release the sleep/shutdown inhibitor if the mutate phase armed it.
              [ -n "''${_inhibit_pid:-}" ] && kill "$_inhibit_pid" 2>/dev/null || true
              ${lib.optionalString cfg.hugepages.enable ''
                echo 0 > ${hugepageSysfsPath} 2>/dev/null || true
                log "[$GUEST_NAME] CLEANUP: hugepages freed"
              ''}
              ${lib.optionalString (mounts != [ ]) ''
                ${lib.concatMapStringsSep "\n" (mp: ''
                  ${pkgs.util-linux}/bin/mount "${mp}" 2>/dev/null || true
                '') mounts}
                log "[$GUEST_NAME] CLEANUP: filesystems remounted"
              ''}
              ${lib.optionalString (gpuAddrs != [ ]) ''
                # Restore GPU to host driver if currently on vfio-pci
                for pci_addr in ${gpuAddrList}; do
                  current_drv=$(basename "$(readlink "/sys/bus/pci/devices/$pci_addr/driver")" 2>/dev/null || echo "none")
                  if [ "$current_drv" = "vfio-pci" ]; then
                    echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
                    echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override" 2>/dev/null || true
                    echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
                    sleep 2
                    host_drv=$(_vfio_resolve_host_driver "$pci_addr")
                    echo "$pci_addr" > "/sys/bus/pci/drivers/$host_drv/bind" 2>/dev/null || true
                    log "[$GUEST_NAME] CLEANUP: $pci_addr restored to $host_drv"
                  fi
                done
                ${lib.optionalString vmCfg.gpu.releaseConsole ''
                  # Restore VT consoles + EFI framebuffer
                  for vtcon in /sys/class/vtconsole/vtcon*/bind; do
                    [ -f "$vtcon" ] && echo 1 > "$vtcon" 2>/dev/null || true
                  done
                  if [ -d /sys/bus/platform/drivers/efi-framebuffer ]; then
                    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null || true
                  fi
                  ${pkgs.kbd}/bin/chvt 1 2>/dev/null || true
                  log "[$GUEST_NAME] CLEANUP: consoles + framebuffer restored"
                ''}
                # Restart PowerDevil
                ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true
                ${lib.optionalString cfg.restrictScxToHost ''
                  # Restore scx scheduler to all cores
                  ${pkgs.systemd}/bin/systemctl unset-environment SCX_FLAGS_OVERRIDE 2>/dev/null || true
                  ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
                ''}
              ''}
              rm -rf "/run/vfio-hook/${name}"
              log "[$GUEST_NAME] CLEANUP: done"
            }
            trap _vfio_cleanup EXIT

            ${lib.optionalString (gpuAddrs != [ ]) ''
              # --- Persist original GPU drivers before unbind ---
              mkdir -p "/run/vfio-hook/${name}"
              for pci_addr in ${gpuAddrList}; do
                orig=$(basename "$(readlink "/sys/bus/pci/devices/$pci_addr/driver")" 2>/dev/null || echo "none")
                safe_addr="$(echo "$pci_addr" | tr ':.' '_')"
                echo "$orig" > "/run/vfio-hook/${name}/$safe_addr.driver"
              done
            ''}

            # Hold a sleep/shutdown inhibitor across the whole mutate phase. A
            # child `bash -c` would lose the hook's log()/_vfio_resolve_host_driver()
            # functions and $GUEST_NAME (none are exported), so hold the lock in a
            # background process and run the mutations INLINE in this shell.
            # Released at the end of the mutate phase + in _vfio_cleanup on abort.
            ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:shutdown \
              --who=vfio-hook --why="GPU passthrough bind/unbind for $GUEST_NAME" \
              --mode=block sleep infinity &
            _inhibit_pid=$!
              ${lib.optionalString cfg.hugepages.enable ''
                # --- Allocate hugepages for VM memory ---
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
              ${lib.optionalString (mounts != [ ] || pciAddrs != [ ]) ''
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
                for pci_addr in ${gpuAddrList}; do
                  current_driver=$(basename "$(readlink "/sys/bus/pci/devices/$pci_addr/driver")" 2>/dev/null || echo "none")
                  if [ "$current_driver" = "vfio-pci" ]; then
                    log "[$GUEST_NAME] $pci_addr stuck on vfio-pci from previous run, recovering..."
                    echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
                    sleep 2
                    echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override"
                    host_drv=$(_vfio_resolve_host_driver "$pci_addr")
                    echo "$pci_addr" > "/sys/bus/pci/drivers/$host_drv/bind" 2>/dev/null || true
                    sleep 2
                    log "[$GUEST_NAME] $pci_addr recovered to $host_drv"
                  fi
                done

                # --- Stop services that hold GPU file descriptors ---
                # PowerDevil binds to GPU i2c bus (DDC brightness) and blocks driver unbind
                ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop plasma-powerdevil.service 2>/dev/null || true
                sleep 1

                ${lib.optionalString cfg.restrictScxToHost ''
                  # Restrict scx scheduler to host-only cores (CCD1) during VM.
                  if ${pkgs.systemd}/bin/systemctl is-active scx.service >/dev/null 2>&1; then
                    log "[$GUEST_NAME] restricting scx scheduler to host cores (mask ${cfg.hostCpuMask})"
                    ${pkgs.systemd}/bin/systemctl set-environment SCX_FLAGS_OVERRIDE="-m ${cfg.hostCpuMask}" 2>/dev/null || true
                    ${pkgs.systemd}/bin/systemctl restart scx.service 2>/dev/null || true
                  fi
                ''}

                ${lib.optionalString vmCfg.gpu.releaseConsole ''
                  # Single-GPU passthrough path: release console handles before driver unbind.
                  log "[$GUEST_NAME] switching to VT3 for safe GPU unbind"
                  ${pkgs.kbd}/bin/chvt 3
                  sleep 2

                  log "[$GUEST_NAME] unbinding VT consoles"
                  for vtcon in /sys/class/vtconsole/vtcon*/bind; do
                    [ -f "$vtcon" ] && echo 0 > "$vtcon" 2>/dev/null || true
                  done

                  if [ -d /sys/bus/platform/drivers/efi-framebuffer ]; then
                    log "[$GUEST_NAME] unbinding EFI framebuffer"
                    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
                  fi

                  # Race condition avoidance: KWin + GPU driver + framebuffer need time to
                  # fully release DRM handles. 8s is conservative; tested: 5s too short, 10s safe.
                  sleep 8
                ''}

                # Unbind GPU from host driver, bind to vfio-pci
                for pci_addr in ${gpuAddrList}; do
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
                      exit 1
                    }
                    log "[$GUEST_NAME] $pci_addr bound to vfio-pci"
                    sleep 2
                  fi
                done

                ${lib.optionalString vmCfg.gpu.releaseConsole ''
                  # Wait for KWin to process GPU removal before switching to graphical VT.
                  sleep 5
                  ${pkgs.kbd}/bin/chvt 1
                ''}

                # Restart PowerDevil (now on iGPU)
                ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true
                log "[$GUEST_NAME] GPU passthrough complete, compositor on iGPU"
              ''}
            # Release the sleep/shutdown inhibitor — mutate phase done.
            kill "$_inhibit_pid" 2>/dev/null || true
            _inhibit_pid=""

            # Success — disarm cleanup trap
            trap - EXIT
          fi
        '';

      mkVmReleaseSection =
        name: vmCfg:
        let
          gpuAddrs = lib.optionals (vmCfg.gpu.mode == "passthrough") (
            [ vmCfg.gpu.pciAddress ]
            ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
            ++ vmCfg.gpu.extraFunctions
          );
          gpuAddrList = lib.concatStringsSep " " gpuAddrs;
          mounts = vmCfg.mountsToUnmount;
        in
        ''
          if [ "$GUEST_NAME" = "${name}" ]; then
            # --- Vendor-aware driver lookup (same 4-tier as prepare hook) ---
            _vfio_resolve_host_driver() {
              local pci_addr="$1"
              local safe_addr
              safe_addr="$(echo "$pci_addr" | tr ':.' '_')"
              # Tier 1: state file persisted during prepare
              if [ -f "/run/vfio-hook/${name}/$safe_addr.driver" ]; then
                cat "/run/vfio-hook/${name}/$safe_addr.driver"
                return
              fi
              # Tier 2: per-VM hostDriver option
              ${lib.optionalString (vmCfg.gpu.hostDriver != null) ''
                echo "${vmCfg.gpu.hostDriver}"
                return
              ''}
              # Tiers 3+4 are emitted ONLY when no per-VM hostDriver is set.
              # Otherwise Tier 2 above ends in an unconditional `return`, which makes
              # these unreachable — and shellcheck (SC2317) correctly fails the build.
              # Emitting them conditionally keeps both generated variants dead-code-free
              # rather than suppressing the check.
              ${lib.optionalString (vmCfg.gpu.hostDriver == null) ''
                # Tier 3: PCI vendor ID heuristic
                if [ -f "/sys/bus/pci/devices/$pci_addr/vendor" ]; then
                  local vendor
                  vendor="$(cat "/sys/bus/pci/devices/$pci_addr/vendor")"
                  case "$vendor" in
                    0x10de) echo "nouveau"; return ;;
                    0x1002) echo "amdgpu"; return ;;
                    0x8086) echo "i915"; return ;;
                  esac
                fi
                # Tier 4: global fallback
                echo "${cfg.hostGpuDriver}"
              ''}
            }

            ${lib.optionalString (gpuAddrs != [ ]) ''
              log "[$GUEST_NAME] releasing GPU back to host"

              # --- Wait for QEMU to fully release devices ---
              sleep 5

              # Stop PowerDevil before GPU rebind
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop plasma-powerdevil.service 2>/dev/null || true

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # Switch to text VT for safe GPU rebind (matches prepare-phase chvt 3).
                ${pkgs.kbd}/bin/chvt 3
                sleep 2
              ''}

              # Unbind from vfio-pci, PCI reset, rebind to host driver
              for pci_addr in ${gpuAddrList}; do
                if [ -d "/sys/bus/pci/devices/$pci_addr" ]; then
                  host_drv=$(_vfio_resolve_host_driver "$pci_addr")
                  log "[$GUEST_NAME] unbinding $pci_addr from vfio-pci (target: $host_drv)"
                  echo "$pci_addr" > /sys/bus/pci/drivers/vfio-pci/unbind || {
                    log "[$GUEST_NAME] WARNING: vfio-pci unbind failed for $pci_addr — attempting force"
                    echo 1 > "/sys/bus/pci/devices/$pci_addr/remove" 2>/dev/null || true
                    sleep 2
                    echo 1 > /sys/bus/pci/rescan
                    sleep 2
                  }
                  echo "" > "/sys/bus/pci/devices/$pci_addr/driver_override" 2>/dev/null || true

                  # PCI function-level reset between vfio-pci unbind and host driver rebind
                  # Clears stale device state left by the guest OS (especially NVIDIA cards).
                  if [ -f "/sys/bus/pci/devices/$pci_addr/reset" ]; then
                    log "[$GUEST_NAME] issuing PCI reset on $pci_addr"
                    echo 1 > "/sys/bus/pci/devices/$pci_addr/reset" 2>/dev/null || {
                      log "[$GUEST_NAME] WARNING: PCI reset failed for $pci_addr (non-fatal)"
                    }
                  fi
                  sleep 2

                  # Rebind to host driver
                  echo "$pci_addr" > "/sys/bus/pci/drivers/$host_drv/bind" 2>/dev/null || {
                    log "[$GUEST_NAME] WARNING: failed to bind $pci_addr to $host_drv — trying PCI rescan"
                    echo 1 > /sys/bus/pci/rescan
                    sleep 2
                  }
                  log "[$GUEST_NAME] $pci_addr rebound to $host_drv"
                  sleep 2
                fi
              done

              log "[$GUEST_NAME] rescanning PCI bus"
              echo 1 > /sys/bus/pci/rescan
              sleep 5

              ${lib.optionalString vmCfg.gpu.releaseConsole ''
                # --- Rebind VT consoles ---
                log "[$GUEST_NAME] rebinding VT consoles"
                for vtcon in /sys/class/vtconsole/vtcon*/bind; do
                  [ -f "$vtcon" ] && echo 1 > "$vtcon" 2>/dev/null || true
                done

                # --- Rebind EFI/simpledrm framebuffer ---
                if [ -d /sys/bus/platform/drivers/efi-framebuffer ]; then
                  log "[$GUEST_NAME] rebinding EFI framebuffer"
                  echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null || true
                fi

                sleep 5
                ${pkgs.kbd}/bin/chvt 1
              ''}

              # Restart PowerDevil (now sees both GPUs)
              ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start plasma-powerdevil.service 2>/dev/null || true

              ${lib.optionalString cfg.restrictScxToHost ''
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
            # Clean up state files
            rm -rf "/run/vfio-hook/${name}"
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

          # Disk-safety guard (refuses passthrough of host-critical disks)
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
            hostDriver = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Override host GPU driver for recovery rebinding. null = auto-detect (0x1002→amdgpu, 0x10de→nouveau, 0x8086→i915). Set to 'nvidia' for proprietary driver.";
              example = "nouveau";
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
          stealth = inputs.vfio-stealth.lib.mkStealthFeatures {
            inherit (cfg.stealth) smbios;
            acpiTables = pkgs.acpi-ssdt-stealth;
            vmUuid = vmCfg.uuid;
            inherit (cfg.stealth) aperfMperf stripVirtio hypervVendorId;
            inherit (cfg.stealth) acpiSsdt;
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
                managed = cfg.bindMethod != "dynamic";
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
                managed = cfg.bindMethod != "dynamic";
                source.address = parsePciAddr vmCfg.gpu.audioAddress;
              }
            ]
            ++ lib.map (addr: {
              mode = "subsystem";
              type = "pci";
              managed = cfg.bindMethod != "dynamic";
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
              ) enabledVms
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
              "d /run/vfio-hook 0755 root root -"
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
