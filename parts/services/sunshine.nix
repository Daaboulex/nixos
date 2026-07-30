# sunshine — Sunshine game streaming server (Moonlight-compatible).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.services.sunshine;
    in
    {
      _class = "nixos";
      options.myModules.services.sunshine = {
        enable = lib.mkEnableOption "Sunshine game streaming server (Moonlight-compatible)";

        outputName = lib.mkOption {
          type = lib.types.str;
          default = "0";
          description = "Display index to capture (Wayland uses numeric index, check sunshine.log for 'Found display: <N>').";
        };

        adapterName = lib.mkOption {
          type = lib.types.str;
          default = "/dev/dri/renderD128";
          description = "GPU render node for hardware encoding.";
        };

        encoder = lib.mkOption {
          type = lib.types.enum [
            "vaapi"
            "nvenc"
            "amf"
            "quicksync"
            "software"
          ];
          default = "vaapi";
          description = "Hardware encoder. AMD on Linux uses vaapi (Mesa).";
        };

        audioSink = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "PipeWire sink to capture. Null = default monitor. Set to .monitor of your speakers to stream WHILE audio plays on desktop.";
        };

        virtualSink = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Virtual sink name — creates a separate sink so audio ONLY goes to stream, silent on desktop. Set to null to mirror to desktop instead.";
        };

        streamAudioToClientAndHost = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "If true, audio plays on desktop speakers AND streams to Moonlight (clone). If false, only streams (silent locally).";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Additional Sunshine settings merged into services.sunshine.settings.";
        };

        applications = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Applications exposed to Moonlight (services.sunshine.applications).";
        };
      };

      config = lib.mkIf cfg.enable {
        # Moonlight input injection: sunshine (a user service) opens /dev/uinput,
        # which is root:uinput -- without the group, streamed keyboard/mouse
        # silently do nothing. Supplementary groups are read when the user
        # manager starts, so the grant lands at the next login/reboot.
        hardware.uinput.enable = true;
        users.users.${config.myModules.primaryUser}.extraGroups = [ "uinput" ];

        services.sunshine = {
          enable = true;
          autoStart = true;
          capSysAdmin = true; # Required for Wayland DRM/KMS capture
          openFirewall = true; # TCP 47984,47989,47990,48010 + UDP 47998-48000,8000-8010

          settings = lib.mkMerge [
            # Video / display — tuned for Switch client + RX 9070 XT on LAN
            {
              output_name = cfg.outputName;
              adapter_name = cfg.adapterName;
              inherit (cfg) encoder;

              # Codec: Switch Moonlight-NX has NO hardware HEVC decoder (CPU-only decode).
              # Force H.264 — HEVC at high bitrate overwhelms the Switch CPU and adds latency.
              hevc_mode = "0";
              av1_mode = "0"; # Switch cannot decode AV1

              # Rate control — AMD VAAPI CBR has overshoot issues (LizardByte#1040).
              # VBR-latency is safer; strict RC buffer prevents VBV overflow → fewer FEC drops.
              vaapi_strict_rc_buffer = "enabled";
              qp = "22"; # Fallback if CBR falls through — 22 is visually near-lossless

              # CPU threading — Ryzen 9950X3D has plenty, spend cores on encode speed
              min_threads = "8";

              # FEC: 20% is ideal for wired LAN (Switch WiFi tolerates well)
              fec_percentage = "20";

              # FPS advertisement — lets client pick cleanly
              fps = "[30, 60, 90, 120, 144]";
            }

            # Audio routing. virtual_sink is written exactly once: an explicit
            # cfg.virtualSink wins; else exclusive streaming gets the default
            # sunshine sink; else it stays unset (clone mode, audio also plays on
            # the desktop). Writing it from two normal-priority mkIf branches
            # mkMerge-conflicts when an explicit virtualSink meets exclusive
            # streaming, which fails the whole nixosConfiguration eval.
            (
              let
                sink =
                  if cfg.virtualSink != null then
                    cfg.virtualSink
                  else if !cfg.streamAudioToClientAndHost then
                    "sink-sunshine-stereo"
                  else
                    null;
              in
              lib.optionalAttrs (sink != null) { virtual_sink = sink; }
            )
            (lib.mkIf (cfg.audioSink != null) {
              audio_sink = cfg.audioSink;
            })

            cfg.extraSettings
          ];

          inherit (cfg) applications;
        };
      };
    };
in
{
  flake.modules.nixos.services-sunshine = mod;

}
