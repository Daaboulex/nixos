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
# direction and the shape this repo standardizes on. This module
# declares it locally so our module exports can use either path without
# having to wait on upstream flake-parts.
#
# flake-parts now ships this as flakeModules.modules; kept local because its
# _file/_class provenance and open-class semantics differ. Revisit when those
# converge (then this file can be dropped for the upstream import).
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
              _class = "homeManager";
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
      Declared locally; flake-parts ships flakeModules.modules but its
      provenance/class semantics differ (see header).
    '';
  };
}
