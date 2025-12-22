{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.audio;

  # =============================================================================
  # GoXLR UCM Profile Fix
  # =============================================================================
  # The GoXLR Mini audio interface requires a patched ALSA UCM configuration
  # to correctly report 21 channels instead of 23.
  fixedAlsaUcm = pkgs.alsa-ucm-conf.overrideAttrs (old: {
    postPatch = lib.concatStringsSep "\n" ([
      (old.postPatch or "")
      "target_file=\"ucm2/USB-Audio/GoXLR/GoXLR-HiFi.conf\""
      "if [ -f \"$target_file\" ]; then ${pkgs.gnused}/bin/sed -i 's/HWChannels 23/HWChannels 21/g' \"$target_file\"; fi"
    ]);
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.gnused ];
  });
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.audio = {
    enable = lib.mkEnableOption "Audio configuration with PipeWire";

    pipewire.lowLatency = lib.mkEnableOption "Low latency configuration (48kHz, 128 samples)";



    easyeffects.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install EasyEffects audio effects processor";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # PipeWire Audio Server
    # ==========================================================================
    # PipeWire is a modern audio/video server that replaces PulseAudio and JACK
    services.pipewire = {
      enable = true;

      # ALSA support (Advanced Linux Sound Architecture)
      alsa = {
        enable = true;
        support32Bit = true;  # Required for 32-bit applications and games
      };

      # PulseAudio compatibility layer
      pulse.enable = true;

      # JACK audio connection kit support (for pro audio)
      jack.enable = true;

      # Enable audio processing
      audio.enable = true;

      # WirePlumber session manager
      wireplumber.enable = true;

      # ----------------------------------------------------------------------
      # PipeWire Configuration (Low Latency)
      # ----------------------------------------------------------------------
      extraConfig.pipewire = lib.mkIf cfg.pipewire.lowLatency {
        "context.properties" = {
          # Sample rate (48kHz is standard for most audio interfaces)
          "default.clock.rate" = 48000;

          # Buffer size (256 samples = ~5.3ms latency)
          # 128 (2.7ms) is technically possible on this CPU but unstable for USB audio (GoXLR), causing crash loops.
          "default.clock.quantum" = 256;

          # Minimum buffer size (128 samples)
          "default.clock.min-quantum" = 128;

          # Maximum buffer size (2048 samples)
          "default.clock.max-quantum" = 2048;
        };
      };

      # ----------------------------------------------------------------------
      # PulseAudio Compatibility Configuration
      # ----------------------------------------------------------------------
      extraConfig."pipewire-pulse" = {
        "stream.properties" = {
          # Resampling quality (0-15, higher is better but more CPU intensive)
          "resample.quality" = 10;
        };
      };
    };

    # ==========================================================================
    # Audio Utilities
    # ==========================================================================
    environment.systemPackages = with pkgs; [
      pulsemixer  # Terminal-based PulseAudio mixer
      qpwgraph    # PipeWire graph editor (like qjackctl)
    ] ++ lib.optionals cfg.easyeffects.enable [
      easyeffects
    ];

    # ==========================================================================
    # User Configuration
    # ==========================================================================
    # Add primary user to audio group
    users.users.user.extraGroups = [ "audio" ];

    # NOTE: LD_LIBRARY_PATH override removed - it was interfering with library loading
    # PipeWire libraries are already properly exposed via NixOS module system

  };
}