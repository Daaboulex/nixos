{ inputs, ... }: {
  flake.nixosModules.tools-iommu = { config, lib, pkgs, ... }:
    let
      cfgTools = config.myModules.tools;

      # ════════════════════════════════════════════════════════════════════════
      # list-iommu-groups — Show IOMMU group assignments
      # ════════════════════════════════════════════════════════════════════════
      list-iommu-groups = pkgs.writeShellApplication {
        name = "list-iommu-groups";
        runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.pciutils ];
        text = ''#!${pkgs.bash}/bin/bash
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
    in {
      options.myModules.tools.listIommuGroups.enable = lib.mkEnableOption "list-iommu-groups";

      config = lib.mkIf cfgTools.listIommuGroups.enable {
        environment.systemPackages = [ list-iommu-groups ];
      };
    };
}
