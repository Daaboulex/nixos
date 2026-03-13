{ inputs, ... }:
{
  flake.overlays.default = _final: prev: {
    # Stealth QEMU — anti-detection patches for VM passthrough
    # Source: Scrut1ny/Hypervisor-Phantom AMD QEMU patch (targets QEMU 10.2.x)
    # postPatch: replace patch's generic hardcoded values with real hardware identifiers
    # so our fingerprint is unique — not the same as every other Hypervisor-Phantom user
    qemu-stealth =
      (prev.qemu.override {
        hostCpuOnly = true;
      }).overrideAttrs
        (old: {
          pname = "qemu-stealth";
          patches = (old.patches or [ ]) ++ [
            "${inputs.hypervisor-phantom}/patches/QEMU/AMD-v10.2.0.patch"
          ];
          postPatch = (old.postPatch or "") + ''
            echo "=== Customizing stealth QEMU with unique hardware identifiers ==="

            # EDID: patch defaults to MSI G27C4X — replace with real monitor (Dell AW2521HFA)
            sed -i 's|"MSI     "|"DEL     "|g' hw/display/edid-generate.c
            sed -i 's|"MSI"|"DEL"|g' hw/display/edid-generate.c
            sed -i 's|"MSI TARGET      "|"DEL AW2521HFA   "|g' hw/display/edid-generate.c
            sed -i 's|"G27C4X"|"AW2521HFA"|g' hw/display/edid-generate.c
            sed -i 's|0x10ad|0xa161|g' hw/display/edid-generate.c
            # EDID manufacture week/year: patch uses week=12 year=2025-2018(=7), real=week 18 year 2021
            sed -i 's|edid\[16\] = 12;|edid[16] = 18;|g' hw/display/edid-generate.c
            sed -i 's|2025 - 2018|2021 - 1990|g' hw/display/edid-generate.c
            # EDID DPI: patch uses 82, real Dell monitors are ~102
            sed -i 's|uint32_t dpi = 82;|uint32_t dpi = 102;|g' hw/display/edid-generate.c

            # ACPI OEM: patch uses ALASKA/AMI — use ASUS-specific strings
            # These defines are in include/hw/acpi/aml-build.h (6-char and 8-char padded)
            sed -i 's|"ALASKA"|"ASUS  "|g' include/hw/acpi/aml-build.h
            sed -i 's|"A M I   "|"ASUS    "|g' include/hw/acpi/aml-build.h

            # BIOS version: patch has no specific version, ensure ours matches real ASUS
            # (SMBIOS injection via domain XML handles the main BIOS strings)

            # Disk model: patch uses "Hitachi HMS360404D5CF00" — replace with common Samsung model
            sed -i 's|Hitachi HMS360404D5CF00|Samsung SSD 870 EVO 1TB |g' hw/ide/core.c hw/scsi/scsi-disk.c 2>/dev/null || true

            # Optical drive: patch uses "HL-DT-ST BD-RE WH16NS60" — use ASUS drive
            sed -i 's|HL-DT-ST BD-RE WH16NS60|ASUS DRW-24B1ST   c    |g' hw/ide/core.c hw/ide/atapi.c 2>/dev/null || true

            echo "=== Stealth customization complete ==="
          '';
        });
  };
}
