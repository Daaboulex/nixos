# checks — one import point for every check binary. readDir-driven: dropping
# a check-<name>.nix in this directory makes it available to both consumers
# (the git-hooks standard-hook list and the tests) without a second import
# site. Companion .py scripts and this file are excluded.
{ pkgs }:
let
  entries = builtins.readDir ./.;
  isCheck =
    name: type: type == "regular" && name != "default.nix" && builtins.match ".*\\.nix" name != null;
in
builtins.listToAttrs (
  map (name: {
    name = builtins.replaceStrings [ ".nix" ] [ "" ] name;
    value = import (./. + "/${name}") { inherit pkgs; };
  }) (builtins.attrNames (pkgs.lib.filterAttrs isCheck entries))
)
