{ inputs, ... }: {
  flake.nixosModules.apps-gaming = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.gaming;
      # Chaotic config alias
      chaoticCfg = config.myModules.chaotic.gaming;
      
      system = pkgs.stdenv.hostPlatform.system;
      
      heroicWithExtras = pkgs.heroic.override {
        extraPkgs = pkgs: 
          [ pkgs.gamemode ]
          ++ lib.optionals cfg.gamescope.enable [ pkgs.gamescope ]
          ++ lib.optionals cfg.mangohud.enable [ pkgs.mangohud ];
      };
      
      protonPackage = 
        if chaoticCfg.cpuMicroarch == "v4" then pkgs.proton-cachyos_x86_64_v4
        else if chaoticCfg.cpuMicroarch == "v3" then pkgs.proton-cachyos_x86_64_v3
        else if chaoticCfg.cpuMicroarch == "v2" then pkgs.proton-cachyos_x86_64_v2
        else pkgs.proton-cachyos;
    in {
      # =========================================================================
      # General Gaming Options
      # =========================================================================
      options.myModules.gaming = {
        enable = lib.mkEnableOption "Gaming optimizations and software";
        steam = {
          enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Steam"; };
          gamescope = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Gamescope session for Steam"; };
        };
        protonup = { enable = lib.mkEnableOption "ProtonUp-Qt for managing Proton versions"; };
        heroic = { enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Heroic Games Launcher"; }; };
        gamescope = { enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Gamescope"; }; };
        mangohud = { enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable MangoHud"; }; };
        ryubing = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Ryubing"; }; };
        eden = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Eden"; }; };
        azahar = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Azahar"; }; };
        nxSaveSync = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable NX-Save-Sync"; }; };
        packages = {
          performance = lib.mkOption { type = lib.types.bool; default = true; description = "Include performance packages"; };
          cachyos = lib.mkOption { type = lib.types.bool; default = true; description = "Use CachyOS optimized packages"; };
        };
      };

      # =========================================================================
      # Chaotic Gaming Options (Optimizations)
      # =========================================================================
      options.myModules.chaotic.gaming = {
        enable = lib.mkEnableOption "Chaotic-Nyx gaming optimizations";
        enableGamescope = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Gamescope compositor from Chaotic"; };
        enableMangohud = lib.mkOption { type = lib.types.bool; default = true; description = "Enable MangoHud from Chaotic"; };
        enableProtonCachyOS = lib.mkOption { type = lib.types.bool; default = true; description = "Enable Proton-CachyOS"; };
        cpuMicroarch = lib.mkOption {
          type = lib.types.enum [ "generic" "v2" "v3" "v4" ];
          default = "v3";
          description = "CPU microarchitecture for optimized builds";
        };
      };

      config = lib.mkMerge [
        # ------------------------------------------------------------------------
        # Base Gaming Configuration
        # ------------------------------------------------------------------------
        (lib.mkIf cfg.enable {
          programs.steam = lib.mkIf cfg.steam.enable {
            package = pkgs.steam.override { extraBwrapArgs = [ "--unsetenv" "TZ" ]; };
            enable = true;
            gamescopeSession.enable = cfg.steam.gamescope && cfg.gamescope.enable;
          };

          programs.gamescope.enable = cfg.gamescope.enable;
          programs.gamemode.enable = true;
          hardware.steam-hardware.enable = cfg.steam.enable;

          environment.systemPackages = with pkgs; [
            steam-devices-udev-rules
            gamemode
          ]
          ++ lib.optionals cfg.protonup.enable [ protonup-qt ]
          ++ lib.optionals cfg.mangohud.enable [ mangohud ]
          ++ lib.optionals cfg.heroic.enable [ heroicWithExtras ]
          ++ lib.optionals cfg.ryubing.enable [ ryubing ]
          ++ lib.optionals cfg.eden.enable [ inputs.eden.packages.${system}.eden ]
          ++ lib.optionals cfg.azahar.enable [ azahar ]
          ++ lib.optionals cfg.nxSaveSync.enable [ inputs.nx-save-sync.packages.${system}.default ];

          users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];

          # Allow gamemode to renice processes
          security.pam.loginLimits = [
            { domain = "@gamemode"; type = "soft"; item = "nice"; value = -10; }
            { domain = "@gamemode"; type = "hard"; item = "nice"; value = -10; }
          ];
        })

        # ------------------------------------------------------------------------
        # Chaotic Gaming Optimizations
        # ------------------------------------------------------------------------
        (lib.mkIf chaoticCfg.enable {
          # Proton-CachyOS + Proton-GE — optimized compatibility layers
          programs.steam.extraCompatPackages = lib.mkIf chaoticCfg.enableProtonCachyOS [
            pkgs.proton-ge-custom
            protonPackage
          ];

          # Gaming-specific packages (optimizations only, no cosmetics)
          environment.systemPackages = with pkgs;
            lib.optionals chaoticCfg.enableGamescope [ gamescope ]
            ++ lib.optionals chaoticCfg.enableMangohud [ mangohud ]
            ++ [
              latencyflex-vulkan  # Frame pacing / latency reduction for Vulkan games
              luxtorpeda          # Native Linux game engine replacements
            ];

          # Gamemode GPU optimization settings
          programs.gamemode = {
            enable = true;
            settings = {
              general = { renice = 10; };
              gpu = {
                apply_gpu_optimisations = "accept-responsibility";
                gpu_device = 0;
                amd_performance_level = "high";
              };
            };
          };

          # Gaming environment variables
          # Note: VK_DRIVER_FILES is set in chaotic.nix (AMD-conditional)
          # Note: ananicy-rules-cachyos_git is provided by performance.nix rulesProvider
          environment.sessionVariables = {
            MANGOHUD = lib.mkDefault "0";
            GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
            AMD_VULKAN_ICD = lib.mkDefault "RADV";
            RADV_PERFTEST = "gpl,nggc";
            VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
          };
        })
      ];
    };
}
