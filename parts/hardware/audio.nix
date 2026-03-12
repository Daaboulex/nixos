{ inputs, ... }:
{
  flake.nixosModules.hardware-audio =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.audio;
    in
    {
      _class = "nixos";
      options.myModules.hardware.audio = {
        enable = lib.mkEnableOption "Audio configuration with PipeWire";
        pipewire.lowLatency = lib.mkEnableOption "Low latency configuration (48kHz, 128 samples)";
        easyeffects.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install EasyEffects audio effects processor";
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

          extraConfig.pipewire = lib.mkIf cfg.pipewire.lowLatency {
            "context.properties" = {
              "default.clock.rate" = 48000;
              "default.clock.quantum" = 256;
              "default.clock.min-quantum" = 128;
              "default.clock.max-quantum" = 2048;
            };
          };

          extraConfig."pipewire-pulse" = {
            "stream.properties" = {
              "resample.quality" = 10;
            };
          };
        };

        environment.systemPackages =
          with pkgs;
          [
            pulsemixer
            qpwgraph
          ]
          ++ lib.optionals cfg.easyeffects.enable [
            easyeffects
          ];

        users.users.${config.myModules.primaryUser}.extraGroups = [
          "audio"
          "video"
        ];
      };
    };
}
