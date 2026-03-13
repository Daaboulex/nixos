{
  # --------------------------------------------------------------------------
  # GoXLR Mini (S200907296DI7) — Full declarative mixer configuration
  # --------------------------------------------------------------------------
  # NixOS module (parts/goxlr.nix) handles: daemon, UCM profiles, PipeWire EQ
  #   chains, DeepFilterNet3 denoise, goxlr-toggle script.
  # HM module (goxlr-hm-nix) applies: mixer state via goxlr-client on login.
  # --------------------------------------------------------------------------
  #
  # ── Stored profiles (deployed as files below) ─────────────────────────
  # Device profiles: "Yellow Default", "Sleep"
  #   Format: ZIP archives containing profile.xml (binary, not Nix-expressible)
  # Mic profiles:    "DEFAULT", "Mic NeatKingBee", "MKH 20", "Sleep"
  #   Format: XML files with DSP/gate/compressor/EQ settings
  #
  # ── Lifecycle (daemon-level, set in settings.json) ────────────────────
  # Shutdown → loads "Sleep" device profile + "Sleep" mic profile
  # Sleep    → loads "Sleep" device profile + "Sleep" mic profile
  # Wake     → loads "Yellow Default" device profile + "Mic NeatKingBee" mic profile
  #
  # ── Toggle script (NixOS-level, parts/goxlr.nix) ─────────────────────
  # goxlr-toggle: switches between active/sleep profiles (Stream Deck button)
  #   Active: "Yellow Default" + "Mic NeatKingBee"
  #   Sleep:  "Sleep" + "Sleep"
  # --------------------------------------------------------------------------

  # ── Deploy all device profiles ────────────────────────────────────────
  home.file = {
    ".local/share/goxlr-utility/profiles/Yellow Default.goxlr".source =
      ./goxlr-profiles + "/Yellow Default.goxlr";
    ".local/share/goxlr-utility/profiles/Sleep.goxlr".source = ./goxlr-profiles + "/Sleep.goxlr";
    ".local/share/goxlr-utility/mic-profiles/DEFAULT.goxlrMicProfile".source =
      ./goxlr-mic-profiles + "/DEFAULT.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/Mic NeatKingBee.goxlrMicProfile".source =
      ./goxlr-mic-profiles + "/Mic NeatKingBee.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/MKH 20.goxlrMicProfile".source =
      ./goxlr-mic-profiles + "/MKH 20.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/Sleep.goxlrMicProfile".source =
      ./goxlr-mic-profiles + "/Sleep.goxlrMicProfile";
  };

  programs.goxlr = {
    enable = true;

    # Active profile loaded on login (matches wake lifecycle)
    profile = "Yellow Default";
    micProfile = "Mic NeatKingBee";

    volumes = {
      mic = 100;
      chat = 100;
      music = 59;
      game = 100;
      console = 50;
      system = 82;
      sample = 100;
      headphones = 100;
      mic-monitor = 0;
      line-out = 100;
      line-in = 100;
    };

    faders = {
      a = "game";
      b = "chat";
      c = "music";
      d = "system";
    };

    # faderMuteBehaviour: all "all" — matches module default, omitted

    routing = {
      microphone = {
        headphones = false;
        broadcast-mix = true;
        chat-mic = true;
        sampler = true;
        line-out = false;
        stream-mix2 = false;
      };
      chat = {
        headphones = true;
        broadcast-mix = false;
        chat-mic = false;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
      music = {
        headphones = true;
        broadcast-mix = true;
        chat-mic = false;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
      game = {
        headphones = true;
        broadcast-mix = false;
        chat-mic = false;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
      console = {
        headphones = true;
        broadcast-mix = false;
        chat-mic = false;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
      line-in = {
        headphones = false;
        broadcast-mix = true;
        chat-mic = false;
        sampler = false;
        line-out = false;
        stream-mix2 = false;
      };
      system = {
        headphones = true;
        broadcast-mix = false;
        chat-mic = false;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
      samples = {
        headphones = true;
        broadcast-mix = false;
        chat-mic = true;
        sampler = false;
        line-out = true;
        stream-mix2 = false;
      };
    };

    # Neat KingBee condenser microphone (Mic NeatKingBee profile)
    microphone = {
      dynamicGain = 37;
      condenserGain = 36;
      jackGain = 30;
      deEss = 0;
      gate = {
        active = true;
        threshold = -59;
        attenuation = 30;
        attack = "gate10ms";
        release = "gate200ms";
      };
      compressor = {
        threshold = -18;
        ratio = "ratio3-2";
        attack = "comp3ms";
        release = "comp230ms";
        makeUp = 3;
      };
    };

    submix = {
      enabled = true;
      volumes = {
        mic = 100;
        chat = 100;
        music = 100;
        game = 100;
        console = 50;
        system = 82;
        sample = 100;
        line-in = 100;
      };
      linked = {
        mic = true;
        chat = true;
        music = false;
        game = true;
        console = true;
        system = true;
        sample = true;
        line-in = true;
      };
      outputMix = {
        headphones = "a";
        broadcast-mix = "b";
        chat-mic = "a";
        sampler = "a";
        line-out = "a";
        stream-mix2 = "a";
      };
      monitorMix = "headphones";
    };

    coughButton = {
      isHold = false;
      muteBehaviour = "all";
    };

    bleepVolume = -7;

    settings = {
      muteHoldDuration = 500;
      monitorWithFx = false;
      deafenOnChatMute = true;
      lockFaders = false;
    };

    # Yellow theme lighting
    lighting = {
      animation = {
        mode = "none";
        mod1 = 0;
        mod2 = 0;
        waterfall = "down";
      };
      faders = {
        a = {
          display = "two-colour";
          top = "000000";
          bottom = "FFF80C";
        };
        b = {
          display = "two-colour";
          top = "000000";
          bottom = "FFF80C";
        };
        c = {
          display = "two-colour";
          top = "000000";
          bottom = "FFF80C";
        };
        d = {
          display = "two-colour";
          top = "000000";
          bottom = "FFF80C";
        };
      };
      buttons = {
        fader1-mute = {
          colour = "FFF80C";
          colour2 = "FF00C8";
          offStyle = "dimmed";
        };
        fader2-mute = {
          colour = "FFF80C";
          colour2 = "FF00C8";
          offStyle = "dimmed";
        };
        fader3-mute = {
          colour = "FFF80C";
          colour2 = "FF00C8";
          offStyle = "dimmed";
        };
        fader4-mute = {
          colour = "FFF80C";
          colour2 = "FF00C8";
          offStyle = "dimmed";
        };
        cough = {
          colour = "FFF80C";
          colour2 = "00FFFF";
          offStyle = "dimmed";
        };
        bleep = {
          colour = "FFF80C";
          colour2 = "00FFFF";
          offStyle = "dimmed";
        };
      };
      # encoders: Mini doesn't have encoder knobs (Full-only)
      simple = {
        global = "003FFA";
        accent = "FFF80C";
      };
    };
  };
}
