{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Ryzen 9950X3D Host Configuration
  # ============================================================================

  # Enable standard tools
  programs.btop.enable = true;
  programs.htop.enable = false;
  programs.vscode.enable = true;

  # Audio
  services.easyeffects.enable = false;

  # ============================================================================
  # Flatpak Packages (host-specific)
  # ============================================================================
  services.flatpak.packages = [
    "com.calibre_ebook.calibre"
    "com.github.tenderowl.frog"
    "com.github.jeromerobert.pdfarranger"
    "com.github.Darazaki.Spedread"
    "com.logseq.Logseq"
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
    "io.gitlab.librewolf-community"
    "md.obsidian.Obsidian"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
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
