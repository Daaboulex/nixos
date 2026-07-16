# flatpak — Flatpak application sandbox runtime support.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "desktop";
  name = "flatpak";
  description = "Flatpak support";
  config = _: { services.flatpak.enable = true; };
}
