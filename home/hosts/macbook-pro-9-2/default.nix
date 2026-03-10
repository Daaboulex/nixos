{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # MacBook Pro 9,2 Host Configuration
  # ============================================================================

  # Git credentials
  programs.git.settings.user = {
    name = "Daaboulex";
    email = "39669593+Daaboulex@users.noreply.github.com";
  };

  # ============================================================================
  # Home Manager Module Toggles
  # ============================================================================
  # All HM modules auto-discover from home/modules/. These control per-host overrides.

  # Development & editors
  programs.btop.enable = true;
  programs.htop.enable = true;        # Lightweight alternative for 2C/4T hardware
  programs.vscode.enable = true;
  programs.kate.enable = true;        # KDE text editor
  programs.konsole.enable = true;     # KDE terminal
  programs.okular.enable = true;      # PDF viewer
  programs.ghostwriter.enable = false; # Markdown editor — not using
  programs.elisa.enable = false;      # KDE music player — not using (Spotify via Flatpak)

  # Audio
  services.easyeffects.enable = false; # No audio processing needed

  # ============================================================================
  # Host-Specific KDE/Plasma Settings
  # ============================================================================

  # Night light: uses module default (Berlin) — override here if laptop moves

  # Laptop power management — suspend on lid close, battery profile
  programs.plasma.powerdevil = {
    AC = {
      autoSuspend.action = "nothing";
      dimDisplay = {
        enable = true;
        idleTimeout = 300;              # Dim after 5 min on AC
      };
      turnOffDisplay.idleTimeout = 600; # Turn off after 10 min
      powerProfile = "balanced";
    };
    battery = {
      autoSuspend = {
        action = "sleep";
        idleTimeout = 600;              # Suspend after 10 min on battery
      };
      dimDisplay = {
        enable = true;
        idleTimeout = 120;              # Dim after 2 min on battery
      };
      turnOffDisplay.idleTimeout = 300; # Turn off after 5 min
      powerProfile = "powerSaving";
    };
    lowBattery = {
      autoSuspend = {
        action = "sleep";
        idleTimeout = 300;              # Suspend after 5 min on low battery
      };
      dimDisplay = {
        enable = true;
        idleTimeout = 30;               # Dim after 30 sec
      };
      turnOffDisplay.idleTimeout = 60;  # Turn off after 1 min
      powerProfile = "powerSaving";
    };
  };

  # Laptop — keep screen locker enabled (module defaults: autoLock=true, lockOnResume=true)

  # btop layout — single Intel HD4000 GPU
  programs.btop.settings = {
    shown_boxes = lib.mkForce "cpu gpu0 mem proc";
    presets = lib.mkForce "cpu:0:default,gpu0:0:default,mem:0:default,proc:0:default";
  };

  # ============================================================================
  # Flatpak Packages (host-specific)
  # ============================================================================
  services.flatpak.packages = [
    "cc.arduino.IDE2"
    "com.calibre_ebook.calibre"
    "com.github.tenderowl.frog"
    "com.github.jeromerobert.pdfarranger"
    "com.github.Darazaki.Spedread"
    "com.obsproject.Studio"
    "com.spotify.Client"
    "com.rtosta.zapzap"
    "de.bund.ausweisapp.ausweisapp2"
    "dev.geopjr.Calligraphy"
    "eu.betterbird.Betterbird"
    "io.github.shiftey.Desktop"
    "io.github.milkshiift.GoofCord"
    "io.github.flattool.Ignition"
    "io.github.giantpinkrobots.flatsweep"
    "io.github.ungoogled_software.ungoogled_chromium"
    "io.gitlab.adhami3310.Impression"  # USB image writer
    "io.gitlab.librewolf-community"
    "md.obsidian.Obsidian"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.pipewire.Helvum"              # PipeWire patchbay (useful for music production)
    "org.gnome.meld"
    "org.kde.kdenlive"
    "org.kicad.KiCad"
    "org.libreoffice.LibreOffice"
    "org.remmina.Remmina"
    "org.signal.Signal"
    "org.videolan.VLC"
  ];

  # App-specific overrides
  services.flatpak.overrides = {
    "org.signal.Signal".Environment = {
      SIGNAL_PASSWORD_STORE = "kwallet6";
    };
  };
}
