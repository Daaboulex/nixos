{ inputs, ... }: {
  flake.nixosModules.hardware-goxlr = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.audio.goxlr;

      fixedAlsaUcm = pkgs.alsa-ucm-conf.overrideAttrs (old: {
        postPatch = lib.concatStringsSep "\n" ([
          (old.postPatch or "")
          "target_file=\"ucm2/USB-Audio/GoXLR/GoXLR-HiFi.conf\""
          "if [ -f \"$target_file\" ]; then ${pkgs.gnused}/bin/sed -i 's/HWChannels 23/HWChannels 21/g' \"$target_file\"; fi"
        ]);
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.gnused ];
      });

      flatEqFilters = "filters = []";
      dt990proEqFilters = ''
        filters = [
          { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },
          { type = bq_lowshelf, freq = 105.0, gain = 5.7, q = 0.70 },
          { type = bq_peaking, freq = 82.6, gain = -4.5, q = 0.67 },
          { type = bq_peaking, freq = 200.8, gain = -1.1, q = 2.44 },
          { type = bq_peaking, freq = 357.0, gain = 0.7, q = 3.56 },
          { type = bq_peaking, freq = 630.6, gain = 2.0, q = 1.25 },
          { type = bq_peaking, freq = 1038.8, gain = -1.4, q = 2.31 },
          { type = bq_peaking, freq = 2254.9, gain = 1.7, q = 2.37 },
          { type = bq_peaking, freq = 4629.2, gain = 4.7, q = 4.14 },
          { type = bq_peaking, freq = 6291.1, gain = -2.4, q = 4.64 },
          { type = bq_highshelf, freq = 10000.0, gain = -5.2, q = 0.70 },
          { type = bq_lowshelf, freq = 100.0, gain = 1.0, q = 1.0 },
        ]
      '';

      mkEqModule = name: targetSink: eqFilters: ''
        {
          name = libpipewire-module-filter-chain
          args = {
            node.description = "EQ ${name}"
            media.name = "EQ ${name}"
            filter.graph = {
              nodes = [ { type = builtin name = eq label = param_eq config = { ${eqFilters} } } ]
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

      enabledModules = lib.concatStringsSep "\n" (lib.filter (x: x != "") [
        (lib.optionalString cfg.eq.channels.system.enable (mkEqModule "System" cfg.eq.channels.system.sink cfg.eq.channels.system.eq))
        (lib.optionalString cfg.eq.channels.game.enable (mkEqModule "Game" cfg.eq.channels.game.sink cfg.eq.channels.game.eq))
        (lib.optionalString cfg.eq.channels.chat.enable (mkEqModule "Chat" cfg.eq.channels.chat.sink cfg.eq.channels.chat.eq))
        (lib.optionalString cfg.eq.channels.music.enable (mkEqModule "Music" cfg.eq.channels.music.sink cfg.eq.channels.music.eq))
        (lib.optionalString cfg.eq.channels.sample.enable (mkEqModule "Sample" cfg.eq.channels.sample.sink cfg.eq.channels.sample.eq))
      ]);

      # DeepFilterNet3 LADSPA denoiser with highpass pre-filter
      # Two-stage chain: HPF removes sub-bass keyboard rumble, then DF3 does neural suppression
      denoiseModule = ''
        {
          name = libpipewire-module-filter-chain
          args = {
            node.description = "Denoised Chat Mic"
            media.name = "Denoised Chat Mic"
            filter.graph = {
              nodes = [
                {
                  type = builtin
                  name = hpf
                  label = bq_highpass
                  control = { Freq = 120.0 Q = 0.707 }
                }
                {
                  type = ladspa
                  name = deepfilter
                  plugin = ${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so
                  label = deep_filter_mono
                  control = {
                    "Attenuation Limit (dB)" = ${toString cfg.denoise.attenuationLimit}
                    "Min processing threshold (dB)" = ${toString cfg.denoise.minThreshold}
                    "Max ERB processing threshold (dB)" = ${toString cfg.denoise.maxErbThreshold}
                    "Max DF processing threshold (dB)" = ${toString cfg.denoise.maxDfThreshold}
                    "Min Processing Buffer (frames)" = ${toString cfg.denoise.minProcessingBuffer}
                    "Post Filter Beta" = ${toString cfg.denoise.postFilterBeta}
                  }
                }
              ]
              links = [
                { output = "hpf:Out" input = "deepfilter:Audio In" }
              ]
            }
            audio.rate = 48000
            audio.channels = 1
            audio.position = [ MONO ]
            capture.props = {
              node.name = "denoised_chat_mic_capture"
              node.target = "${cfg.denoise.source}"
              node.passive = true
              stream.dont-remix = true
              node.latency = "960/48000"
            }
            playback.props = {
              node.name = "denoised_chat_mic"
              media.class = Audio/Source
              priority.session = 1500
            }
          }
        }
      '';
    in {
      options.myModules.audio.goxlr = {
        enable = lib.mkEnableOption "GoXLR Mini support";
        isMini = lib.mkOption { type = lib.types.bool; default = true; description = "Apply GoXLR Mini UCM patch"; };
        utility.enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable goxlr-utility daemon"; };
        installProfiles = lib.mkOption { type = lib.types.bool; default = true; description = "Install custom GoXLR UCM profiles"; };
        eq = {
          enable = lib.mkEnableOption "PipeWire parametric EQ for GoXLR channels";
          presets = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            readOnly = true;
            default = { flat = flatEqFilters; dt990pro = dt990proEqFilters; };
            description = "Built-in EQ presets (read-only). Use as values for channel eq options.";
          };
          clearStreamProperties = lib.mkOption { type = lib.types.bool; default = false; description = "Clear PipeWire stream properties before applying EQ filters"; };
          channels = {
            system = { enable = lib.mkEnableOption "EQ for System channel" // { default = true; }; sink = lib.mkOption { type = lib.types.str; default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Speaker__sink"; description = "PipeWire sink node name for System channel (adjust for full-size GoXLR)"; }; eq = lib.mkOption { type = lib.types.str; default = dt990proEqFilters; description = "PipeWire filter-chain EQ filter definition for System channel"; }; };
            game = { enable = lib.mkEnableOption "EQ for Game channel" // { default = true; }; sink = lib.mkOption { type = lib.types.str; default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line1__sink"; description = "PipeWire sink node name for Game channel (adjust for full-size GoXLR)"; }; eq = lib.mkOption { type = lib.types.str; default = dt990proEqFilters; description = "PipeWire filter-chain EQ filter definition for Game channel"; }; };
            chat = { enable = lib.mkEnableOption "EQ for Chat channel" // { default = true; }; sink = lib.mkOption { type = lib.types.str; default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Headphones__sink"; description = "PipeWire sink node name for Chat channel (adjust for full-size GoXLR)"; }; eq = lib.mkOption { type = lib.types.str; default = dt990proEqFilters; description = "PipeWire filter-chain EQ filter definition for Chat channel"; }; };
            music = { enable = lib.mkEnableOption "EQ for Music channel" // { default = true; }; sink = lib.mkOption { type = lib.types.str; default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line2__sink"; description = "PipeWire sink node name for Music channel (adjust for full-size GoXLR)"; }; eq = lib.mkOption { type = lib.types.str; default = dt990proEqFilters; description = "PipeWire filter-chain EQ filter definition for Music channel"; }; };
            sample = { enable = lib.mkEnableOption "EQ for Sample channel" // { default = true; }; sink = lib.mkOption { type = lib.types.str; default = "alsa_output.usb-TC-Helicon_GoXLRMini-00.HiFi__Line3__sink"; description = "PipeWire sink node name for Sample channel (adjust for full-size GoXLR)"; }; eq = lib.mkOption { type = lib.types.str; default = dt990proEqFilters; description = "PipeWire filter-chain EQ filter definition for Sample channel"; }; };
          };
        };
        toggle = {
          enable = lib.mkEnableOption "goxlr-toggle script for switching between active and sleep profiles";
          activeProfile = lib.mkOption {
            type = lib.types.str;
            default = "Default";
            description = "Device profile to load when waking (active state)";
          };
          activeMicProfile = lib.mkOption {
            type = lib.types.str;
            default = "Default";
            description = "Microphone profile to load when waking (active state)";
          };
          sleepProfile = lib.mkOption {
            type = lib.types.str;
            default = "Sleep";
            description = "Device profile to load when sleeping";
          };
          sleepMicProfile = lib.mkOption {
            type = lib.types.str;
            default = "Sleep";
            description = "Microphone profile to load when sleeping";
          };
        };
        denoise = {
          enable = lib.mkEnableOption "DeepFilterNet3 neural noise suppression on chat mic";
          source = lib.mkOption {
            type = lib.types.str;
            default = "alsa_input.usb-TC-Helicon_GoXLRMini-00.HiFi__Headset__source";
            description = "PipeWire node name of the raw microphone source";
          };
          attenuationLimit = lib.mkOption {
            type = lib.types.int;
            default = 70;
            description = "Max noise attenuation in dB (0-100). 70 avoids artifacts while maintaining full perceived suppression.";
          };
          minThreshold = lib.mkOption {
            type = lib.types.float;
            default = -15.0;
            description = "Min processing threshold in dB (-15 to 35).";
          };
          maxErbThreshold = lib.mkOption {
            type = lib.types.float;
            default = 20.0;
            description = "Max ERB processing threshold in dB (-15 to 35). Lower reduces muffling on loud speech.";
          };
          maxDfThreshold = lib.mkOption {
            type = lib.types.float;
            default = 20.0;
            description = "Max DF processing threshold in dB (-15 to 35). Lower prevents keyboard transient reconstruction.";
          };
          minProcessingBuffer = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Min processing buffer in frames (0-10). 0 = lowest latency.";
          };
          postFilterBeta = lib.mkOption {
            type = lib.types.float;
            default = 0.0;
            description = "Post-filter beta (0-0.05). 0 = disabled. DF3 is sufficient without it; higher values muffle voice.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        system.replaceDependencies.replacements = lib.mkIf cfg.isMini [
          { original = pkgs.alsa-ucm-conf; replacement = fixedAlsaUcm; }
        ];

        environment.etc = lib.mkIf (cfg.enable && cfg.installProfiles) {
          "alsa/ucm2/GoXLR/GoXLR.conf".text = ''SectionUseCase."HiFi" { File "HiFi.conf" Comment "Default" }'';
          "alsa/ucm2/GoXLR/HiFi.conf".text = ''
            SectionVerb { EnableSequence [ cset "name='Mic Playback Switch' off" cset "name='Line In Playback Switch' off" cset "name='Headphones Playback Switch' on" cset "name='Sampler Playback Switch' on" ] Value { TQ "HiFi" } }
            SectionDevice."Headphones" { Comment "Headphones" EnableSequence [ cset "name='Headphones Playback Switch' on" ] DisableSequence [ cset "name='Headphones Playback Switch' off" ] Value { PlaybackPCM "hw:GoXLR,0" JackControl "Headphones Jack" } }
          '';
        };

        services.goxlr-utility = lib.mkIf cfg.utility.enable { enable = true; autoStart.xdg = true; };

        environment.systemPackages = lib.mkIf cfg.toggle.enable [
          (pkgs.writeShellScriptBin "goxlr-toggle" ''
            current=$(goxlr-client --status-json 2>/dev/null \
              | ${pkgs.python3}/bin/python3 -c "
            import json, sys
            d = json.load(sys.stdin)
            for m in d.get(\"mixers\", {}).values():
                print(m.get(\"profile_name\", \"\")); break
            " 2>/dev/null)

            if [ "$current" = "${cfg.toggle.sleepProfile}" ]; then
              goxlr-client profiles device load "${cfg.toggle.activeProfile}"
              goxlr-client profiles microphone load "${cfg.toggle.activeMicProfile}"
              echo "GoXLR → Active (${cfg.toggle.activeProfile})"
            else
              goxlr-client profiles device load "${cfg.toggle.sleepProfile}"
              goxlr-client profiles microphone load "${cfg.toggle.sleepMicProfile}"
              echo "GoXLR → Sleep (${cfg.toggle.sleepProfile})"
            fi
          '')
        ];

        services.pipewire.configPackages =
          # EQ filter-chain sinks for GoXLR output channels
          lib.optionals (cfg.eq.enable && enabledModules != "") [
            (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/90-goxlr-eq.conf" ''
              context.modules = [ ${enabledModules} ]
            '')
          ]
          # DeepFilterNet3 denoiser for chat mic
          ++ lib.optionals cfg.denoise.enable [
            (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/91-goxlr-denoise.conf" ''
              context.modules = [ ${denoiseModule} ]
            '')
          ];

        # NOTE: Hiding raw GoXLR ALSA nodes from Plasma volume applet was
        # attempted extensively but is not feasible with PipeWire's current
        # permission model. The EQ filter chains target raw UCM sinks by
        # node.name, and any permission denial that hides them from
        # pipewire-pulse also breaks the audio graph. Approaches tried:
        #   1. monitor.alsa.rules media.class → overridden by createSplitPCMLoopback
        #   2. node.hidden / node.disabled → prevents node creation
        #   3. client permissions "-" to non-WP → kills audio graph
        #   4. node:update_properties() → not available on WpNode proxies
        #   5. "--x-" to non-WP → filter chains lose read access, can't link
        #   6. PID-based pulse-only deny → timing: pulse connects before nodes exist

        systemd.user.services.goxlr-clear-stream-props = lib.mkIf cfg.eq.clearStreamProperties {
          description = "Clear WirePlumber stream-properties";
          wantedBy = [ "graphical-session.target" ];
          before = [ "wireplumber.service" ];
          serviceConfig = { Type = "oneshot"; ExecStart = "${pkgs.coreutils}/bin/rm -f %h/.local/state/wireplumber/stream-properties"; };
        };
      };
    };
}
