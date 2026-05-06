# flake-module — composition root, auto-imports every parts/**/*.nix module.
{ lib, ... }:
{
  # Auto-imports every parts/**/*.nix that declares a
  # flake.modules.nixos.<name> module, excluding:
  #   • parts/_build/**        build infrastructure (imported below)
  #   • parts/hosts/**         host wiring (imported below)
  #   • parts/**/drivers/**    kernel-module package derivations, not
  #                            flake-parts modules (called by callPackage)
  #   • parts/**/flake-module.nix    flake-parts plumbing (never modules)
  #   • parts/**/_*.nix        private helpers (convention)
  imports =
    let
      allFiles = lib.filesystem.listFilesRecursive ./.;
      isModule =
        p:
        let
          s = toString p;
        in
        lib.hasSuffix ".nix" s
        && !(lib.hasInfix "/_build/" s)
        && !(lib.hasInfix "/hosts/" s)
        && !(lib.hasInfix "/drivers/" s)
        && !(lib.hasSuffix "/flake-module.nix" s)
        && !(lib.hasInfix "/_" s);
      autoModules = lib.filter isModule allFiles;
    in
    autoModules
    ++ [
      # ── Build Infrastructure ────────────────────────────────────────
      ./_build/overlays.nix
      ./_build/treefmt.nix
      ./_build/git-hooks.nix
      ./_build/tests.nix
      ./_build/tests/smoke.nix
      ./_build/tests/nrb.nix
      ./_build/lib.nix
      ./_build/modules-hierarchy.nix

      # ── Hosts ───────────────────────────────────────────────────────
    ]
    ++ (
      # Auto-discover each parts/hosts/<name>/flake-module.nix so adding
      # a new host = `mkdir parts/hosts/foo && echo '...' > flake-module.nix`
      # (no edit here required). Skips directories without a flake-module.
      let
        hostDir = ./hosts;
        entries = builtins.readDir hostDir;
        hostNames = lib.attrNames (lib.filterAttrs (_: t: t == "directory") entries);
        hostFlake = name: hostDir + "/${name}/flake-module.nix";
      in
      lib.filter builtins.pathExists (map hostFlake hostNames)
    );

  perSystem =
    {
      config,
      self',
      inputs',
      pkgs,
      system,
      ...
    }:
    {
      # Per-system configuration if needed (e.g. devShells, packages)
    };
}
