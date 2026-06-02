# goxlr-denoise — pipewire RNNoise filter chain for GoXLR Chat Mic.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.goxlr.denoise;
  parentCfg = config.myModules.home.goxlr;
  deviceName = if parentCfg.isMini then "GoXLRMini" else "GoXLR";

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
              control = { Freq = 80.0 Q = 0.707 }
            }
            {
              type = ladspa
              name = deepfilter
              plugin = libdeep_filter_ladspa
              label = deep_filter_mono
              control = {
                "Attenuation Limit (dB)" = ${toString cfg.attenuationLimit}
                "Min processing threshold (dB)" = ${toString cfg.minThreshold}
                "Max ERB processing threshold (dB)" = ${toString cfg.maxErbThreshold}
                "Max DF processing threshold (dB)" = ${toString cfg.maxDfThreshold}
                "Min Processing Buffer (frames)" = ${toString cfg.minProcessingBuffer}
                "Post Filter Beta" = ${toString cfg.postFilterBeta}
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
          node.target = "${cfg.source}"
          node.passive = true
          stream.dont-remix = true
          node.latency = "960/48000"
        }
        playback.props = {
          node.name = "denoised_chat_mic"
          media.class = Audio/Source
          priority.session = 2500
        }
      }
    }
  '';
in
{
  options.myModules.home.goxlr.denoise = {
    enable = lib.mkEnableOption "DeepFilterNet3 neural noise suppression on chat mic";
    # isMini is inherited from myModules.home.goxlr.isMini (parent module)
    source = lib.mkOption {
      type = lib.types.str;
      default = "alsa_input.usb-TC-Helicon_${deviceName}-00.HiFi__Headset__source";
      description = "PipeWire node name of the raw microphone source";
    };
    attenuationLimit = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Max noise attenuation in dB (0-100). 100 = no limit (official default). 6-12 = light, 18-24 = medium.";
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
      default = 12.0;
      description = "Max DF processing threshold in dB (-15 to 35). Lower suppresses transient noise (claps, bumps). Below 10 risks affecting plosives.";
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

  config = lib.mkIf cfg.enable {
    xdg.configFile."pipewire/pipewire.conf.d/91-goxlr-denoise.conf".text = ''
      context.modules = [ ${denoiseModule} ]
    '';

  };
}
