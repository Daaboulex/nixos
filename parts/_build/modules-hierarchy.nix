# modules-hierarchy — declare `flake.modules.<class>.<name>` as a local
# flake-parts option tree.
#
# Contract:
#   Options:  flake.modules.{nixos,homeManager}
#   Sets:     nothing — pure option declaration
#   Depends:  flake-parts (types.deferredModule)
#
# Rationale: flake-parts currently ships `flake.nixosModules.<name>` and
# `flake.homeManagerModules.<name>` as flat attrsets. The class-hierarchical
# form `flake.modules.<class>.<name>` is the pre-RFC "Modularized flakes"
# direction and is the preferred shape in docs/STYLE.md §6.1. This module
# declares it locally so our module exports can use either path without
# having to wait on upstream flake-parts.
#
# When flake-parts upstream adopts the hierarchical form (with potentially
# different merge semantics), delete this file and migrate.
{ lib, ... }:
{
  options.flake.modules = lib.mkOption {
    default = { };
    type = lib.types.submodule {
      options = {
        nixos = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.deferredModule;
          default = { };
          apply = lib.mapAttrs (
            k: v: {
              _class = "nixos";
              _file = "flake.modules.nixos.${k}";
              imports = [ v ];
            }
          );
          description = ''
            NixOS modules, hierarchical form. Consumed as
            `inputs.self.modules.nixos.<name>` from host flake-modules.
            Equivalent in content to `flake.nixosModules.<name>`.
          '';
        };
        homeManager = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.deferredModule;
          default = { };
          apply = lib.mapAttrs (
            k: v: {
              _file = "flake.modules.homeManager.${k}";
              imports = [ v ];
            }
          );
          description = ''
            Home-Manager modules, hierarchical form. Consumed as
            `inputs.self.modules.homeManager.<name>`.
          '';
        };
      };
    };
    description = ''
      Hierarchical module exports: `flake.modules.<class>.<name>`.
      Declared locally (flake-parts does not yet ship this).
    '';
  };
}
