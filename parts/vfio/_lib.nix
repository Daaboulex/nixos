# _lib — the single home for all shared VFIO logic: pure-Nix helpers and the
# shell-snippet builders interpolated into the libvirt hook. Private (underscore
# prefix) → imported by the parts/vfio/* modules, NOT exposed as a flake module,
# so it carries no nixos-exhaustiveness surface. One implementation + one style
# for every concern; the modules that consume it stay thin.
#
#   helpers = import ./_lib.nix { inherit lib config cfg pkgs myLib; };
#
# `cfg` is config.myModules.vfio. `config`/`pkgs` are threaded for the snippet
# builders (pkgs-pinned binaries) and future host-derived helpers.
{
  lib,
  config,
  cfg,
  pkgs,
  myLib,
}:
let
  # ── PCI address parsing ──────────────────────────────────────────────────
  # Nix has no direct hex parser; TOML integers accept 0x literals, so
  # fromTOML is the stdlib route (parsePciAddr's regex guarantees hex input).
  hexToInt = s: (fromTOML "n = 0x${s}").n;

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

  # Well-formedness lives in lib/pci.nix (shared with displays);
  # the domain-0000 pin matches parsePciAddr's hardcoded domain=0.
  inherit (myLib.pci) isValidPciAddr;

  # ── Deterministic per-VM identity (stable across rebuilds, unique per VM) ──
  # All derived from sha256(name) so a VM keeps the same identity without
  # explicit config, and two VMs never collide.
  nameHash = name: builtins.hashString "sha256" name;

  # MAC from a 3-byte OUI prefix + 3 hash-derived bytes. EXACT historical
  # behaviour — existing VMs depend on their generated MAC staying stable.
  generateMac =
    prefix: name:
    let
      h = lib.stringToCharacters (nameHash name);
    in
    "${prefix}:${lib.concatStrings (lib.sublist 0 2 h)}:${lib.concatStrings (lib.sublist 2 2 h)}:${
      lib.concatStrings (lib.sublist 4 2 h)
    }";

  # Plausible SMBIOS/disk serial from a VM name — same role as generateMac for
  # the identity fields the stealth lib treats as host-wide (system serial,
  # baseBoard serial, memory serial). Two simultaneously-running VMs (vfio-both)
  # must NOT share a board/BIOS serial. Uppercase hex of the name hash,
  # truncated to `length`; pass distinct `tag`s for distinct fields of one VM.
  generateSerial =
    tag: name: length:
    lib.concatStrings (
      lib.sublist 0 length (lib.stringToCharacters (lib.toUpper (nameHash "${name}:${tag}")))
    );

  # Per-VM SMBIOS: replace the host-wide system + baseboard serials with
  # name-derived unique ones so two VMs running at once (vfio-both) don't present
  # identical board/BIOS serials — a fidelity tell. Only the serial fields
  # diverge; manufacturer/product/BIOS/cache/memory stay the faithful host
  # values. NOT per-VM here (package-baked / real-device, so already distinct or
  # out of reach): the type-17 DIMM serial is hardcoded in the stealth lib; the
  # disk serial + EDID are baked into qemu-stealth but inert for these VMs (they
  # pass REAL NVMes + drive REAL monitors via the passed GPU, so the guest sees
  # the real device's own serial/EDID, not QEMU's emulated one).
  perVmSmbios =
    smbios: name:
    smbios
    // {
      serial = generateSerial "system" name 12;
      baseBoardSerial = generateSerial "baseboard" name 12;
    };

  # USB vendor/product int → 4-digit lowercase hex, matching sysfs idVendor/idProduct
  # for udev rules (e.g. 4640 → "1220", 2821 → "0b05", 1133 → "046d").
  usbIdHex = n: lib.fixedWidthString 4 "0" (lib.toLower (lib.toHexString n));

  # ── VM-set accessors ─────────────────────────────────────────────────────
  enabledVms = lib.filterAttrs (_: v: v.enable) cfg.vms;
  # VMs this module DECLARES but does not enable in the current profile. A targeted
  # prune undefines these if a prior boot profile defined them, so passthrough domains
  # never leak across profiles — scoped to our own VMs by name (NixVirt's built-in
  # prune is all-or-nothing and would also delete hand-made/emulated VMs).
  disabledVms = lib.filterAttrs (_: v: !v.enable) cfg.vms;

  # The full PCI-address list of a VM's passed GPU (VGA + optional audio +
  # extra functions). Single definition — the hook, release, and domain builders
  # all derive from this.
  gpuAddrsOf =
    vmCfg:
    lib.optionals (vmCfg.gpu.mode == "passthrough") (
      [ vmCfg.gpu.pciAddress ]
      ++ lib.optionals (vmCfg.gpu.audioAddress != null) [ vmCfg.gpu.audioAddress ]
      ++ vmCfg.gpu.extraFunctions
    );

  # Sysfs path for dynamic hugepage allocation (1G vs 2M backing).
  hugepageSysfsPath =
    if cfg.hugepages.size == "1G" then
      "/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"
    else
      "/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages";

  # vendor:device IDs to capture at boot via vfio-pci.ids, collected from the
  # enabled passthrough VMs' declared gpu.staticIds. GPUs only — both dGPUs have
  # collision-free IDs. NEVER feed NVMe IDs here: the two 9100 PROs share
  # 144d:a810 with the host root disk, so NVMe is passed by ADDRESS
  # (managed='yes'), never by id.
  mkStaticPciIds =
    vms:
    lib.unique (
      lib.concatMap (
        v:
        lib.optionals (
          v.enable && v.gpu.mode == "passthrough" && !v.gpu.dynamicBind && !v.gpu.libvirtManaged
        ) v.gpu.staticIds
      ) (lib.attrValues vms)
    );

  # ── Eval-time safety ─────────────────────────────────────────────────────
  # Typo-catcher complementing the runtime protectedDiskGuard: refuse at build
  # time if any enabled VM passes a PCI address declared host-critical. The
  # runtime guard (which resolves live findmnt, robust to BDF renumber) remains
  # the last line of defence.
  mkProtectedDiskAssertions =
    protectedAddrs:
    lib.concatLists (
      lib.mapAttrsToList (
        name: vmCfg:
        map (addr: {
          assertion = !(lib.elem addr protectedAddrs);
          message = "myModules.vfio.vms.${name}: pciPassthrough ${addr} is a declared host-critical disk (protectedDiskAddrs = ${lib.concatStringsSep ", " protectedAddrs}) — refusing passthrough.";
        }) vmCfg.pciPassthrough
      ) enabledVms
    );

  # ── Shell-snippet builders (interpolated into the libvirt qemu hook) ──────

  # Refuse to pass a PCI device whose block devices back a host-critical filesystem
  # (cfg.criticalMounts — / /boot /nix /nix/store /home by default — plus swap), resolved
  # live through LUKS/dm. Fail-closed: if the critical set can't be resolved, abort.
  protectedDiskGuard = ''
    vfio_guard_protected_disk() {
      local pci_addr="$1" crit src cand target
      crit=$(
        {
          for m in ${lib.concatStringsSep " " cfg.criticalMounts}; do
            src=$(${pkgs.util-linux}/bin/findmnt -no SOURCE --nofsroot "$m" 2>/dev/null) || continue
            [ -n "$src" ] && ${pkgs.util-linux}/bin/lsblk -nso NAME "$src" 2>/dev/null
          done
          ${pkgs.util-linux}/bin/swapon --show=NAME --noheadings 2>/dev/null | while read -r sw; do
            ${pkgs.util-linux}/bin/lsblk -nso NAME "$sw" 2>/dev/null
          done
        } | grep -oE 'nvme[0-9]+n[0-9]+|sd[a-z]+|mmcblk[0-9]+' | sort -u
      )
      if ! ${pkgs.util-linux}/bin/findmnt -no SOURCE --nofsroot / >/dev/null 2>&1; then
        log "[$GUEST_NAME] SAFETY ABORT: cannot resolve root filesystem — refusing passthrough of $pci_addr."
        return 0
      fi
      if [ -z "$crit" ]; then
        log "[$GUEST_NAME] SAFETY ABORT: could not determine host-critical disks — refusing passthrough of $pci_addr."
        return 0
      fi
      for blk in /sys/block/*; do
        [ -e "$blk/device" ] || continue
        target="$(readlink -f "$blk/device" 2>/dev/null)"
        case "$target" in
          *"/$pci_addr/"*)
            cand="$(basename "$blk")"
            # Pipe-free here-string, not `echo | grep -q`: under pipefail a
            # producer SIGPIPE on the match would fail OPEN (skip this abort,
            # pass a critical disk through).
            if grep -qx "$cand" <<< "$crit"; then
              log "[$GUEST_NAME] SAFETY ABORT: $pci_addr ($cand) backs a critical host filesystem (/, /boot, /nix, /home, or swap) — refusing passthrough. Re-verify the device with the inspection script."
              return 0
            fi
            ;;
        esac
      done
      return 1
    }
  '';

in
{
  inherit
    hexToInt
    parsePciAddr
    isValidPciAddr
    generateMac
    generateSerial
    perVmSmbios
    usbIdHex
    enabledVms
    disabledVms
    gpuAddrsOf
    hugepageSysfsPath
    mkStaticPciIds
    mkProtectedDiskAssertions
    protectedDiskGuard
    ;
}
