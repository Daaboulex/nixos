{ lib, ... }:

{
  # ============================================================================
  # Ryzen 9950X3D Host Configuration
  # ============================================================================

  # Git credentials
  programs.git.settings.user = {
    name = "stephandaaboul";
    email = "s.daaboul@jacobs-university.de";
  };

  # Enable standard tools
  programs.btop.enable = true;
  programs.htop.enable = false;
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

  # Logitech G502 — disable acceleration (handled by yeetmouse)
  programs.plasma.configFile."kcminputrc"."Libinput][1133][16511][Logitech G502" = {
    PointerAcceleration = "0";
    PointerAccelerationProfile = 1;
  };

  # btop GPU layout (gpu0 = Zen 5 iGPU, gpu1 = RX 9070 XT)
  programs.btop.settings = {
    shown_boxes = lib.mkForce "cpu gpu0 gpu1 mem proc";
    presets = lib.mkForce "cpu:0:default,gpu1:0:default,mem:0:default,proc:0:default cpu:0:default,gpu0:0:default,gpu1:0:default,mem:0:default,net:0:default,proc:0:default";
  };

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
