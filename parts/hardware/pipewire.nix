# pipewire — audio stack via PipeWire (ALSA, JACK, PulseAudio compatibility).
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
      cfg = config.myModules.hardware.pipewire;
    in
    {
      _class = "nixos";
      options.myModules.hardware.pipewire = {
        enable = lib.mkEnableOption "Audio configuration with PipeWire";
        lowLatency = lib.mkEnableOption "Low latency configuration (48kHz, quantum 256)";
        quantum = lib.mkOption {
          type = lib.types.int;
          default = 256;
          description = "Audio buffer size in samples (lower = less latency, more CPU). 256=5.3ms, 512=10.7ms, 1024=21ms";
        };
        extraLadspaPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "LADSPA plugin packages forwarded to services.pipewire.extraLadspaPackages";
        };
      };

      config = lib.mkIf cfg.enable {
        services.pipewire = {
          enable = true;
          inherit (cfg) extraLadspaPackages;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          pulse.enable = true;
          jack.enable = true;
          audio.enable = true;
          wireplumber.enable = true;

          extraConfig.pipewire = lib.mkMerge [
            {
              # Disable x11-bell module — unnecessary on Wayland, and its error
              # handler calls exit() which kills PipeWire, cascading into a full
              # session exit. Every session crash tonight went through this path.
              "context.properties"."module.x11.bell" = false;
            }
            (lib.mkIf cfg.lowLatency {
              "context.properties" = {
                "default.clock.rate" = 48000;
                "default.clock.allowed-rates" = [
                  44100
                  48000
                ]; # Avoid resampling music (44.1kHz) content
                "default.clock.quantum" = cfg.quantum;
                "default.clock.min-quantum" = cfg.quantum / 2;
                "default.clock.max-quantum" = 2048;
              };
            })
          ];

          extraConfig."pipewire-pulse" = {
            "stream.properties" = {
              "resample.quality" = 10;
            };
          };
        };

        # PipeWire 1.6.3 SPA filter-graph plugins reference spa_log_topic_enum
        # from libspa-support.so, but PipeWire loads SPA plugins via dlopen
        # without RTLD_GLOBAL — the symbol isn't visible. Preload libspa-support
        # so its symbols are globally available to all SPA plugins.
        # Why: without this, filter-chain (EQ, denoise) crashes PipeWire with
        # "undefined symbol: spa_log_topic_enum".
        systemd.user.services.pipewire.environment.LD_PRELOAD =
          "${config.services.pipewire.package}/lib/spa-0.2/support/libspa-support.so";

        users.users.${config.myModules.primaryUser}.extraGroups = [
          "audio"
          "video"
        ];
      };
    };
in
{
  flake.modules.nixos.hardware-pipewire = mod;

}
