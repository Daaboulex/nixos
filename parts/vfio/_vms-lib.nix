# _vms-lib — pure helpers used by parts/vfio/vms.nix (PCI parsing, MAC
# generation, display probing, hugepage sysfs path). Separated so vms.nix
# can focus on hook + domain generation. Underscore prefix keeps this
# out of the flake-parts auto-discovery.
#
# Inputs: `lib`, `config`, `cfg` (= config.myModules.vfio). Call via:
#   helpers = import ./_vms-lib.nix { inherit lib config cfg; };
{
  lib,
  config,
  cfg,
}:
let
  # Parse PCI address string "0000:03:00.0" into integers for NixVirt.
  # Nix has no native hex parser, so we convert manually.
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

  hexToInt = s: lib.foldl (acc: c: acc * 16 + hexChars.${c}) 0 (lib.stringToCharacters s);

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

  # Validate a PCI address is well-formed DDDD:BB:DD.F. Catches placeholders
  # and malformed entries at eval time, before they reach the hook or QEMU.
  # Domain pinned to 0000 — parsePciAddr hardcodes domain=0, so anything else
  # would silently mis-parse. Reject it at eval time instead.
  isValidPciAddr = addr: builtins.match "0000:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" addr != null;

  # Generate deterministic MAC from prefix + VM name hash (so a VM keeps
  # the same MAC across rebuilds even without explicit config).
  generateMac =
    prefix: name:
    let
      hash = builtins.hashString "sha256" name;
      hexCharList = lib.stringToCharacters hash;
      b1 = lib.concatStrings (lib.sublist 0 2 hexCharList);
      b2 = lib.concatStrings (lib.sublist 2 2 hexCharList);
      b3 = lib.concatStrings (lib.sublist 4 2 hexCharList);
    in
    "${prefix}:${b1}:${b2}:${b3}";

  enabledVms = lib.filterAttrs (_: v: v.enable) cfg.vms;

  # Sysfs path for dynamic hugepage allocation (1G vs 2M backing).
  hugepageSysfsPath =
    if cfg.hugepages.size == "1G" then
      "/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"
    else
      "/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages";

  # --- Shell-script helpers embedded into hook output ---

  # Check if a PCI device has active DRM connectors (displays attached
  # and enabled). Returns 0 if the device has at least one active conn.
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

  # Find any OTHER GPU (not the one being passed through) that has
  # active displays — used to decide whether it's safe to release the
  # passthrough GPU (need at least one other GPU driving displays).
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
in
{
  inherit
    parsePciAddr
    isValidPciAddr
    generateMac
    enabledVms
    hugepageSysfsPath
    hasActiveDisplay
    hasFallbackDisplay
    ;
}
