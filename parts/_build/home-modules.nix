# home-modules — auto-discover and export Home Manager modules as flake outputs.
#
# Walks home/modules/ (flat, not recursive) and registers each subdir
# containing a default.nix as flake.modules.homeManager.<name>, plus a
# `default` aggregate importing the whole tree.
#
# Flat readDir, not recursive: a recursive walk (e.g. import-tree)
# double-imports umbrella sub-modules (macbook, neovim, plasma), which must
# export as a single entry — their sub-modules are internal.
#
# Also exposes flake.homeModules as an alias for external consumers
# who expect the standard output key (catppuccin/nix convention).
{
  lib,
  config,
  ...
}:
let
  hmDir = ../../home/modules;
  files = builtins.readDir hmDir;
  isPublicModule =
    name: type:
    type == "directory"
    && !(lib.hasPrefix "_" name)
    && builtins.pathExists (hmDir + "/${name}/default.nix");
  validModules = lib.filterAttrs isPublicModule files;
  moduleSet = lib.mapAttrs (name: _: hmDir + "/${name}") validModules;
in
{
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Alias for flake.modules.homeManager (external consumer convention).";
  };

  config = {
    flake.modules.homeManager = moduleSet // {
      # Whole-tree aggregate for consumers that want every module. Args the
      # modules need (inputs, myLib) must come via (extra)specialArgs — they
      # are used in imports, so _module.args would recurse infinitely. An
      # out-of-tree consumer passes THIS flake's own set:
      #   extraSpecialArgs = {
      #     inputs = <personal>.inputs // { self = <personal>; };
      #     myLib = <personal>.lib;
      #   };
      default.imports = lib.attrValues moduleSet;
    };
    flake.homeModules = config.flake.modules.homeManager;
  };
}
