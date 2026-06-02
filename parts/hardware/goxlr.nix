# goxlr — GoXLR Mini audio mixer support (goxlr-utility daemon and udev).
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
      cfg = config.myModules.hardware.goxlr;

      fixedAlsaUcm = pkgs.alsa-ucm-conf.overrideAttrs (old: {
        postPatch = lib.concatStringsSep "\n" [
          (old.postPatch or "")
          "target_file=\"ucm2/USB-Audio/GoXLR/GoXLR-HiFi.conf\""
          "if [ -f \"$target_file\" ]; then ${pkgs.gnused}/bin/sed -i 's/HWChannels 23/HWChannels 21/g' \"$target_file\"; fi"
        ];
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.gnused ];
      });
    in
    {
      _class = "nixos";
      options.myModules.hardware.goxlr = {
        enable = lib.mkEnableOption "GoXLR Mini support";
        isMini = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply GoXLR Mini UCM patch";
        };
        utility.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "goxlr-utility daemon";
        };
        installProfiles = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install custom GoXLR UCM profiles";
        };
      };

      config = lib.mkIf cfg.enable {
        system.replaceDependencies.replacements = lib.mkIf cfg.isMini [
          {
            original = pkgs.alsa-ucm-conf;
            replacement = fixedAlsaUcm;
          }
        ];

        environment.etc = lib.mkIf (cfg.enable && cfg.installProfiles) {
          "alsa/ucm2/GoXLR/GoXLR.conf".text =
            ''SectionUseCase."HiFi" { File "HiFi.conf" Comment "Default" }'';
          "alsa/ucm2/GoXLR/HiFi.conf".text = ''
            SectionVerb { EnableSequence [ cset "name='Mic Playback Switch' off" cset "name='Line In Playback Switch' off" cset "name='Headphones Playback Switch' on" cset "name='Sampler Playback Switch' on" ] Value { TQ "HiFi" } }
            SectionDevice."Headphones" { Comment "Headphones" EnableSequence [ cset "name='Headphones Playback Switch' on" ] DisableSequence [ cset "name='Headphones Playback Switch' off" ] Value { PlaybackPCM "hw:GoXLR,0" JackControl "Headphones Jack" } }
          '';
        };

        services.goxlr-utility = lib.mkIf cfg.utility.enable {
          enable = true;
          autoStart.xdg = true;
        };

        # NOTE: Hiding raw GoXLR ALSA nodes from Plasma volume applet was
        # attempted extensively but is not feasible with PipeWire's current
        # permission model. The EQ filter chains target raw UCM sinks by
        # node.name, and any permission denial that hides them from
        # pipewire-pulse also breaks the audio graph. Approaches tried:
        #   1. monitor.alsa.rules media.class -> overridden by createSplitPCMLoopback
        #   2. node.hidden / node.disabled -> prevents node creation
        #   3. client permissions "-" to non-WP -> kills audio graph
        #   4. node:update_properties() -> not available on WpNode proxies
        #   5. "--x-" to non-WP -> filter chains lose read access, can't link
        #   6. PID-based pulse-only deny -> timing: pulse connects before nodes exist
      };
    };
in
{
  flake.modules.nixos.hardware-goxlr = mod;
}
