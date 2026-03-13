{ inputs, ... }:
{
  flake.nixosModules.iommu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules;

      # list-iommu-groups — Show IOMMU group assignments
      list-iommu-groups = pkgs.writeShellApplication {
        name = "list-iommu-groups";
        runtimeInputs = [
          pkgs.bash
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
      _class = "nixos";
      options.myModules.iommu = lib.mkEnableOption "IOMMU group listing tool";

      config = lib.mkIf cfg.iommu {
        environment.systemPackages = [ list-iommu-groups ];
      };
    };
}
