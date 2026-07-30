# mkSpecialisations — auto-wire every `<name>.nix` in a host's `specialisations/`
# directory as `specialisation.<name>.configuration`. The folder IS the manifest:
# dropping a file adds a specialisation with no host-file edit and no separate names
# list to drift. `default.nix` and `_`-prefixed files (shared fragments imported by
# the specs) are skipped. Each spec file is an ordinary NixOS module
# (`{ config, lib, pkgs, ... }: { … }`). `readDir` is a pure source read (no IFD).
{ lib }:
{ dir }:
let
  isSpec =
    name: type:
    type == "regular"
    && lib.hasSuffix ".nix" name
    && name != "default.nix"
    && !(lib.hasPrefix "_" name);
  specFiles = lib.filterAttrs isSpec (builtins.readDir dir);
in
lib.mapAttrs' (
  file: _:
  lib.nameValuePair (lib.removeSuffix ".nix" file) {
    configuration.imports = [ (dir + "/${file}") ];
  }
) specFiles
