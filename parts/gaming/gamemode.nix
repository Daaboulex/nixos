# gamemode — Gamemode CPU/GPU optimisation daemon for foreground-game priority boosting.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.gaming.gamemode;
    in
    {
      _class = "nixos";
      options.myModules.gaming.gamemode = {
        enable = lib.mkEnableOption "Gamemode CPU/GPU optimisation daemon";
        gpuDevice = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "GPU device index for gamemode optimizations (0 = first GPU)";
        };
        renice = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Renice priority for gamemode-managed processes (0 = disabled, avoids conflict with ananicy-cpp)";
        };
        ioprio = lib.mkOption {
          type = lib.types.str;
          default = "off";
          description = "IO priority for game processes (off = disabled to avoid ananicy-cpp conflict, or 0-7)";
        };
        desiredgov = lib.mkOption {
          type = lib.types.str;
          default = "performance";
          description = "CPU governor to set when a game starts (performance = aggressive EPP hint on amd_pstate)";
        };
        x3dMode = {
          desired = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "cache"
                "frequency"
              ]
            );
            default = null;
            description = "X3D V-Cache CCD mode when gaming (cache = prefer V-Cache CCD, frequency = prefer high-clock CCD)";
          };
          default = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "cache"
                "frequency"
              ]
            );
            default = null;
            description = "X3D V-Cache CCD mode when not gaming (restored on exit)";
          };
        };
        pinCores = lib.mkOption {
          type = lib.types.str;
          default = "no";
          description = "Pin game to specific cores (yes = auto-detect, or core list like 0-7,16-23, no = disabled)";
        };
        gpuPerformanceLevel = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "auto"
              "low"
              "high"
            ]
          );
          default = null;
          description = "AMDGPU power_dpm_force_performance_level (null = don't set, auto = driver decides, high = max clocks)";
        };
      };
      config = lib.mkIf cfg.enable {
        programs.gamemode = {
          enable = true;
          settings = {
            general = {
              inherit (cfg) renice;
              inherit (cfg) ioprio;
              inherit (cfg) desiredgov;
              softrealtime = "off"; # Incompatible with BORE/scx_lavd
              inhibit_screensaver = 1;
              disable_splitlock = 1; # Helps certain games with split-lock mitigation overhead
            };
            gpu = lib.mkIf (cfg.gpuPerformanceLevel != null) (
              {
                apply_gpu_optimisations = "accept-responsibility";
                gpu_device = cfg.gpuDevice;
              }
              // lib.optionalAttrs (config.myModules.hardware.gpuAmd.enable or false) {
                amd_performance_level = cfg.gpuPerformanceLevel;
              }
            );
            cpu = lib.mkMerge [
              {
                pin_cores = cfg.pinCores;
                park_cores = "no";
              }
              (lib.mkIf (cfg.x3dMode.desired != null) {
                amd_x3d_mode_desired = cfg.x3dMode.desired;
              })
              (lib.mkIf (cfg.x3dMode.default != null) {
                amd_x3d_mode_default = cfg.x3dMode.default;
              })
            ];
          };
        };

        # gamemode package provided by programs.gamemode.enable above

        users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];

        # Allow gamemode to renice processes
        security.pam.loginLimits = [
          {
            domain = "@gamemode";
            type = "soft";
            item = "nice";
            value = -10;
          }
          {
            domain = "@gamemode";
            type = "hard";
            item = "nice";
            value = -10;
          }
        ];

        # Vulkan layer search path is owned by hardware-graphics (VK_ADD_LAYER_PATH,
        # additive so user layers like mangohud/vkbasalt are not clobbered).
        # GAMESCOPE_LIMITER_FILE is set by the HM gamescope module.
        # MANGOHUD default is set by the HM mangohud module.
      };
    };
in
{
  flake.modules.nixos.gaming-gamemode = mod;

}
