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
#
# HAZARD, enforced below: a default that wraps a WHOLE attrset in
# mkDefault/mkForce is silently broken here — recursiveUpdate recurses into
# the wrapper ({ _type; priority; content }) and merges override keys NEXT TO
# `content`; the module system then reads only `content` and drops the
# override. Wrap leaves instead. This asserts at eval so the mistake cannot
# ship (derivation-valued content is exempt: nothing recurses usefully into
# a derivation either way).
{ lib }:
{ defaults, overrides }:
let
  # Follow wrapper chains (mkIf(mkDefault(x)) etc.) to the terminal value:
  # only a terminal PLAIN attrset is hazardous — terminal leaves (strings,
  # lists, derivations) are replaced wholesale by recursiveUpdate and merge
  # correctly.
  unwrap = v: if lib.isAttrs v && v ? _type && v ? content then unwrap v.content else v;
  checkNode =
    path: v:
    if lib.isAttrs v && !lib.isDerivation v then
      if v ? _type then
        let
          t = unwrap v;
        in
        if lib.isAttrs t && !lib.isDerivation t then
          throw "mergeSettings: defaults.${lib.concatStringsSep "." path} wraps a whole attrset in a ${v._type} wrapper — wrap the leaves instead, or host overrides under this path are silently dropped"
        else
          true
      else
        builtins.all (n: checkNode (path ++ [ n ]) v.${n}) (builtins.attrNames v)
    else
      true;
in
assert checkNode [ ] defaults;
lib.recursiveUpdate defaults overrides
