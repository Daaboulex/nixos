{ inputs, ... }: {
  flake.nixosModules.apps-gaming = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.gaming;
      system = pkgs.stdenv.hostPlatform.system;
      
      heroicWithExtras = pkgs.heroic.override {
        extraPkgs = pkgs: 
          [ pkgs.gamemode ]
          ++ lib.optionals cfg.gamescope.enable [ pkgs.gamescope ]
          ++ lib.optionals cfg.mangohud.enable [ pkgs.mangohud ];
      };
      
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
        protonplus = { enable = lib.mkEnableOption "ProtonPlus for managing Proton versions"; };
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

      config = lib.mkIf cfg.enable {
        programs.steam = lib.mkIf cfg.steam.enable {
          enable = true;
          gamescopeSession.enable = cfg.steam.gamescope && cfg.gamescope.enable;
          # Provide standard proton-ge-bin instead of proton-cachyos
          extraCompatPackages = [ pkgs.proton-ge-bin ];
        };

        programs.gamescope.enable = cfg.gamescope.enable;
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
        hardware.steam-hardware.enable = cfg.steam.enable;

        environment.systemPackages = with pkgs; [
          steam-devices-udev-rules
          gamemode
        ]
        ++ lib.optionals cfg.protonplus.enable [ protonplus ]
        ++ lib.optionals cfg.mangohud.enable [ mangohud ]
        ++ lib.optionals cfg.gamescope.enable [ gamescope ]
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

        # Gaming environment variables
        environment.sessionVariables = {
          MANGOHUD = lib.mkDefault "0";
          GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
          AMD_VULKAN_ICD = lib.mkDefault "RADV";
          RADV_PERFTEST = "gpl,nggc";
          VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
        };
      };
    };
}
