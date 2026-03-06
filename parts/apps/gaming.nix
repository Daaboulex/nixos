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
          profiles = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                effects = lib.mkOption { type = lib.types.str; description = "Colon-separated vkBasalt effects for this profile"; };
                casSharpness = lib.mkOption { type = lib.types.str; default = cfg.vkbasalt.casSharpness; description = "CAS sharpness for this profile"; };
                toggleKey = lib.mkOption { type = lib.types.str; default = cfg.vkbasalt.toggleKey; description = "Toggle key for this profile"; };
                extraConfig = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra shader parameters for this profile"; };
              };
            });
            default = {};
            description = "Named vkBasalt profiles generating /etc/vkBasalt-<name>.conf (use with vkbasalt-run <profile> or VKBASALT_CONFIG_FILE)";
          };
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
        ++ lib.optionals cfg.vkbasalt.enable [
          pkgs.vkbasalt pkgs.reshade-shaders

          # vkbasalt-run [profile] <command...> — launch with a specific profile
          (let
            profileNames = builtins.attrNames cfg.vkbasalt.profiles;
            hasProfiles = profileNames != [];
          in pkgs.writeShellScriptBin "vkbasalt-run" ''
            if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
              echo "Usage: vkbasalt-run [profile] <command...>"
              echo ""
              echo "Launch a game with vkBasalt enabled using a specific filter profile."
              echo "vkBasalt reads its config once at launch — profile selection happens here."
              echo ""
              echo "Profiles:"
              echo "  (none)       /etc/vkBasalt.conf (default)"
              ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: _:
                ''echo "  ${name}$(printf '%*s' $((12 - ${toString (builtins.stringLength name)})) "")  /etc/vkBasalt-${name}.conf"''
              ) cfg.vkbasalt.profiles)}
              echo ""
              echo "Examples:"
              echo "  vkbasalt-run %command%              # Default profile (Steam launch option)"
              ${lib.optionalString hasProfiles ''echo "  vkbasalt-run ${builtins.head profileNames} %command%   # Named profile"''}
              echo ""
              echo "In-game: press Home to toggle effects on/off"
              echo "See also: vkbasalt-ctl (manage user config, adjust parameters)"
              exit 0
            fi

            PROFILE=""
            ${lib.optionalString hasProfiles ''
            case "$1" in
              ${lib.concatStringsSep "|" profileNames})
                PROFILE="$1"
                shift
                ;;
            esac
            ''}

            export ENABLE_VKBASALT=1
            if [ -n "$PROFILE" ]; then
              export VKBASALT_CONFIG_FILE="/etc/vkBasalt-''${PROFILE}.conf"
            fi
            exec "$@"
          '')

          # vkbasalt-ctl — manage user vkBasalt config (~/.config/vkBasalt.conf)
          # User config overrides system /etc/vkBasalt.conf. Changes apply on next game launch.
          (let
            profileNames = builtins.attrNames cfg.vkbasalt.profiles;
          in pkgs.writeShellScriptBin "vkbasalt-ctl" ''
            USER_CONF="''${XDG_CONFIG_HOME:-$HOME/.config}/vkBasalt.conf"
            SYSTEM_CONF="/etc/vkBasalt.conf"

            # Get the active config (user override or system default)
            active_conf() {
              if [ -f "$USER_CONF" ]; then
                echo "$USER_CONF"
              else
                echo "$SYSTEM_CONF"
              fi
            }

            # Read a value from the active config
            get_value() {
              local key="$1"
              grep -m1 "^[[:space:]]*$key[[:space:]]*=" "$(active_conf)" 2>/dev/null | sed 's/.*=[[:space:]]*//'
            }

            # Set a value in the user config (creates from system config if needed)
            set_value() {
              local key="$1" val="$2"
              if [ ! -f "$USER_CONF" ]; then
                mkdir -p "$(dirname "$USER_CONF")"
                cp -L "$SYSTEM_CONF" "$USER_CONF"
                chmod u+w "$USER_CONF"
                echo "Created $USER_CONF from system defaults"
              fi
              if grep -q "^[[:space:]]*$key[[:space:]]*=" "$USER_CONF" 2>/dev/null; then
                ${pkgs.gnused}/bin/sed -i "s|^[[:space:]]*$key[[:space:]]*=.*|$key = $val|" "$USER_CONF"
              else
                echo "$key = $val" >> "$USER_CONF"
              fi
            }

            # Adjust a numeric value by a delta, clamped to [min, max]
            adjust_value() {
              local key="$1" delta="$2" min="$3" max="$4"
              local current
              current=$(get_value "$key")
              if [ -z "$current" ]; then
                echo "Parameter '$key' not found in config"
                return 1
              fi
              local new
              new=$(${pkgs.python3}/bin/python3 -c "print(max($min, min($max, round($current + $delta, 2))))")
              set_value "$key" "$new"
              echo "$key: $current -> $new"
            }

            case "''${1:-}" in
              show|status)
                echo "Active config: $(active_conf)"
                echo ""
                echo "Current settings:"
                echo "  effects      = $(get_value effects)"
                echo "  casSharpness = $(get_value casSharpness)"
                echo "  toggleKey    = $(get_value toggleKey)"
                # Show ReShade params if present
                for param in Vibrance LiftGammaGainLift LiftGammaGainGamma LiftGammaGainGain Gamma Exposure Saturation; do
                  val=$(get_value "$param")
                  [ -n "$val" ] && echo "  $param = $val"
                done
                echo ""
                if [ -f "$USER_CONF" ]; then
                  echo "User override active. Run 'vkbasalt-ctl reset' to remove."
                else
                  echo "Using system config. Run 'vkbasalt-ctl set <key> <val>' to create user override."
                fi
                ;;

              set)
                if [ $# -lt 3 ]; then
                  echo "Usage: vkbasalt-ctl set <key> <value>"
                  exit 1
                fi
                set_value "$2" "$3"
                echo "Set $2 = $3 (applies on next game launch)"
                ;;

              sharpen-up)
                adjust_value "casSharpness" "0.1" "0.0" "1.0"
                echo "(applies on next game launch)"
                ;;
              sharpen-down)
                adjust_value "casSharpness" "-0.1" "0.0" "1.0"
                echo "(applies on next game launch)"
                ;;
              vibrance-up)
                adjust_value "Vibrance" "0.1" "-1.0" "1.0"
                echo "(applies on next game launch)"
                ;;
              vibrance-down)
                adjust_value "Vibrance" "-0.1" "-1.0" "1.0"
                echo "(applies on next game launch)"
                ;;

              profile)
                if [ -z "''${2:-}" ]; then
                  echo "Usage: vkbasalt-ctl profile <name>"
                  echo ""
                  echo "Available profiles:"
                  echo "  default    /etc/vkBasalt.conf"
                  ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: _:
                    ''echo "  ${name}$(printf '%*s' $((12 - ${toString (builtins.stringLength name)})) "")  /etc/vkBasalt-${name}.conf"''
                  ) cfg.vkbasalt.profiles)}
                  exit 0
                fi
                SRC="$SYSTEM_CONF"
                if [ "$2" != "default" ]; then
                  SRC="/etc/vkBasalt-$2.conf"
                fi
                if [ ! -f "$SRC" ]; then
                  echo "Profile '$2' not found ($SRC does not exist)"
                  exit 1
                fi
                mkdir -p "$(dirname "$USER_CONF")"
                rm -f "$USER_CONF"
                cp -L "$SRC" "$USER_CONF"
                chmod u+w "$USER_CONF"
                echo "Switched to profile '$2' (copied to $USER_CONF)"
                echo "(applies on next game launch)"
                ;;

              reset)
                if [ -f "$USER_CONF" ]; then
                  rm "$USER_CONF"
                  echo "Removed user config — back to system defaults"
                else
                  echo "No user config to remove"
                fi
                ;;

              *)
                echo "vkbasalt-ctl — manage vkBasalt post-processing settings"
                echo ""
                echo "vkBasalt reads config once at game launch. The Home key toggles"
                echo "effects on/off in-game. All other changes apply on next launch."
                echo ""
                echo "Commands:"
                echo "  show                 Show active config and current values"
                echo "  set <key> <value>    Set a parameter in user config"
                echo "  sharpen-up           Increase CAS sharpness by 0.1"
                echo "  sharpen-down         Decrease CAS sharpness by 0.1"
                echo "  vibrance-up          Increase Vibrance by 0.1"
                echo "  vibrance-down        Decrease Vibrance by 0.1"
                echo "  profile <name>       Switch to a named profile (default${lib.concatStringsSep "" (map (n: ", ${n}") profileNames)})"
                echo "  reset                Remove user config, revert to system defaults"
                echo ""
                echo "Stream Deck buttons:"
                echo "  vkbasalt-ctl sharpen-up"
                echo "  vkbasalt-ctl sharpen-down"
                echo "  vkbasalt-ctl vibrance-up"
                echo "  vkbasalt-ctl vibrance-down"
                echo "  vkbasalt-ctl profile competitive"
                ;;
            esac
          '')
        ];

        users.users.${config.myModules.primaryUser}.extraGroups = [ "gamemode" ];

        # vkBasalt config: default + per-profile config files
        environment.etc = lib.mkIf cfg.vkbasalt.enable ({
          # Default config (/etc/vkBasalt.conf)
          "vkBasalt.conf".text = ''
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
        } // lib.mapAttrs' (name: profile:
          # Named profiles (/etc/vkBasalt-<name>.conf)
          lib.nameValuePair "vkBasalt-${name}.conf" {
            text = ''
              effects = ${profile.effects}

              reshadeTexturePath = ${pkgs.reshade-shaders}/share/reshade/Textures
              reshadeIncludePath = ${pkgs.reshade-shaders}/share/reshade/Shaders
              depthCapture = off

              toggleKey = ${profile.toggleKey}
              enableOnLaunch = True

              casSharpness = ${profile.casSharpness}
            '' + lib.optionalString (profile.extraConfig != "") ''

              ${profile.extraConfig}
            '';
          }
        ) cfg.vkbasalt.profiles);

        # Allow gamemode to renice processes
        security.pam.loginLimits = [
          { domain = "@gamemode"; type = "soft"; item = "nice"; value = -10; }
          { domain = "@gamemode"; type = "hard"; item = "nice"; value = -10; }
        ];

        # Gaming environment variables
        environment.sessionVariables = {
          MANGOHUD = lib.mkDefault "0";
          ENABLE_VKBASALT = lib.mkIf cfg.vkbasalt.enable (lib.mkDefault "0");
          DISABLE_LSFGVK = lib.mkIf cfg.lsfgVk.enable (lib.mkDefault "1");
          GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
          VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
        } // lib.optionalAttrs (config.myModules.hardware.graphics.amd.enable or false) {
          AMD_VULKAN_ICD = lib.mkDefault "RADV";
          RADV_PERFTEST = cfg.radv.perftest;
        };
      };
    };
}
