{ inputs, ... }: {
  flake.nixosModules.hardware-performance = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.performance;
    in {
      options.myModules.hardware.performance = {
        enable = lib.mkEnableOption "Performance tuning and optimization";
        governor = lib.mkOption { type = lib.types.str; default = "powersave"; description = "CPU frequency governor"; };
        ananicy = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Ananicy"; };
        scx = {
          enable = lib.mkEnableOption "Sched-ext (scx) userspace CPU schedulers";
          scheduler = lib.mkOption {
            type = lib.types.enum [ "scx_rusty" "scx_rustland" "scx_lavd" "scx_bpfland" "scx_central" ];
            default = "scx_rusty";
            description = "Which SCX scheduler to run";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # ZRAM and sysctl tuning are handled by myModules.cachyos.settings
        # This module only manages CPU governor and process priority (ananicy)

        powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

        services.ananicy = {
          enable = cfg.ananicy;
          package = pkgs.ananicy-cpp;
          rulesProvider = pkgs.ananicy-rules-cachyos;
        };

        services.scx = lib.mkIf cfg.scx.enable {
          enable = true;
          scheduler = cfg.scx.scheduler;
          package = pkgs.scx.full;
        };

        boot.kernelParams = lib.mkIf cfg.scx.enable [ "sched_ext" ];
      };
    };
}
