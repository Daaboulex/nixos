# performance — general performance tuning (governor, swappiness, scheduler).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.myModules.tuning.performance;
    in
    {
      _class = "nixos";
      options.myModules.tuning.performance = {
        enable = lib.mkEnableOption "Performance tuning and optimization";
        governor = lib.mkOption {
          type = lib.types.enum [
            "performance"
            "powersave"
            "schedutil"
            "ondemand"
            "conservative"
            "userspace"
          ];
          default = "powersave";
          description = ''
            CPU frequency governor (cpufreq scaling_governor). Finite set
            defined by the kernel cpufreq subsystem. `powersave` is the
            safe default on scx-scheduled hosts (scx handles frequency
            decisions); pick `performance` for VFIO or low-latency hosts.
          '';
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
            # Upstream's own type validates the name, so this option can never
            # drift from the schedulers services.scx actually accepts.
            type = options.services.scx.scheduler.type;
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
        # ZRAM and sysctl tuning are handled by myModules.tuning.cachyos
        # This module only manages CPU governor and process priority (ananicy)

        powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

        services = {
          ananicy = {
            enable = cfg.ananicy;
            package = pkgs.ananicy-cpp;
            rulesProvider = pkgs.ananicy-rules-cachyos;
          };
          irqbalance.enable = cfg.irqbalance;
          scx = lib.mkIf cfg.scx.enable {
            enable = true;
            inherit (cfg.scx) scheduler;
            inherit (cfg.scx) extraArgs;
            # Daaboulex git build (flake input scx-git), not nixpkgs scx and not
            # via overlay — referenced directly at the point of use.
            package = inputs.scx-git.packages.${pkgs.stdenv.hostPlatform.system}."scx-git-full";
          };
        };

        boot.kernelParams = lib.mkIf cfg.scx.enable [ "sched_ext" ];
      };
    };
in
{
  flake.modules.nixos.tuning-performance = mod;

}
