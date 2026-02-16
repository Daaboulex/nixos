{ inputs, ... }: {
  flake.nixosModules.desktop-flatpak = { config, lib, pkgs, ... }: {
    options.myModules.desktop.flatpak.enable = lib.mkEnableOption "Flatpak support";
    config = lib.mkIf config.myModules.desktop.flatpak.enable {
      services.flatpak.enable = true;
    };
  };
}
