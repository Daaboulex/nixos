# List GPU Drivers - diagnostic tool
{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.tools.listGpuDrivers;

  list-gpu-drivers = pkgs.writeShellApplication {
    name = "list-gpu-drivers";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.pciutils pkgs.gnugrep pkgs.gawk pkgs.gnused ];
    checkPhase = ''
      $out/bin/list-gpu-drivers --version || true
    '';
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      if [[ "$#" -gt 0 && "$1" == "--version" ]]; then echo "list-gpu-drivers 1.4"; exit 0; fi
      echo "--- GPU Devices and Associated Functions ---"; echo "(Display Controllers [Class 03xx] and related functions)"; echo ""
      LSPCI_CMD="lspci"; GREP_CMD="grep"; AWK_CMD="awk"; SORT_CMD="sort"; SED_CMD="sed"
      command -v "$LSPCI_CMD" >/dev/null || { echo "ERROR: lspci not found." >&2; exit 1; }
      command -v "$GREP_CMD" >/dev/null || { echo "ERROR: grep not found." >&2; exit 1; }
      command -v "$AWK_CMD" >/dev/null || { echo "ERROR: awk not found." >&2; exit 1; }
      command -v "$SORT_CMD" >/dev/null || { echo "ERROR: sort not found." >&2; exit 1; }
      command -v "$SED_CMD"  >/dev/null || { echo "ERROR: sed not found."  >&2; exit 1; }
      display_controller_ids=$($LSPCI_CMD -nn | $GREP_CMD -E '\\[03[0-9a-fA-F]{2}\\]:' | $AWK_CMD '{print $1}' || true)
      if [ -z "$display_controller_ids" ]; then echo "No Display Controller devices (Class 03xx) found."; echo "--- End of GPU Devices ---"; exit 0; fi
      unique_base_addresses=$(echo "$display_controller_ids" | $AWK_CMD -F '[.:]' '{ if (NF==4) { print $1":"$2":"$3 } else if (NF==3) { print $1":"$2 } }' | $SORT_CMD -u)
      [ -z "$unique_base_addresses" ] && { echo "ERROR: Could not extract base addresses." >&2; exit 1; }
      echo "Found GPU base addresses: $unique_base_addresses"; echo ""
      processed_bases=""; echo "$unique_base_addresses" | while IFS= read -r base_address; do
        if echo "$processed_bases" | $GREP_CMD -q -F -x "$base_address"; then continue; fi
        echo "--- Devices Card/Group at Base Address: $base_address ---"
        devices_info=$($LSPCI_CMD -s "$base_address." -nnk 2>/dev/null) || { echo "  WARN: Could not get lspci info for base $base_address."; processed_bases+="$base_address"$'\n'; echo ""; continue; }
        [ -z "$devices_info" ] && { echo "  WARN: No info for base $base_address."; processed_bases+="$base_address"$'\n'; echo ""; continue; }
        echo "$devices_info" | $AWK_CMD '
          function print_device_info(){ if (current_pci != "") { printf "  Device:   %s %s\n", current_pci, description; if (vendor_device != "") { printf "  VendorID: %s\n", vendor_device; } if (class_code != "") { printf "  ClassID:  %s\n", class_code; } if (driver_in_use != "") { printf "  Driver:   %s\n", driver_in_use; } else if (kernel_modules != "") { printf "  Driver:   (None in use, modules: %s)\n", kernel_modules; } else { printf "  Driver:   (None Found / Not Applicable)\n"; } printf "\n"; } current_pci=""; vendor_device=""; class_code=""; description=""; driver_in_use=""; kernel_modules=""; }
          BEGIN { current_pci=""; }
          /^[0-9a-fA-F.:]+ / { print_device_info(); current_pci=$1; if (match($0, /\[([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\]/)) { vendor_device=substr($0, RSTART, RLENGTH); } if (match($0, /\[([0-9a-fA-F]{4})\]:/)) { class_code=substr($0, RSTART, RLENGTH); } description=substr($0, index($0,$2)); }
          /Kernel driver in use:/ { if (current_pci != "") { driver_in_use=$NF; } }
          /Kernel modules:/ { if (current_pci != "") { kernel_modules=$NF; if (driver_in_use == "") driver="(None)"; } }
          END { print_device_info(); }
        '
        processed_bases+="$base_address"$'\n'
      done
      echo "--- End of GPU Devices ---"; exit 0
    '';
  };
in {
  options.myModules.tools.listGpuDrivers = {
    enable = lib.mkEnableOption "list-gpu-drivers diagnostic tool";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ list-gpu-drivers ];
  };
}