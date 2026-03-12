{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # GTK Configuration - Breeze Dark theme (override per-host for different themes)
  # ============================================================================
  gtk = {
    enable = true;
    theme = lib.mkDefault {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = lib.mkDefault {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
    cursorTheme = lib.mkDefault {
      name = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
    };
    gtk2.force = true; # Force overwrite, prevent backup collisions
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
}
