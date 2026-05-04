# mkSettingsOption — factory for the host-override `settings` mkOption.
#
# Every HM module that wants to let host configs merge overrides into its
# programs.<tool> block exposes an identical 5-line option:
#
#   settings = lib.mkOption {
#     type = lib.types.attrsOf lib.types.anything;
#     default = { };
#     description = "Overrides merged over module defaults.";
#   };
#
# Thirty+ callsites across home/modules/*/default.nix use this exact shape.
# This helper collapses each to one line and centralizes the type/default/
# description invariant so a future schema tightening is a one-file change.
#
# Usage (inside a HM module — `myLib` arrives via specialArgs):
#
#   { config, lib, myLib, ... }:
#   {
#     options.myModules.home.<tool> = {
#       enable = lib.mkEnableOption "...";
#       settings = myLib.mkSettingsOption { };
#     };
#   }
#
# Custom description (rare):
#
#   settings = myLib.mkSettingsOption {
#     description = "Theme colour overrides merged over palette.";
#   };
#
# Do NOT use on modules that declare a typed submodule (e.g. goxlr.eq.gain)
# — those need `types.submodule`, not `attrsOf anything`. This helper is
# deliberately limited to the free-form overrides case.
{ lib }:
{
  description ? "Overrides merged over module defaults.",
}:
lib.mkOption {
  type = lib.types.attrsOf lib.types.anything;
  default = { };
  inherit description;
}
