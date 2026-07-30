{ config, ... }:

{
  # Deploy all device profiles (local file assets — not module settings territory)
  home.file = {
    ".local/share/goxlr-utility/profiles/Yellow Default.goxlr".source =
      ./profiles + "/Yellow Default.goxlr";
    ".local/share/goxlr-utility/profiles/Sleep.goxlr".source = ./profiles + "/Sleep.goxlr";
    ".local/share/goxlr-utility/mic-profiles/DEFAULT.goxlrMicProfile".source =
      ./mic-profiles + "/DEFAULT.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/Mic NeatKingBee.goxlrMicProfile".source =
      ./mic-profiles + "/Mic NeatKingBee.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/MKH 20.goxlrMicProfile".source =
      ./mic-profiles + "/MKH 20.goxlrMicProfile";
    ".local/share/goxlr-utility/mic-profiles/Sleep.goxlrMicProfile".source =
      ./mic-profiles + "/Sleep.goxlrMicProfile";
  };

  # Host-specific GoXLR settings — merged over module defaults via settings passthrough
  myModules.home.goxlr.settings = {

    # Boot and wake always start in sleep mode — toggle to active when needed.
    # This prevents the wake service from reverting a manually-set sleep state.
    profile = "Sleep";
    micProfile = "Sleep";

    volumes = {
      mic = 100;
      chat = 100;
      music = 59;
      game = 100;
      console = 100; # Optical in from SupremeFX (VM audio via GoXLR)
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
        console = 100; # Optical in from SupremeFX (VM audio)
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

    bleepVolume = 50;

    # Power actions — daemon handles these natively via settings.json patch.
    # On shutdown/sleep: load Sleep profile (lights off, mic muted).
    # On wake: reload settings + load Sleep profile (user toggles to active manually).
    powerActions = {
      shutdown = {
        profile = "Sleep";
        micProfile = "Sleep";
        loadColours = "Sleep";
      };
      sleep = {
        profile = "Sleep";
        micProfile = "Sleep";
        loadColours = "Sleep";
      };
      wake = {
        reloadSettings = true;
        profile = "Sleep";
        micProfile = "Sleep";
        loadColours = "Sleep";
      };
    };

    # Lighting is managed by the profile files (Sleep.goxlr / Yellow Default.goxlr),
    # NOT declared here. Declaring lighting in HM config would override the Sleep
    # profile's dark lighting on boot, causing lights to turn on before the user
    # toggles to active mode. The profile files contain the correct lighting for
    # each state — Sleep (lights off) and Yellow Default (yellow faders/buttons).
    # To update lighting: edit the profile on-device, then re-export with export-config.sh.
    #
    # Active-state lighting (reference — uncomment to override profiles):
    # lighting = {
    #   animation = { mode = "none"; mod1 = 0; mod2 = 0; waterfall = "down"; };
    #   faders = {
    #     a = { display = "two-colour"; top = "000000"; bottom = "FFF80C"; };
    #     b = { display = "two-colour"; top = "000000"; bottom = "FFF80C"; };
    #     c = { display = "two-colour"; top = "000000"; bottom = "FFF80C"; };
    #     d = { display = "two-colour"; top = "000000"; bottom = "FFF80C"; };
    #   };
    #   buttons = {
    #     fader1-mute = { colour = "FFF80C"; colour2 = "FF00C8"; offStyle = "dimmed"; };
    #     fader2-mute = { colour = "FFF80C"; colour2 = "FF00C8"; offStyle = "dimmed"; };
    #     fader3-mute = { colour = "FFF80C"; colour2 = "FF00C8"; offStyle = "dimmed"; };
    #     fader4-mute = { colour = "FFF80C"; colour2 = "FF00C8"; offStyle = "dimmed"; };
    #     cough = { colour = "FFF80C"; colour2 = "00FFFF"; offStyle = "dimmed"; };
    #     bleep = { colour = "FFF80C"; colour2 = "00FFFF"; offStyle = "dimmed"; };
    #   };
    #   simple = { global = "003FFA"; accent = "FFF80C"; };
    # };
  };
}
