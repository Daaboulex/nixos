{ inputs, ... }: {
  flake.nixosModules.hardware-performance = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.performance;
      cachyosCfg = config.myModules.cachyos.settings;
    in {
      options.myModules.hardware.performance = {
        enable = lib.mkEnableOption "Performance tuning and optimization";
        governor = lib.mkOption { type = lib.types.str; default = "powersave"; description = "CPU frequency governor"; };
        zramPercent = lib.mkOption { type = lib.types.int; default = 75; description = "Percentage of RAM to use for ZRAM swap"; };
        ananicy = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Ananicy"; };
      };

      config = lib.mkIf cfg.enable {
        zramSwap = lib.mkIf (!cachyosCfg.enable) {
          enable = lib.mkDefault true;
          algorithm = "zstd";
          memoryPercent = cfg.zramPercent;
          priority = lib.mkDefault 100;
        };

        boot.kernel.sysctl = lib.mkIf (!cachyosCfg.enable) {
          "vm.swappiness" = 133;
          "vm.watermark_boost_factor" = 0;
          "vm.watermark_scale_factor" = 125;
          "vm.page-cluster" = 0;
        };

        powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

        services.ananicy = {
          enable = cfg.ananicy;
          package = pkgs.ananicy-cpp;
          rulesProvider = pkgs.ananicy-rules-cachyos_git;
        };
      };
    };
}
