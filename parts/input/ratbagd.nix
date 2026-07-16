# ratbagd — Piper mouse configuration tool and ratbagd service for programmable mice.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "input";
  name = "ratbagd";
  description = "Piper mouse configuration tool and ratbagd service";
  config = _: { services.ratbagd.enable = true; };
}
