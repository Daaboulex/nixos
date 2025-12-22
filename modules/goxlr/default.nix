{ config, pkgs, lib, ... }:

# =============================================================================
# GoXLR Mini Configuration Module
# =============================================================================
# This module consolidates all GoXLR Mini specific configuration:
# - UCM patch (23->21 channels fix)
# - EQ filter-chains for each channel
# - goxlr-utility service
# =============================================================================

let
  cfg = config.myModules.audio.goxlr;

  # ===========================================================================
  # GoXLR Mini UCM Patch
  # ===========================================================================
  # The GoXLR Mini requires a patched ALSA UCM configuration
  # to correctly report 21 channels instead of 23.
  fixedAlsaUcm = pkgs.alsa-ucm-conf.overrideAttrs (old: {
    postPatch = lib.concatStringsSep "\n" ([
      (old.postPatch or "")
      "target_file=\"ucm2/USB-Audio/GoXLR/GoXLR-HiFi.conf\""
      "if [ -f \"$target_file\" ]; then ${pkgs.gnused}/bin/sed -i 's/HWChannels 23/HWChannels 21/g' \"$target_file\"; fi"
    ]);
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.gnused ];
  });

  # ===========================================================================
  # EQ Presets
  # ===========================================================================
  
  # Flat passthrough (no EQ applied)
  flatEqFilters = ''
    filters = []
  '';

  # DT 990 Pro 250 Ohm EQ preset (from AutoEQ)
  dt990proEqFilters = ''
    filters = [
      # Preamp: -5.23 dB
      { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },
      # Filter 1: LSC Fc 105.0 Hz Gain 5.7 dB Q 0.70
      { type = bq_lowshelf, freq = 105.0, gain = 5.7, q = 0.70 },
      # Filter 2: PK Fc 82.6 Hz Gain -4.5 dB Q 0.67
      { type = bq_peaking, freq = 82.6, gain = -4.5, q = 0.67 },
      # Filter 3: PK Fc 200.8 Hz Gain -1.1 dB Q 2.44
      { type = bq_peaking, freq = 200.8, gain = -1.1, q = 2.44 },
      # Filter 4: PK Fc 357.0 Hz Gain 0.7 dB Q 3.56
      { type = bq_peaking, freq = 357.0, gain = 0.7, q = 3.56 },
      # Filter 5: PK Fc 630.6 Hz Gain 2.0 dB Q 1.25
      { type = bq_peaking, freq = 630.6, gain = 2.0, q = 1.25 },
      # Filter 6: PK Fc 1038.8 Hz Gain -1.4 dB Q 2.31
      { type = bq_peaking, freq = 1038.8, gain = -1.4, q = 2.31 },
      # Filter 7: PK Fc 2254.9 Hz Gain 1.7 dB Q 2.37
      { type = bq_peaking, freq = 2254.9, gain = 1.7, q = 2.37 },
      # Filter 8: PK Fc 4629.2 Hz Gain 4.7 dB Q 4.14
      { type = bq_peaking, freq = 4629.2, gain = 4.7, q = 4.14 },
      # Filter 9: PK Fc 6291.1 Hz Gain -2.4 dB Q 4.64
      { type = bq_peaking, freq = 6291.1, gain = -2.4, q = 4.64 },
      # Filter 10: HSC Fc 10000.0 Hz Gain -5.2 dB Q 0.70
      { type = bq_highshelf, freq = 10000.0, gain = -5.2, q = 0.70 },
      # Filter 11: LSC Fc 100.0 Hz Gain 1.0 dB Q 1.0
      { type = bq_lowshelf, freq = 100.0, gain = 1.0, q = 1.0 },
    ]
  '';

  # ===========================================================================
  # EQ Filter-Chain Generator
  # ===========================================================================
  mkEqModule = name: targetSink: eqFilters: ''
    {
      name = libpipewire-module-filter-chain
      args = {
        node.description = "EQ ${name}"
        media.name = "EQ ${name}"
        filter.graph = {
          nodes = [
            {
              type = builtin
              name = eq
              label = param_eq
              config = { ${eqFilters} }
            }
          ]
          links = []
        }
        audio.channels = 2
        audio.position = [ FL FR ]
        capture.props = {
          node.name = "eq_${lib.toLower name}"
          media.class = Audio/Sink
          priority.session = 1500
          device.class = "sound"
          device.api = "filter-chain"
        }
        playback.props = {
          node.name = "eq_${lib.toLower name}_out"
          node.target = "${targetSink}"
          node.passive = true
          stream.dont-remix = true
          stream.reconnect = true
        }
      }
    }
  '';

  # Build enabled EQ modules list
  enabledModules = lib.concatStringsSep "\n" (lib.filter (x: x != "") [
    (lib.optionalString cfg.eq.channels.system.enable
      (mkEqModule "System" cfg.eq.channels.system.sink cfg.eq.channels.system.eq))
    (lib.optionalString cfg.eq.channels.game.enable
      (mkEqModule "Game" cfg.eq.channels.game.sink cfg.eq.channels.game.eq))
    (lib.optionalString cfg.eq.channels.chat.enable
      (mkEqModule "Chat" cfg.eq.channels.chat.sink cfg.eq.channels.chat.eq))
    (lib.optionalString cfg.eq.channels.music.enable
      (mkEqModule "Music" cfg.eq.channels.music.sink cfg.eq.channels.music.eq))
    (lib.optionalString cfg.eq.channels.sample.enable
      (mkEqModule "Sample" cfg.eq.channels.sample.sink cfg.eq.channels.sample.eq))
  ]);

