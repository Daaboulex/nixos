{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # MacBook Pro 9,2 Host Configuration
  # ============================================================================

  # Git credentials
  programs.git.settings.user = {
    name = "stephandaaboul";
    email = "s.daaboul@jacobs-university.de";
  };

  # Enable standard tools
  programs.btop.enable = true;
  programs.htop.enable = true;     # Lightweight alternative for old hardware
  programs.vscode.enable = true;

  # Audio
  services.easyeffects.enable = false;

  # ============================================================================
  # Host-Specific Hardware Settings
  # ============================================================================

  # Night light location (Berlin)
  programs.plasma.kwin.nightLight.location = {
    latitude = "52.52";
    longitude = "13.405";
  };

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
    "io.gitlab.adhami3310.Impression"
    "io.gitlab.librewolf-community"
    "md.obsidian.Obsidian"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.pipewire.Helvum"
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
