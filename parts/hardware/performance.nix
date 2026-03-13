{ inputs, ... }:
{
  flake.nixosModules.hardware-performance =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.performance;
    in
    {
      _class = "nixos";
      options.myModules.hardware.performance = {
        enable = lib.mkEnableOption "Performance tuning and optimization";
        governor = lib.mkOption {
          type = lib.types.str;
          default = "powersave";
          description = "CPU frequency governor";
        };
        ananicy = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Ananicy-cpp process prioritization";
        };
        irqbalance = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "IRQ balancing across CPU cores";
        };
        scx = {
          enable = lib.mkEnableOption "Sched-ext (scx) userspace CPU schedulers";
          scheduler = lib.mkOption {
            type = lib.types.enum [
              "scx_lavd"
              "scx_bpfland"
              "scx_cosmos"
              "scx_rusty"
              "scx_rustland"
              "scx_flash"
              "scx_p2dq"
              "scx_beerland"
              "scx_mitosis"
              "scx_tickless"
              "scx_central"
              "scx_nest"
              "scx_layered"
            ];
            default = "scx_lavd";
            description = "Which SCX scheduler to run";
          };
          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "--performance" ];
            description = "Extra arguments passed to the scheduler";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # ZRAM and sysctl tuning are handled by myModules.system.cachyos
        # This module only manages CPU governor and process priority (ananicy)

        powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

        services.ananicy = {
          enable = cfg.ananicy;
          package = pkgs.ananicy-cpp;
          rulesProvider = pkgs.ananicy-rules-cachyos;
        };

        services.irqbalance.enable = cfg.irqbalance;

        services.scx = lib.mkIf cfg.scx.enable {
          enable = true;
          inherit (cfg.scx) scheduler;
          inherit (cfg.scx) extraArgs;
          package = pkgs.scx.full;
        };

        boot.kernelParams = lib.mkIf cfg.scx.enable [ "sched_ext" ];
      };
    };
}
