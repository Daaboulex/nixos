# flatpak — Flatpak application sandbox runtime support.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.desktop.flatpak;
    in
    {
      _class = "nixos";
      options.myModules.desktop.flatpak.enable = lib.mkEnableOption "Flatpak support";

      config = lib.mkIf cfg.enable {
        services.flatpak.enable = true;
      };
    };
in
{
  flake.modules.nixos.desktop-flatpak = mod;

}
