#
# Generates a Home Manager host config template from actual myModules.home options.
#
# Usage: nix-build scripts/generate-hm-template.nix --no-out-link
#
{
  pkgs ? import <nixpkgs> { },
}:

let
  flake = builtins.getFlake (toString ./..);
  eval = flake.nixosConfigurations.${builtins.head (builtins.attrNames flake.nixosConfigurations)};
  inherit (eval.pkgs) lib;

  inherit (eval.config.myModules) primaryUser;
  hmConfig = eval.config.home-manager.users.${primaryUser}.myModules.home;
  moduleNames = builtins.sort (a: b: a < b) (builtins.attrNames hmConfig);

  # Generate a toggle line for each module
  formatToggle =
    name:
    let
      mod = hmConfig.${name};
      attrs = if builtins.isAttrs mod then builtins.attrNames mod else [ ];
      subOpts = builtins.filter (a: a != "enable" && a != "settings") attrs;
      subLines = lib.concatMapStringsSep "\n" (
        sub:
        let
          val = mod.${sub};
        in
        if builtins.isAttrs val && val ? enable then
          "  # myModules.home.${name}.${sub}.enable = false;"
        else if builtins.isBool val then
          "  # myModules.home.${name}.${sub} = ${if val then "true" else "false"};"
        else
          "  # myModules.home.${name}.${sub} = ...;"
      ) subOpts;
    in
    "  myModules.home.${name}.enable = true;" + (if subLines != "" then "\n${subLines}" else "");

  toggleBlock = lib.concatStringsSep "\n" (map formatToggle moduleNames);

  template = ''
    # ==========================================================================
    # Home Manager Host Configuration Template
    # ==========================================================================
    # Auto-generated from myModules.home option definitions.
    # ${toString (builtins.length moduleNames)} modules available.
    #
    # Copy to home/hosts/<hostname>/default.nix and customise.
    # Set enable = false for modules you don't need on this host.
    #
    # Regenerate: bash scripts/update-docs.sh
    # ==========================================================================
    {
      config,
      lib,
      ...
    }:
    {
      # ========================================================================
      # Git credentials (required per-host)
      # ========================================================================
      programs.git.settings.user = {
        name = "<username>";
        email = "<email>";
      };

      # ========================================================================
      # Module Enable Toggles (exhaustive, alphabetical)
      # ========================================================================
      # Sub-options shown commented below their parent. Uncomment to override.
    ${toggleBlock}

      # ========================================================================
      # Per-Host Overrides (add below toggle block)
      # ========================================================================
      # Host-specific settings go here, grouped by concern.
      # Example:
      #   myModules.home.tidalcycles.autostartSuperDirt = true;
      #   myModules.home.btop.settings = { ... };
    }
  '';

in
# Plain string attr — consumed via `nix eval --raw … .text`. No derivation
# build required (previous `pkgs.writeText` forced bash+coreutils realisation).
{
  text = template;
}
