# nct6775 — Nuvoton NCT67xx Super I/O sensors (motherboard Vcore, fans, temps).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "sensors";
  name = "nct6775";
  description = "Nuvoton NCT67xx Super I/O sensors (motherboard Vcore, fans, temps)";
  config = _: { boot.kernelModules = [ "nct6775" ]; };
}
