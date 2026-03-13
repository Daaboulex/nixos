{
  lib,
  options,
  ...
}:

{
  # ============================================================================
  # GoXLR — Declarative mixer configuration via goxlr-client
  # ============================================================================
  # Two-layer architecture:
  #   NixOS  (parts/goxlr.nix) → daemon, UCM profiles, PipeWire EQ, denoise,
  #                                toggle script, system packages
  #   HM     (this module)      → user-facing mixer state via goxlr-client
  #
  # The external goxlr-hm-nix module (imported via sharedModules) provides
  # the full option interface with these sections:
  #   - device:             serial number for multi-device setups (nullable str)
  #   - profile/micProfile: device/mic profile names to load (nullable str)
  #   - volumes:            per-channel volume levels (attrsOf int, 0-100)
  #   - faders:             fader-to-channel assignments (attrsOf str)
  #   - faderMuteBehaviour: per-fader mute routing (attrsOf str)
  #   - faderMuteState:     per-fader mute state (attrsOf str)
  #   - scribbles:          fader OLED display text (attrsOf submodule, Full-only)
  #   - routing:            input→output routing matrix (attrsOf (attrsOf bool))
  #   - microphone:         mic gain, gate, compressor, EQ (submodule)
  #   - submix:             submix volumes/linking/routing (submodule)
  #   - effects:            voice effects presets (submodule, Full-only)
  #   - sampler:            sample pad config (attrsOf submodule, Full-only)
  #   - coughButton:        cough mute behaviour (submodule)
  #   - bleepVolume:        bleep/censor volume (nullable int)
  #   - settings:           device-wide settings (submodule)
  #   - lighting:           button/fader/encoder LED colours (submodule)
  #   - extraCommands:      additional goxlr-client commands (listOf str)
  #
  # This wrapper defaults all behavioural/scalar options. Host configs set
  # hardware-specific values: volumes, routing, microphone, lighting colours.
  #
  # Applied via systemd user service on login (goxlr-client commands).
  #
  # Guarded: only applies when the goxlr-hm-nix HM module is loaded.

  config = lib.optionalAttrs (options.programs ? goxlr) {
    programs.goxlr = {

      # ── Device serial ─────────────────────────────────────────────────
      # device: nullable str — only needed for multi-GoXLR setups.
      # null = auto-detect single connected device.

      # ── Profiles ──────────────────────────────────────────────────────
      # profile:    nullable str — device profile to load (set per-host)
      # micProfile: nullable str — microphone profile to load (set per-host)
      # Profiles are stored on the daemon; names come from GoXLR app.

      # ── Volumes ───────────────────────────────────────────────────────
      # volumes: attrsOf int (0-100) — per-channel volume levels.
      # Channels: mic, chat, music, game, console, system, sample,
      #           headphones, mic-monitor, line-out, line-in
      # Set per-host: levels depend on audio setup and personal preference.

      # ── Fader assignments ─────────────────────────────────────────────
      # faders: attrsOf str — which channel each fader (a/b/c/d) controls.
      # Set per-host: depends on workflow and monitoring needs.

      # ── Fader mute behaviour ──────────────────────────────────────────
      # What happens when a fader's mute button is pressed.
      # Options: "all", "to-stream", "to-voice-chat", "to-phones", "to-line-out"
      faderMuteBehaviour = lib.mkDefault {
        a = "all";
        b = "all";
        c = "all";
        d = "all";
      };

      # ── Fader mute state ──────────────────────────────────────────────
      # faderMuteState: attrsOf str — current mute state per fader.
      # Options: "unmuted", "muted-to-x", "muted-to-all"
      # Set per-host if you want specific faders muted on login.

      # ── Scribbles (Full-only) ─────────────────────────────────────────
      # scribbles: attrsOf submodule — OLED text/icon on each fader.
      # Each: icon (str), text (str), number (str), invert (bool)
      # Not available on GoXLR Mini.

      # ── Routing ───────────────────────────────────────────────────────
      # routing: attrsOf (attrsOf bool) — audio routing matrix.
      # Maps inputs (microphone, chat, music, game, console, line-in,
      #   system, samples) to outputs (headphones, broadcast-mix,
      #   chat-mic, sampler, line-out, stream-mix2).
      # Set per-host: depends on streaming/recording setup.

      # ── Microphone ────────────────────────────────────────────────────
      # microphone: submodule — mic gain, processing, and EQ.
      #   dynamicGain:   int — gain for dynamic mics (0-72 dB)
      #   condenserGain: int — gain for condenser mics (0-72 dB)
      #   jackGain:      int — gain for 3.5mm input (0-72 dB)
      #   deEss:         int — de-esser strength (0-100)
      #   monitorWithFx: bool — monitor mic with effects applied
      #   gate:          submodule — noise gate
      #     threshold:   int (-59 to 0 dB)
      #     attenuation: int (0-100 dB)
      #     attack:      str — e.g. "gate10ms"
      #     release:     str — e.g. "gate200ms"
      #     active:      bool
      #   compressor:    submodule — dynamics compressor
      #     threshold:   int (-40 to 0 dB)
      #     ratio:       str — e.g. "ratio3-2"
      #     attack:      str — e.g. "comp3ms"
      #     release:     str — e.g. "comp230ms"
      #     makeUp:      int (0-24 dB)
      #   equaliser:     attrsOf {frequency, gain} — Full 6-band EQ
      #   equaliserMini: attrsOf {frequency, gain} — Mini 3-band EQ
      # Set per-host: depends on microphone hardware and room acoustics.

      # ── Submix ────────────────────────────────────────────────────────
      # Submix allows independent volume control for monitor vs stream.
      submix.enabled = lib.mkDefault false;
      # submix.volumes:    attrsOf int — per-channel submix levels (set per-host)
      # submix.linked:     attrsOf bool — link submix to main volume (set per-host)
      # submix.outputMix:  attrsOf str — output → submix assignment "a"/"b" (set per-host)
      # submix.monitorMix: str — which output is the monitor (set per-host)

      # ── Cough button ──────────────────────────────────────────────────
      coughButton = {
        isHold = lib.mkDefault false;
        muteBehaviour = lib.mkDefault "all";
        # muteState: nullable str — initial cough state (set per-host if needed)
      };

      # ── Bleep button ──────────────────────────────────────────────────
      # Volume for the censor bleep sound (dB, typically negative).
      bleepVolume = lib.mkDefault 0;

      # ── Device settings ───────────────────────────────────────────────
      settings = {
        # How long to hold mute button before toggle vs momentary (ms)
        muteHoldDuration = lib.mkDefault 500;
        # Pre-record buffer for sampler in ms (Full-only)
        samplePreRecordBuffer = lib.mkDefault 0;
        # Apply effects to monitor output
        monitorWithFx = lib.mkDefault false;
        # Mute headphones when chat channel is muted
        deafenOnChatMute = lib.mkDefault true;
        # Prevent fader movement from changing volumes
        lockFaders = lib.mkDefault false;
      };

      # ── Lighting ──────────────────────────────────────────────────────
      lighting = {
        # LED animation mode: "none", "rainbow-retro", "rainbow-bright",
        # "rainbow-dark", "simple", "ripple"
        animation = {
          mode = lib.mkDefault "none";
          mod1 = lib.mkDefault 0;
          mod2 = lib.mkDefault 0;
          waterfall = lib.mkDefault "down";
        };
        # lighting.global:   nullable str — global colour hex (set per-host)
        # lighting.fadersAll: submodule — bulk fader lighting (set per-host)
        # lighting.faders:   attrsOf submodule — per-fader colours (set per-host)
        #   Each: display (str), top (hex), bottom (hex)
        # lighting.buttons:  attrsOf submodule — per-button colours (set per-host)
        #   Each: colour (hex), colour2 (hex), offStyle (str)
        #   Mini buttons: fader1-mute..fader4-mute, cough, bleep
        #   Full buttons: above + effect-select1..6, effect-fx, effect-megaphone,
        #                 effect-robot, effect-hard-tune
        # lighting.buttonGroups: attrsOf submodule — group colours (set per-host)
        # lighting.simple:   attrsOf str — named colours: global, accent (set per-host)
        # lighting.encoders: attrsOf submodule — encoder ring LEDs (Full-only)
        #   Each: colour1 (hex), colour2 (hex), colour3 (hex)
      };

      # ── Effects (Full-only) ───────────────────────────────────────────
      # effects: submodule — voice effects presets.
      #   enabled:           bool
      #   activePreset:      str — name of active preset
      #   loadPreset:        str — preset to load
      #   renameActivePreset: str — rename current preset
      #   saveActivePreset:  bool
      #   reverb:   submodule — style, amount, decay, earlyLevel, tailLevel, etc.
      #   echo:     submodule — style, amount, feedback, tempo, delayLeft/Right, etc.
      #   pitch:    submodule — style, amount, character
      #   gender:   submodule — style, amount
      #   megaphone: submodule — style, amount, postGain, enabled
      #   robot:    submodule — style, ranges, waveform, pulseWidth, etc.
      #   hardTune: submodule — style, amount, rate, window, source, enabled
      # Not available on GoXLR Mini.

      # ── Sampler (Full-only) ───────────────────────────────────────────
      # sampler: attrsOf (attrsOf submodule) — sample pad banks/buttons.
      #   Structure: bank → button → {files, playbackMode, playbackOrder, etc.}
      # Not available on GoXLR Mini.

      # ── Extra commands ────────────────────────────────────────────────
      # extraCommands: listOf str — additional goxlr-client commands
      # executed after all other settings are applied. Set per-host.
    };
  };
}
