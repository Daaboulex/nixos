# mergeSettings — named-arg wrapper around lib.recursiveUpdate for
# module defaults + host overrides.
#
# Every HM module with an overrides-friendly `settings` option applies
# `cfg.settings` to its defaults via `lib.recursiveUpdate`:
#
#   programs.<tool> = lib.recursiveUpdate { <defaults> } cfg.settings;
#
# `lib.recursiveUpdate a b` has `b` win on collision. Positional args mean
# mis-ordering silently lets defaults overwrite user overrides — no type
# error, just wrong behaviour. This wrapper uses named args so callsites
# declare intent and the wrong order fails at eval with a clear message.
#
# Twenty-three callsites across home/modules/*/default.nix use the
# recursiveUpdate shape. Centralizing here also makes a future swap to a
# different merge strategy (e.g. `lib.attrsets.recursiveUpdateUntil` or a
# deep-merge-with-list-concat) a single-file change.
#
# Usage (inside a HM module — `myLib` arrives via specialArgs):
#
#   { config, lib, myLib, ... }:
#   {
#     config = lib.mkIf cfg.enable {
#       programs.<tool> = myLib.mergeSettings {
#         defaults = {
#           enable = true;
#           # ... module defaults, including `lib.optionalAttrs hasTheme {...}` merges
#         };
#         overrides = cfg.settings;
#       };
#     };
#   }
#
# Pairs with `mkSettingsOption`. A module that uses one almost always
# uses the other.
{ lib }: { defaults, overrides }: lib.recursiveUpdate defaults overrides
