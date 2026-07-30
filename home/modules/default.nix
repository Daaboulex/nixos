# home-modules — auto-importer that walks home/modules/ and imports every subdir containing a default.nix.
#
# Walks home/modules/ and imports every subdir containing a default.nix.
# Subdirs whose basename starts with `_` are skipped (reserved for
# per-module private helpers, if we ever need them).
#
# Flat readDir of direct subdirs (not import-tree's recursive walk): a
# recursive walk double-imports umbrella sub-modules (macbook, neovim,
# plasma) that their umbrella default.nix already imports, causing
# option-merge conflicts / stack-overflow.
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
