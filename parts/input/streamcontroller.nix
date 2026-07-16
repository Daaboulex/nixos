# streamcontroller — StreamController (Elgato Stream Deck) support with udev rules.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "input";
  name = "streamcontroller";
  description = "StreamController (Elgato Stream Deck)";
  config =
    { pkgs, ... }:
    {
      # Elgato Stream Deck USB device access (vendor 0x0fd9)
      services.udev.packages = [ pkgs.streamcontroller ];
    };
}
