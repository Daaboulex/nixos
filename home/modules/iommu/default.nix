# iommu — helper script that lists IOMMU groups for PCI passthrough planning.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.iommu;

  list-iommu-groups = pkgs.writeShellApplication {
    name = "list-iommu-groups";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.pciutils
    ];
    text = ''
      set -euo pipefail
      echo "=== IOMMU Groups ==="
      shopt -s nullglob
      for g in /sys/kernel/iommu_groups/*; do
        echo "Group $(basename "$g"):"
        for d in "$g"/devices/*; do
          echo -n "  "
          lspci -nns "$(basename "$d")"
        done
      done
    '';
  };
in
{
  options.myModules.home.iommu = {
    enable = lib.mkEnableOption "IOMMU group listing tool";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ list-iommu-groups ];
  };
}
