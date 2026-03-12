#
# Generates a NixOS host config template showing all myModules options
# with their types and defaults, structured by namespace and sub-group.
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
            }
          ]
        else if lib.isAttrs v then
          findOptions path v
        else
          [ ]
      ) opts
    );

  allOptions = findOptions "" options;

  # Format a default value — skip multiline strings, keep it concise
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
      if builtins.stringLength val > 60 || lib.hasInfix "\n" val then "\"...\"" else ''"${val}"''
    else if builtins.isList val then
      if val == [ ] then "[ ]" else "[ ... ]"
    else
      "<complex>";

  # Check if a default is too complex to show inline
  isSimpleDefault =
    val:
    if val == null then
      true
    else if builtins.isBool val then
      true
    else if builtins.isInt val then
      true
    else if builtins.isFloat val then
      true
    else if builtins.isString val then
      builtins.stringLength val <= 60 && !(lib.hasInfix "\n" val)
    else if builtins.isList val then
      val == [ ]
    else
      false;

  # Group by 2-level namespace (e.g., "system.boot", "hardware.cpu")
  getSubNamespace =
    path:
    let
      parts = lib.splitString "." path;
      len = builtins.length parts;
    in
    if len >= 2 then
      "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}"
    else
      builtins.elemAt parts 0;

  groupedBySubNs = builtins.groupBy (opt: getSubNamespace opt.path) allOptions;
  subNamespaces = builtins.sort (a: b: a < b) (builtins.attrNames groupedBySubNs);

  # Format a single option line
  formatOption =
    opt:
    let
      parts = lib.splitString "." opt.path;
      # Show the leaf name (last segment) for context
      # Show path relative to the sub-namespace (drop first 2 segments)
      relParts = lib.drop 2 parts;
      relPath = lib.concatStringsSep "." relParts;
      displayPath = if relPath == "" then opt.path else relPath;
      defaultStr = formatDefault opt.default;
      simple = isSimpleDefault opt.default;
      typeStr = opt.typeName;
      descShort =
        if builtins.stringLength opt.description > 80 then
          builtins.substring 0 77 opt.description + "..."
        else
          opt.description;
    in
    if simple then
      "    # ${displayPath} = ${defaultStr};  # ${typeStr} — ${descShort}"
    else
      "    # ${displayPath} = ...;  # ${typeStr} — ${descShort}";

  # Format a sub-namespace section
  formatSubNamespace =
    ns:
    let
      opts = groupedBySubNs.${ns};
      count = builtins.length opts;
      # Only show enable options and simple scalar options (skip complex nested ones like EQ)
      simpleOpts = builtins.filter (opt: isSimpleDefault opt.default) opts;
      complexCount = count - builtins.length simpleOpts;
      lines = map formatOption simpleOpts;
      complexNote =
        if complexCount > 0 then
          "\n    # ... and ${toString complexCount} more options with complex defaults (see docs/OPTIONS.md)"
        else
          "";
    in
    ''
      # --- ${ns} (${toString count} options) ---
      ${lib.concatStringsSep "\n" lines}${complexNote}
    '';

  header = ''
    # ==========================================================================
    # NixOS Host Configuration Template
    # ==========================================================================
    # Auto-generated from myModules option definitions.
    # ${toString (builtins.length allOptions)} options across ${toString (builtins.length subNamespaces)} groups.
    #
    # Usage: copy this file to parts/hosts/<hostname>/default.nix and uncomment
    # the options you want to set. Options left commented use their module defaults.
    #
    # For full option details with complex defaults, see docs/OPTIONS.md
    # Regenerate: bash scripts/update-docs.sh
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

  body = lib.concatStringsSep "\n" (map formatSubNamespace subNamespaces);

in
pkgs.writeText "host-template.nix" (header + body + footer)
