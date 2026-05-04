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
      };

      config = lib.mkIf cfg.enable {
        services.pipewire = {
          enable = true;
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
