# Flatpak Module - System service only
#
# This NixOS module just enables the Flatpak daemon.
# All configuration (packages, remotes, overrides) is managed via Home Manager.
#
{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.desktop.flatpak;
in {
  options.myModules.desktop.flatpak = {
    enable = lib.mkEnableOption "Flatpak support (service only, config via Home Manager)";
  };

  config = lib.mkIf cfg.enable {
    # Enable Flatpak service (required for Home Manager to manage packages)
    services.flatpak.enable = true;
  };
}