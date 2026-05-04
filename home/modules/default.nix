# home-modules — auto-importer that walks home/modules/ and imports every subdir containing a default.nix.
#
# Walks home/modules/ and imports every subdir containing a default.nix.
# Subdirs whose basename starts with `_` are skipped (reserved for
# per-module private helpers, if we ever need them).
#
# import-tree was evaluated and rejected (2026-04-15): its recursive walk
# double-imports umbrella sub-modules (macbook, neovim, plasma, …) that
# their umbrella default.nix already imports explicitly, triggering
# option-merge conflicts / stack-overflow. Flat readDir of direct subdirs
# is the correct behavior for this layout.
{ lib, ... }:
{
  imports =
    let
      files = builtins.readDir ./.;
      isPublicModule =
        name: type:
        type == "directory"
        && !(lib.hasPrefix "_" name)
        && builtins.pathExists (./. + "/${name}/default.nix");
      validModules = lib.filterAttrs isPublicModule files;
    in
    lib.mapAttrsToList (name: _: ./. + "/${name}") validModules;
}
