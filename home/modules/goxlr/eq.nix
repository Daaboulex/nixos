# goxlr-eq — pipewire parametric EQ filter chains for GoXLR channels.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.goxlr.eq;
  parentCfg = config.myModules.home.goxlr;
  deviceName = if parentCfg.isMini then "GoXLRMini" else "GoXLR";

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

  enabledModules = lib.concatStringsSep "\n" (
    lib.filter (x: x != "") [
      (lib.optionalString cfg.channels.system.enable (
        mkEqModule "System" cfg.channels.system.sink cfg.channels.system.eq
      ))
      (lib.optionalString cfg.channels.game.enable (
        mkEqModule "Game" cfg.channels.game.sink cfg.channels.game.eq
      ))
      (lib.optionalString cfg.channels.chat.enable (
        mkEqModule "Chat" cfg.channels.chat.sink cfg.channels.chat.eq
      ))
      (lib.optionalString cfg.channels.music.enable (
        mkEqModule "Music" cfg.channels.music.sink cfg.channels.music.eq
      ))
      (lib.optionalString cfg.channels.sample.enable (
        mkEqModule "Sample" cfg.channels.sample.sink cfg.channels.sample.eq
      ))
    ]
  );
in
{
  options.myModules.home.goxlr.eq = {
    enable = lib.mkEnableOption "PipeWire parametric EQ for GoXLR channels";
    # isMini is inherited from myModules.home.goxlr.isMini (parent module)
    presets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = {
        flat = flatEqFilters;
        dt990pro = dt990proEqFilters;
      };
      description = "Built-in EQ presets (read-only). Use as values for channel eq options.";
    };
    clearStreamProperties = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Clear PipeWire stream properties before applying EQ filters";
    };
    channels = {
      system = {
        enable = lib.mkEnableOption "EQ for System channel" // {
          default = true;
        };
        sink = lib.mkOption {
          type = lib.types.str;
          default = "alsa_output.usb-TC-Helicon_${deviceName}-00.HiFi__Speaker__sink";
          description = "PipeWire sink node name for System channel";
        };
        eq = lib.mkOption {
          type = lib.types.str;
          default = dt990proEqFilters;
          description = "PipeWire filter-chain EQ filter definition for System channel";
        };
      };
      game = {
        enable = lib.mkEnableOption "EQ for Game channel" // {
          default = true;
        };
        sink = lib.mkOption {
          type = lib.types.str;
          default = "alsa_output.usb-TC-Helicon_${deviceName}-00.HiFi__Line1__sink";
          description = "PipeWire sink node name for Game channel";
        };
        eq = lib.mkOption {
          type = lib.types.str;
          default = dt990proEqFilters;
          description = "PipeWire filter-chain EQ filter definition for Game channel";
        };
      };
      chat = {
        enable = lib.mkEnableOption "EQ for Chat channel" // {
          default = true;
        };
        sink = lib.mkOption {
          type = lib.types.str;
          default = "alsa_output.usb-TC-Helicon_${deviceName}-00.HiFi__Headphones__sink";
          description = "PipeWire sink node name for Chat channel";
        };
        eq = lib.mkOption {
          type = lib.types.str;
          default = dt990proEqFilters;
          description = "PipeWire filter-chain EQ filter definition for Chat channel";
        };
      };
      music = {
        enable = lib.mkEnableOption "EQ for Music channel" // {
          default = true;
        };
        sink = lib.mkOption {
          type = lib.types.str;
          default = "alsa_output.usb-TC-Helicon_${deviceName}-00.HiFi__Line2__sink";
          description = "PipeWire sink node name for Music channel";
        };
        eq = lib.mkOption {
          type = lib.types.str;
          default = dt990proEqFilters;
          description = "PipeWire filter-chain EQ filter definition for Music channel";
        };
      };
      sample = {
        enable = lib.mkEnableOption "EQ for Sample channel" // {
          default = true;
        };
        sink = lib.mkOption {
          type = lib.types.str;
          default = "alsa_output.usb-TC-Helicon_${deviceName}-00.HiFi__Line3__sink";
          description = "PipeWire sink node name for Sample channel";
        };
        eq = lib.mkOption {
          type = lib.types.str;
          default = dt990proEqFilters;
          description = "PipeWire filter-chain EQ filter definition for Sample channel";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."pipewire/pipewire.conf.d/90-goxlr-eq.conf" = lib.mkIf (enabledModules != "") {
      text = ''
        context.modules = [ ${enabledModules} ]
      '';
    };

    systemd.user.services.goxlr-clear-stream-props = lib.mkIf cfg.clearStreamProperties {
      Unit = {
        Description = "Clear WirePlumber stream-properties";
        Before = [ "wireplumber.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/rm -f %h/.local/state/wireplumber/stream-properties";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
