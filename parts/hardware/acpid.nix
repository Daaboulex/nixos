# acpid — ACPI event daemon for power button, lid, and hotkey handling.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "hardware";
  name = "acpid";
  description = "ACPI event daemon";
  config = _: { services.acpid.enable = true; };
}
