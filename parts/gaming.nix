{ inputs, withSystem, ... }:
{
  flake.nixosModules.gaming =
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

      # ── ReShade Shader Collections ──────────────────────────────────────
      # Each package installs to share/reshade/{Shaders,Textures}.
      # combinedShaders merges them all via symlinkJoin for vkBasalt paths.
      # Only shaders that work without depth buffer are useful (depthCapture=off).
      mkShaderPkg =
        {
          pname,
          src,
          shaderDir ? "Shaders",
          textureDir ? "Textures",
        }:
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname src;
          version = "unstable";
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/reshade/{Shaders,Textures}
            if [ -d "${shaderDir}" ]; then
              cp -r ${shaderDir}/* $out/share/reshade/Shaders/
            fi
            if [ -d "${textureDir}" ]; then
              cp -r ${textureDir}/* $out/share/reshade/Textures/
            fi
            runHook postInstall
          '';
        };

      shaderCollections = [
        # Base ReShade shaders (crosire) — CAS, Deband, LUT, SMAA, FXAA
        (mkShaderPkg {
          pname = "reshade-shaders-crosire";
          src = pkgs.fetchFromGitHub {
            owner = "crosire";
            repo = "reshade-shaders";
            rev = "d71489726fa0c732e862e36044abbf7e2bbb6ba1";
            hash = "sha256-87Z+4p4Sx5FcTIvh9cMcHvjySWg5ohHAwvNV6RbLq4A=";
          };
        })
        # SweetFX — Vibrance, LiftGammaGain, Tonemap, Curves, LumaSharpen
        (mkShaderPkg {
          pname = "reshade-shaders-sweetfx";
          src = pkgs.fetchFromGitHub {
            owner = "CeeJayDK";
            repo = "SweetFX";
            rev = "16d1a42247cb5baaf660120ee35c9a33bb94649c";
            hash = "sha256-h7nqn4aQHomrI/NG0Oj2R9bBT8VfzRGVSZ/CSi/Ishs=";
          };
          shaderDir = "Shaders/SweetFX";
        })
        # prod80 — Professional color grading: Shadows/Midtones/Highlights,
        # Selective Color, Color Temperature, Bloom, Film Grain, Sharpening, LUTs
        (mkShaderPkg {
          pname = "reshade-shaders-prod80";
          src = pkgs.fetchFromGitHub {
            owner = "prod80";
            repo = "prod80-ReShade-Repository";
            rev = "1c2ed5b093b03c558bfa6aea45c2087052e99554";
            hash = "sha256-EM9WxpbN0tUB9yjZFwWtY1l8um7jvMfC2eenEl2amF8=";
          };
        })
        # AstrayFX — DLAA (best AA without depth), Smart_Sharp, Clarity, BloomingHDR
        (mkShaderPkg {
          pname = "reshade-shaders-astrayfx";
          src = pkgs.fetchFromGitHub {
            owner = "BlueSkyDefender";
            repo = "AstrayFX";
            rev = "7e6d7bd8e0729a2cee80d26907b8fb27b568d955";
            hash = "sha256-wcNLTGQxkGaQr/N4BCsT+y9pe41oU5Bsen49ofVcGc0=";
          };
        })
        # fubax — FilmicAnamorphSharpen, FilmicSharpen, PerfectPerspective
        (mkShaderPkg {
          pname = "reshade-shaders-fubax";
          src = pkgs.fetchFromGitHub {
            owner = "Fubaxiusz";
            repo = "fubax-shaders";
            rev = "38825ee2e91c257318c5459fe87337e3049351d9";
            hash = "sha256-X9SX/sypZX3QxblncmxLfjFjiNEeIk/yAkqeKz/WzN4=";
          };
        })
        # qUINT — Lightroom color grading, bloom, sharp
        (mkShaderPkg {
          pname = "reshade-shaders-quint";
          src = pkgs.fetchFromGitHub {
            owner = "martymcmodding";
            repo = "qUINT";
            rev = "98fed77b26669202027f575a6d8f590426c21ebd";
            hash = "sha256-nPraJgxDm1N9FIhrv0msI3B3it8uyzk6YoX25WY27gE=";
          };
        })
        # iMMERSE — SMAA, sharpen (qUINT successor by martymcmodding)
        (mkShaderPkg {
          pname = "reshade-shaders-immerse";
          src = pkgs.fetchFromGitHub {
            owner = "martymcmodding";
            repo = "iMMERSE";
            rev = "8fa641ef7af561a52cfc15f43155abd54b095b1f";
            hash = "sha256-U2jCXL+nDKrFdjby/oQ0T0hw0tL6+SJPzSu9IAaXibA=";
          };
        })
        # METEOR — Film grain, NVSharpen, local Laplacian, long exposure, halftone
        (mkShaderPkg {
          pname = "reshade-shaders-meteor";
          src = pkgs.fetchFromGitHub {
            owner = "martymcmodding";
            repo = "METEOR";
            rev = "228e4aa521b34bdf3ad798220a1e59cc4a2a6a95";
            hash = "sha256-iQ8BYWRNCbQuJ9CRSelF+idcKlCtW+172ZrUUAI8F20=";
          };
        })
        # Insane-Shaders — Dehaze, Halftone, BilateralComic, Oilify
        (mkShaderPkg {
          pname = "reshade-shaders-insane";
          src = pkgs.fetchFromGitHub {
            owner = "LordOfLunacy";
            repo = "Insane-Shaders";
            rev = "19397d503e2fbf1ad2cbedb35fbf2ee84a32e3ec";
            hash = "sha256-2tP0huDz+DBe9GusI2levldx4ilSapePjjiUCEGqOn8=";
          };
        })
        # Daodan — ColorIsolation, Comic, RemoveTint, RetroTint, MeshEdges
        (mkShaderPkg {
          pname = "reshade-shaders-daodan";
          src = pkgs.fetchFromGitHub {
            owner = "Daodan317081";
            repo = "reshade-shaders";
            rev = "f01ddb6f3dce6a8fb75ffb9fee878a1489edfc16";
            hash = "sha256-69jgQfuoV7pObUdSFCwDJzvWR8ijAX9W8TzJR+yIl44=";
          };
        })
        # FXShaders — Bloom, tonemapping, color grading
        (mkShaderPkg {
          pname = "reshade-shaders-fxshaders";
          src = pkgs.fetchFromGitHub {
            owner = "luluco250";
            repo = "FXShaders";
            rev = "76365e35c48e30170985ca371e67d8daf8eb9a98";
            hash = "sha256-Ig8LyICXeo60Xq+4AfVh9FV904pMBPoQ0beUSLi48hY=";
          };
        })
        # potatoFX — HDR-compatible camera, color noise, palette effects
        (mkShaderPkg {
          pname = "reshade-shaders-potatofx";
          src = pkgs.fetchFromGitHub {
            owner = "GimleLarpes";
            repo = "potatoFX";
            rev = "f55a022121688ce9e0d4534f676f1300f14dcb90";
            hash = "sha256-z0R0erjzBlfScaBX6IZE/0zQPU8eHph6fAp9fV/acLU=";
          };
        })
        # CShade — CAS, RCAS, FXAA, DLAA, auto-exposure bloom
        (mkShaderPkg {
          pname = "reshade-shaders-cshade";
          src = pkgs.fetchFromGitHub {
            owner = "papadanku";
            repo = "CShade";
            rev = "40d1105e7ae96ecba7860b1672ef91296489c5fe";
            hash = "sha256-OxPN6pouGtV63+qt3aHwyxX4bOl8WeDN4o7u9MqTRq0=";
          };
          shaderDir = "shaders"; # lowercase in this repo
        })
        # ZenteonFX — Film grain, local contrast, sharpening, xenon bloom
        (mkShaderPkg {
          pname = "reshade-shaders-zenteonfx";
          src = pkgs.fetchFromGitHub {
            owner = "Zenteon";
            repo = "ZenteonFX";
            rev = "0f0a290d3f497330f02cc6d56bf5e8d2524efc52";
            hash = "sha256-UCD3LAZ01aXAo/obsmjsTA12pBx09IXozdcJVc8xir0=";
          };
        })
        # HDR shaders — Tone mapping, film grain, CAS/RCAS for HDR, SDR-to-HDR
        (mkShaderPkg {
          pname = "reshade-shaders-hdr";
          src = pkgs.fetchFromGitHub {
            owner = "EndlesslyFlowering";
            repo = "ReShade_HDR_shaders";
            rev = "48ab279bcc433d8218b7f32cfc550a39a408365c";
            hash = "sha256-zWKTBuoeCcUzZsaZX5h9R2dwR72WIKMR2KvC2aFGR3o=";
          };
        })
      ];

      # Combine all enabled shader packages into one derivation
      combinedShaders = pkgs.symlinkJoin {
        name = "combined-reshade-shaders";
        paths = cfg.vkbasalt.shaderPackages;
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
          shaderPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = shaderCollections;
            defaultText = lib.literalExpression "[ <15 shader collections> ]";
            description = "Shader packages providing share/reshade/{Shaders,Textures} — combined into vkBasalt shader/texture paths";
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
              // lib.optionalAttrs (config.myModules.hardware.gpu.amd.enable or false) {
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
            combinedShaders

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
          # Stable symlink for overlay UI shader manager (survives rebuilds)
          "vkBasalt-overlay/reshade".source = "${combinedShaders}/share/reshade";
          "vkBasalt-overlay/vkBasalt.conf".text = ''
            effects = ${cfg.vkbasalt.effects}

            reshadeTexturePath = ${combinedShaders}/share/reshade/Textures
            reshadeIncludePath = ${combinedShaders}/share/reshade/Shaders
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
        // lib.optionalAttrs (config.myModules.hardware.gpu.amd.enable or false) {
          AMD_VULKAN_ICD = lib.mkDefault "RADV";
          RADV_PERFTEST = cfg.radv.perftest;
        };
      };
    };
}
