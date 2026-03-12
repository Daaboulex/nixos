#
# Generates a NixOS host config template showing all myModules options
# with their types and defaults, structured by category.
#
# Usage: nix-build scripts/generate-host-template.nix --no-out-link
#
{
  pkgs ? import <nixpkgs> { },
}:

let
  flake = builtins.getFlake (toString ./..);
  eval = flake.nixosConfigurations."ryzen-9950x3d";
  inherit (eval.pkgs) lib;
  options = eval.options.myModules;

  # Recursive option finder — returns flat list of { path, type, default, description }
  findOptions =
    prefix: opts:
    lib.concatLists (
      lib.mapAttrsToList (
        k: v:
        let
          path = if prefix == "" then k else "${prefix}.${k}";
        in
        if lib.isOption v then
          [
            {
              inherit path;
              description = v.description or "";
              default = v.default or null;
              typeName = v.type.description or "unknown";
              isEnable = k == "enable";
            }
          ]
        else if lib.isAttrs v then
          findOptions path v
        else
          [ ]
      ) opts
    );

  allOptions = findOptions "" options;

  # Group by top-level namespace
  groupByNamespace =
    opts:
    builtins.groupBy (
      opt:
      let
        parts = lib.splitString "." opt.path;
      in
      builtins.elemAt parts 0
    ) opts;

  grouped = groupByNamespace allOptions;
  namespaces = builtins.sort (a: b: a < b) (builtins.attrNames grouped);

  # Format a default value for display in Nix code
  formatDefault =
    val:
    if val == null then
      "null"
    else if builtins.isBool val then
      if val then "true" else "false"
    else if builtins.isInt val then
      toString val
    else if builtins.isFloat val then
      toString val
    else if builtins.isString val then
      ''"${val}"''
    else if builtins.isList val then
      let
        json = builtins.toJSON val;
      in
      if builtins.stringLength json > 80 then "[ ... ]" else json
    else
      "<complex>";

  # Format a single option as a Nix comment + assignment
  formatOption =
    opt:
    let
      indent = "    ";
      # Build the path segments after the namespace
      segments = lib.splitString "." opt.path;
      name = lib.last segments;
      defaultStr = formatDefault opt.default;
      typeStr = opt.typeName;
      descStr = if opt.description != "" then " — ${opt.description}" else "";
    in
    "${indent}# ${name}: ${typeStr}${descStr}\n${indent}# ${name} = ${defaultStr};";

  # Group options by their sub-path (e.g., system.boot, system.packages)
  formatNamespace =
    ns:
    let
      opts = grouped.${ns};
      count = builtins.length opts;
      lines = map formatOption opts;
    in
    ''
      # --------------------------------------------------------------------------
      # ${ns} (${toString count} options)
      # --------------------------------------------------------------------------
      ${lib.concatStringsSep "\n" lines}
    '';

  header = ''
    # ==========================================================================
    # NixOS Host Configuration Template
    # ==========================================================================
    # Auto-generated from myModules option definitions.
    # ${toString (builtins.length allOptions)} options across ${toString (builtins.length namespaces)} namespaces.
    #
    # Usage: copy this file to parts/hosts/<hostname>/default.nix and uncomment
    # the options you want to set. Options left commented use their module defaults.
    #
    # Regenerate: nix-build scripts/generate-host-template.nix --no-out-link
    # ==========================================================================
    {
      config,
      pkgs,
      inputs,
      lib,
      ...
    }:
    {
      imports = [
        ./hardware-configuration.nix
      ];

      myModules = {
  '';

  footer = ''
      };

      # System basics (edit these for your host)
      system.stateVersion = "26.05";
      networking.hostName = "<hostname>";
      time.timeZone = "Europe/Berlin";
    }
  '';

  body = lib.concatStringsSep "\n" (map formatNamespace namespaces);

in
pkgs.writeText "host-template.nix" (header + body + footer)
