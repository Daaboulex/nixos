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
        occt = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable OCCT stability test"; }; };
        lsfgVk = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable lsfg-vk Vulkan frame generation (requires Lossless Scaling)"; }; };
        prismlauncher = { enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Prism Launcher for Minecraft"; }; };
        vkbasalt = {
          enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable vkBasalt Vulkan post-processing layer (vibrance, sharpening, color filters)"; };
          effects = lib.mkOption { type = lib.types.str; default = "cas"; description = "Colon-separated vkBasalt effects (cas, smaa, fxaa, Vibrance, LiftGammaGain, Tonemap, Levels, Curves)"; };
          casSharpness = lib.mkOption { type = lib.types.str; default = "0.4"; description = "CAS sharpness amount (0.0 = subtle, 1.0 = maximum)"; };
          toggleKey = lib.mkOption { type = lib.types.str; default = "Home"; description = "Key to toggle vkBasalt effects in-game"; };
          extraConfig = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra lines appended to vkBasalt.conf (ReShade shader parameters like Vibrance, LiftGammaGain)"; };
        };
        gpuDevice = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "GPU device index for gamemode optimizations (0 = first GPU)";
        };
        gamemode.renice = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Renice priority for gamemode-managed processes";
        };
        radv.perftest = lib.mkOption {
          type = lib.types.str;
          default = "gpl,nggc";
          description = "RADV_PERFTEST flags for AMD Vulkan driver (comma-separated)";
        };
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
            general = { renice = cfg.gamemode.renice; };
            gpu = {
              apply_gpu_optimisations = "accept-responsibility";
              gpu_device = cfg.gpuDevice;
            } // lib.optionalAttrs (config.myModules.hardware.graphics.amd.enable or false) {
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
        ++ lib.optionals cfg.mangohud.enable [ mangohud mangojuice ]
        ++ lib.optionals cfg.gamescope.enable [ gamescope ]
        ++ lib.optionals cfg.heroic.enable [ heroicWithExtras ]
        ++ lib.optionals cfg.ryubing.enable [ ryubing ]
        ++ lib.optionals cfg.eden.enable [ inputs.eden.packages.${system}.eden ]
        ++ lib.optionals cfg.azahar.enable [ azahar ]
        ++ lib.optionals cfg.nxSaveSync.enable [ inputs.nx-save-sync.packages.${system}.default ]
        ++ lib.optionals cfg.occt.enable [ pkgs.occt ]
        ++ lib.optionals cfg.lsfgVk.enable [ pkgs.lsfg-vk ]
        ++ lib.optionals cfg.prismlauncher.enable [ pkgs.prismlauncher ]
        ++ lib.optionals cfg.vkbasalt.enable [ pkgs.vkbasalt pkgs.vkbasalt-cli pkgs.reshade-shaders ];

        users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];

        # vkBasalt config with ReShade shader support
        environment.etc."vkBasalt.conf" = lib.mkIf cfg.vkbasalt.enable {
          text = ''
            effects = ${cfg.vkbasalt.effects}

            reshadeTexturePath = ${pkgs.reshade-shaders}/share/reshade/Textures
            reshadeIncludePath = ${pkgs.reshade-shaders}/share/reshade/Shaders
            depthCapture = off

            toggleKey = ${cfg.vkbasalt.toggleKey}
            enableOnLaunch = True

            casSharpness = ${cfg.vkbasalt.casSharpness}
          '' + lib.optionalString (cfg.vkbasalt.extraConfig != "") ''

            ${cfg.vkbasalt.extraConfig}
          '';
        };

        # Allow gamemode to renice processes
        security.pam.loginLimits = [
          { domain = "@gamemode"; type = "soft"; item = "nice"; value = -10; }
          { domain = "@gamemode"; type = "hard"; item = "nice"; value = -10; }
        ];

        # Gaming environment variables
        environment.sessionVariables = {
          MANGOHUD = lib.mkDefault "0";
          ENABLE_VKBASALT = lib.mkIf cfg.vkbasalt.enable (lib.mkDefault "0");
          GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
          VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
        } // lib.optionalAttrs (config.myModules.hardware.graphics.amd.enable or false) {
          AMD_VULKAN_ICD = lib.mkDefault "RADV";
          RADV_PERFTEST = cfg.radv.perftest;
        };
      };
    };
}
