# gamescope — Gamescope micro-compositor for gaming (HDR, VRR, upscaling).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs-unstable.lib; }) {
  scope = "gaming";
  name = "gamescope";
  description = "Gamescope compositor";
  config = _: { programs.gamescope.enable = true; };
}
