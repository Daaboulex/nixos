# upower — UPower battery and power monitoring daemon.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "hardware";
  name = "upower";
  description = "UPower (battery/power monitoring)";
  config = _: { services.upower.enable = true; };
}
