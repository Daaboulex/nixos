# usbmuxd — USB multiplexing daemon for iOS device support (iPhone/iPad tethering).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "hardware";
  name = "usbmuxd";
  description = "USB multiplexing daemon (iOS device support)";
  config = _: { services.usbmuxd.enable = true; };
}