in
{
  # ===========================================================================
  # Module Options
  # ===========================================================================
  options.myModules.audio.goxlr = {
    enable = lib.mkEnableOption "GoXLR Mini support";

    isMini = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply GoXLR Mini UCM patch (23->21 channels)";
    };

    utility.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable goxlr-utility daemon";
    };

    installProfiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install custom GoXLR UCM profiles";
    };

    # -------------------------------------------------------------------------
    # EQ Options
    # -------------------------------------------------------------------------
    eq = {
      enable = lib.mkEnableOption "PipeWire parametric EQ for GoXLR channels";

      presets = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = {
          flat = flatEqFilters;
          dt990pro = dt990proEqFilters;
        };
        description = "Available EQ presets (use config.myModules.audio.goxlr.eq.presets.<name>)";
      };

      clearStreamProperties = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Clear WirePlumber stream-properties on login (reset app audio preferences).
          Enable once after setup, then disable.
        '';
      };

      channels = {
        system = {
          enable = lib.mkEnableOption "EQ for System channel" // { default = true; };
          sink = lib.mkOption {
            type = lib.types.str;
            default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Speaker__sink";
          };
          eq = lib.mkOption {
            type = lib.types.str;
            default = dt990proEqFilters;
            description = "EQ filters (PipeWire filter-chain format)";
          };
        };
        game = {
          enable = lib.mkEnableOption "EQ for Game channel" // { default = true; };
          sink = lib.mkOption {
            type = lib.types.str;
            default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line1__sink";
          };
          eq = lib.mkOption {
            type = lib.types.str;
            default = dt990proEqFilters;
          };
        };
        chat = {
          enable = lib.mkEnableOption "EQ for Chat channel" // { default = true; };
          sink = lib.mkOption {
            type = lib.types.str;
            default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Headphones__sink";
          };
          eq = lib.mkOption {
            type = lib.types.str;
            default = dt990proEqFilters;
          };
        };
        music = {
          enable = lib.mkEnableOption "EQ for Music channel" // { default = true; };
          sink = lib.mkOption {
            type = lib.types.str;
            default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line2__sink";
          };
          eq = lib.mkOption {
            type = lib.types.str;
            default = dt990proEqFilters;
          };
        };
        sample = {
          enable = lib.mkEnableOption "EQ for Sample channel" // { default = true; };
          sink = lib.mkOption {
            type = lib.types.str;
            default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line3__sink";
          };
          eq = lib.mkOption {
            type = lib.types.str;
            default = dt990proEqFilters;
          };
        };
      };
    };
  };

  # ===========================================================================
  # Module Configuration
  # ===========================================================================
  config = lib.mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # GoXLR Mini UCM Patch
    # -------------------------------------------------------------------------
    system.replaceDependencies.replacements = lib.mkIf cfg.isMini [
      {
        original = pkgs.alsa-ucm-conf;
        replacement = fixedAlsaUcm;
      }
    ];

    # -------------------------------------------------------------------------
    # Custom UCM Profiles
    # -------------------------------------------------------------------------
    environment.etc = lib.mkIf (cfg.enable && cfg.installProfiles) {

      # Main GoXLR configuration
      "alsa/ucm2/GoXLR/GoXLR.conf".text = ''
        SectionUseCase."HiFi" { File "HiFi.conf" Comment "Default" }
      '';

      # HiFi profile configuration
      "alsa/ucm2/GoXLR/HiFi.conf".text = ''
        SectionVerb { EnableSequence [ cset "name='Mic Playback Switch' off" cset "name='Line In Playback Switch' off" cset "name='Headphones Playback Switch' on" cset "name='Sampler Playback Switch' on" ] Value { TQ "HiFi" } }
        SectionDevice."Headphones" { Comment "Headphones" EnableSequence [ cset "name='Headphones Playback Switch' on" ] DisableSequence [ cset "name='Headphones Playback Switch' off" ] Value { PlaybackPCM "hw:GoXLR,0" JackControl "Headphones Jack" } }
      '';
    };

    # -------------------------------------------------------------------------
    # GoXLR Utility Daemon
    # -------------------------------------------------------------------------
    services.goxlr-utility = lib.mkIf cfg.utility.enable {
      enable = true;
      autoStart.xdg = true;
    };

    # -------------------------------------------------------------------------
    # PipeWire EQ Filter-Chains
    # -------------------------------------------------------------------------
    services.pipewire.configPackages = lib.mkIf (cfg.eq.enable && enabledModules != "") [
      (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/90-goxlr-eq.conf" ''
        context.modules = [
          ${enabledModules}
        ]
      '')
    ];

    # -------------------------------------------------------------------------
    # Stream Properties Cleanup (optional)
    # -------------------------------------------------------------------------
    systemd.user.services.goxlr-clear-stream-props = lib.mkIf cfg.eq.clearStreamProperties {
      description = "Clear WirePlumber stream-properties";
      wantedBy = [ "graphical-session.target" ];
      before = [ "wireplumber.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/rm -f %h/.local/state/wireplumber/stream-properties";
      };
    };
  };
}
