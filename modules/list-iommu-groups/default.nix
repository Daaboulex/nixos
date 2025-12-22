# List IOMMU Groups - diagnostic tool for VFIO passthrough
{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.tools.listIommuGroups;

  list-iommu-groups = pkgs.writeShellApplication {
    name = "list-iommu-groups";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.pciutils ];
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      shopt -s nullglob
      echo "--- IOMMU Groups ---"
      if [ ! -d /sys/kernel/iommu_groups ] || [ ! -r /sys/kernel/iommu_groups ]; then echo "ERROR: Cannot access /sys/kernel/iommu_groups" >&2; exit 1; fi
      command -v lspci >/dev/null || { echo "ERROR: lspci not found." >&2; exit 1; }
      for group_dir in /sys/kernel/iommu_groups/*; do
        if [ -d "$group_dir" ]; then
          group_id=$(basename "$group_dir"); echo ""; echo "IOMMU Group $group_id:"; found_device=false
          for device_link in "$group_dir"/devices/*; do
            if [ -L "$device_link" ]; then device_id=$(basename "$device_link"); device_info=$(lspci -nns "$device_id" 2>/dev/null || echo "  Error reading device $device_id");
              if [[ -n "$device_info" ]]; then echo -e "\t$device_info"; found_device=true; fi
            fi
          done
          if ! $found_device; then echo -e "\t(No devices found in this group or error reading devices)"; fi
        fi
      done
      echo ""; echo "--- End of IOMMU Groups ---"; exit 0
    '';
  };
in {
  options.myModules.tools.listIommuGroups = {
    enable = lib.mkEnableOption "list-iommu-groups diagnostic tool for VFIO passthrough";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ list-iommu-groups ];
  };
}