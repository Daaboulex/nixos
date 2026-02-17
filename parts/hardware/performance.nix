{ inputs, ... }: {
  flake.nixosModules.hardware-performance = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.performance;
    in {
      options.myModules.hardware.performance = {
        enable = lib.mkEnableOption "Performance tuning and optimization";
        governor = lib.mkOption { type = lib.types.str; default = "powersave"; description = "CPU frequency governor"; };
        ananicy = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Ananicy"; };
      };

      config = lib.mkIf cfg.enable {
        # ZRAM and sysctl tuning are handled by myModules.cachyos.settings
        # This module only manages CPU governor and process priority (ananicy)

        powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

        services.ananicy = {
          enable = cfg.ananicy;
          package = pkgs.ananicy-cpp;
          rulesProvider = pkgs.ananicy-rules-cachyos_git;
        };
      };
    };
}
