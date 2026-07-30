# gtk — GTK theme configuration (Breeze Dark) with theme-module derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.gtk;
  inherit (myLib.themeCtx { inherit config; }) hasTheme;
in
{
  options.myModules.home.gtk = {
    enable = lib.mkEnableOption "GTK theme configuration (Breeze Dark)";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # GTK Configuration — derived from myModules.home.theme when enabled
    # Currently only breeze-dark palette exists; when more palettes are added,
    # the GTK theme name can be derived from cfg.palette.
    gtk = myLib.mergeSettings {
      defaults = {
        enable = true;
        # Leaf-level mkDefault (whole-attrset wrappers are broken under
        # mergeSettings — see lib/mergeSettings.nix).
        theme = {
          # Derived from theme palette — currently only breeze-dark exists
          name = lib.mkDefault "Breeze-Dark";
          package = lib.mkDefault pkgs.kdePackages.breeze-gtk;
        };
        iconTheme = {
          name = lib.mkDefault "breeze-dark";
          package = lib.mkDefault pkgs.kdePackages.breeze-icons;
        };
        cursorTheme = {
          name = lib.mkDefault "breeze_cursors";
          package = lib.mkDefault pkgs.kdePackages.breeze;
        };
        gtk2.force = true; # Force overwrite, prevent backup collisions
        gtk3.extraConfig = lib.optionalAttrs hasTheme {
          gtk-application-prefer-dark-theme = true;
        };
        gtk4.extraConfig = lib.optionalAttrs hasTheme {
          gtk-application-prefer-dark-theme = true;
        };
      };
      overrides = cfg.settings;
    };
  };
}
