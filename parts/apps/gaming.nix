{ inputs, withSystem, ... }:
{
  flake.nixosModules.apps-gaming =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.gaming;
      perSystem = withSystem pkgs.stdenv.hostPlatform.system ({ inputs', ... }: inputs');

      heroicWithExtras = pkgs.heroic.override {
        extraPkgs =
          pkgs:
          [ pkgs.gamemode ]
          ++ lib.optionals cfg.gamescope.enable [ pkgs.gamescope ]
          ++ lib.optionals cfg.mangohud.enable [ pkgs.mangohud ];
      };

    in
    {
      _class = "nixos";
      # =========================================================================
      # General Gaming Options
      # =========================================================================
      options.myModules.gaming = {
        enable = lib.mkEnableOption "Gaming optimizations and software";
        steam = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Steam";
          };
          gamescope = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Gamescope session for Steam";
          };
        };
        protonplus = {
          enable = lib.mkEnableOption "ProtonPlus for managing Proton versions";
        };
        heroic = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Heroic Games Launcher";
          };
        };
        gamescope = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Gamescope";
          };
        };
        mangohud = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "MangoHud";
          };
        };
        ryubing = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Ryubing";
          };
        };
        eden = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Eden";
          };
        };
        azahar = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Azahar";
          };
        };
        nxSaveSync = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "NX-Save-Sync";
          };
        };
        occt = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "OCCT stability test";
          };
        };
        lsfgVk = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "lsfg-vk Vulkan frame generation (requires Lossless Scaling)";
          };
        };
        prismlauncher = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Prism Launcher for Minecraft";
          };
        };
        vkbasalt = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "vkBasalt overlay — Vulkan post-processing with in-game UI";
          };
          effects = lib.mkOption {
            type = lib.types.str;
            default = "cas";
            description = "Default colon-separated effect chain (cas, smaa, fxaa, Vibrance, LiftGammaGain, Tonemap, etc.)";
          };
          casSharpness = lib.mkOption {
            type = lib.types.str;
            default = "0.4";
            description = "Default CAS sharpness (0.0 = subtle, 1.0 = maximum)";
          };
          toggleKey = lib.mkOption {
            type = lib.types.str;
            default = "Home";
            description = "Key to toggle effects on/off in-game";
          };
          overlayKey = lib.mkOption {
            type = lib.types.str;
            default = "F1";
            description = "Key to open the overlay UI in-game";
          };
          enableOnLaunch = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Effects enabled automatically when a game launches";
          };
          autoApply = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Auto-apply parameter changes without clicking Apply";
          };
          extraConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Extra lines for system config (ReShade shader parameters like Vibrance, LiftGammaGain values)";
          };
        };
        gpuDevice = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "GPU device index for gamemode optimizations (0 = first GPU)";
        };
        gamemode = {
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
        radv.perftest = lib.mkOption {
          type = lib.types.str;
          default = "gpl,nggc";
          description = "RADV_PERFTEST flags for AMD Vulkan driver (comma-separated)";
        };
        packages = {
          performance = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Performance packages";
          };
          cachyos = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "CachyOS optimized packages";
          };
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
            general = {
              inherit (cfg.gamemode) renice;
              inherit (cfg.gamemode) ioprio;
              inherit (cfg.gamemode) desiredgov;
              softrealtime = "off"; # Incompatible with BORE/scx_lavd
              inhibit_screensaver = 1;
              disable_splitlock = 1; # Helps certain games with split-lock mitigation overhead
            };
            gpu = lib.mkIf (cfg.gamemode.gpuPerformanceLevel != null) (
              {
                apply_gpu_optimisations = "accept-responsibility";
                gpu_device = cfg.gpuDevice;
              }
              // lib.optionalAttrs (config.myModules.hardware.graphics.amd.enable or false) {
                amd_performance_level = cfg.gamemode.gpuPerformanceLevel;
              }
            );
            cpu = lib.mkMerge [
              {
                pin_cores = cfg.gamemode.pinCores;
                park_cores = "no";
              }
              (lib.mkIf (cfg.gamemode.x3dMode.desired != null) {
                amd_x3d_mode_desired = cfg.gamemode.x3dMode.desired;
              })
              (lib.mkIf (cfg.gamemode.x3dMode.default != null) {
                amd_x3d_mode_default = cfg.gamemode.x3dMode.default;
              })
            ];
          };
        };
        hardware.steam-hardware.enable = cfg.steam.enable;

        environment.systemPackages =
          with pkgs;
          [
            steam-devices-udev-rules
            gamemode
          ]
          ++ lib.optionals cfg.protonplus.enable [ protonplus ]
          ++ lib.optionals cfg.mangohud.enable [
            mangohud
            mangojuice
          ]
          ++ lib.optionals cfg.gamescope.enable [ gamescope ]
          ++ lib.optionals cfg.heroic.enable [ heroicWithExtras ]
          ++ lib.optionals cfg.ryubing.enable [ ryubing ]
          ++ lib.optionals cfg.eden.enable [ perSystem.eden.packages.eden ]
          ++ lib.optionals cfg.azahar.enable [ azahar ]
          ++ lib.optionals cfg.nxSaveSync.enable [ perSystem.nx-save-sync.packages.default ]
          ++ lib.optionals cfg.occt.enable [ pkgs.occt ]
          ++ lib.optionals cfg.lsfgVk.enable [ pkgs.lsfg-vk ]
          ++ lib.optionals cfg.prismlauncher.enable [ pkgs.prismlauncher ]
          ++ lib.optionals cfg.vkbasalt.enable [
            pkgs.vkbasalt-overlay
            pkgs.reshade-shaders

            # Wrap the package's vkbasalt-run with NixOS-specific help text
            # (keybinds and config paths that the package doesn't know about).
            (pkgs.writeShellScriptBin "vkbasalt-run" ''
              if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
                echo "Usage: vkbasalt-run <command...>"
                echo ""
                echo "Launch a game with vkBasalt overlay enabled."
                echo "Sets ENABLE_VKBASALT=1 and LD_AUDIT for Wine Wayland input interposition."
                echo ""
                echo "Examples:"
                echo "  vkbasalt-run %command%      # Steam launch option"
                echo "  vkbasalt-run ./game          # Direct launch"
                echo ""
                echo "In-game controls:"
                echo "  ${cfg.vkbasalt.overlayKey}    Open overlay UI (add/remove effects, save configs)"
                echo "  ${cfg.vkbasalt.toggleKey}  Toggle effects on/off"
                echo ""
                echo "Config locations:"
                echo "  System defaults:  /etc/vkBasalt-overlay/vkBasalt.conf"
                echo "  User overrides:   ~/.config/vkBasalt-overlay/vkBasalt.conf"
                echo "  Saved configs:    ~/.config/vkBasalt-overlay/configs/"
                exit 0
              fi

              exec ${pkgs.vkbasalt-overlay}/bin/vkbasalt-run "$@"
            '')
          ];

        users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];

        # vkBasalt overlay: system-level config (fallback when no user config exists)
        # User config at ~/.config/vkBasalt-overlay/vkBasalt.conf takes precedence.
        # The overlay's in-game UI manages per-game configs in ~/.config/vkBasalt-overlay/configs/
        environment.etc = lib.mkIf cfg.vkbasalt.enable {
          "vkBasalt-overlay/vkBasalt.conf".text = ''
            effects = ${cfg.vkbasalt.effects}

            reshadeTexturePath = ${pkgs.reshade-shaders}/share/reshade/Textures
            reshadeIncludePath = ${pkgs.reshade-shaders}/share/reshade/Shaders
            depthCapture = off

            toggleKey = ${cfg.vkbasalt.toggleKey}
            overlayKey = ${cfg.vkbasalt.overlayKey}
            enableOnLaunch = ${if cfg.vkbasalt.enableOnLaunch then "true" else "false"}
            autoApply = ${if cfg.vkbasalt.autoApply then "true" else "false"}

            casSharpness = ${cfg.vkbasalt.casSharpness}
          ''
          + lib.optionalString (cfg.vkbasalt.extraConfig != "") ''

            ${cfg.vkbasalt.extraConfig}
          '';
        };

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

        # Gaming environment variables
        environment.sessionVariables = {
          MANGOHUD = lib.mkDefault "0";
          ENABLE_VKBASALT = lib.mkIf cfg.vkbasalt.enable (lib.mkDefault "0");
          DISABLE_LSFGVK = lib.mkIf cfg.lsfgVk.enable (lib.mkDefault "1");
          GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
          VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
        }
        // lib.optionalAttrs (config.myModules.hardware.graphics.amd.enable or false) {
          AMD_VULKAN_ICD = lib.mkDefault "RADV";
          RADV_PERFTEST = cfg.radv.perftest;
        };
      };
    };
}
