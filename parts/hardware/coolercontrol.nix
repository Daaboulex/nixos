# coolercontrol — CoolerControl fan and cooling device management daemon.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "hardware";
  name = "coolercontrol";
  description = "CoolerControl fan and cooling device management";
  config = _: { programs.coolercontrol.enable = true; };
}
