{ pkgs ? import <nixpkgs> {} }:

let
  flake = builtins.getFlake (toString ./..);
  # Target the specific host configuration to resolve the options
  eval = flake.nixosConfigurations."ryzen-9950x3d";
  lib = eval.pkgs.lib;
  options = eval.options.myModules;

  # Recursive function to find all options
  # Returns a list of { name, description, default, type }
  findOptions = prefix: opts:
    lib.concatLists (lib.mapAttrsToList (k: v:
      let
        path = if prefix == "" then k else "${prefix}.${k}";
      in
      if lib.isOption v then
        [{
          name = path;
          description = v.description or "No description provided.";
          default = if v ? default then v.default else "<no default>";
          type = v.type.description or "unspecified";
        }]
      else if lib.isAttrs v then
        findOptions path v
      else
        []
    ) opts);

  allOptions = findOptions "myModules" options;

  # Group by top-level module (e.g. "myModules.hardware" vs "myModules.system")
  groupByCategory = opts:
    lib.groupBy (opt:
      let parts = lib.splitString "." opt.name;
      in if builtins.length parts > 1 then builtins.elemAt parts 1 else "misc"
    ) opts;

  groupedOptions = groupByCategory allOptions;
  categories = builtins.sort (a: b: a < b) (builtins.attrNames groupedOptions);

  # Truncate long default values for readability
  formatDefault = val:
    let
      json = builtins.toJSON val;
    in
      if builtins.stringLength json > 120 then
        builtins.substring 0 117 json + "..."
      else
        json;

  formatOption = opt: ''
    #### `${opt.name}`

    **Description**: ${opt.description}
    - **Type**: `${opt.type}`
    - **Default**: `${formatDefault opt.default}`

  '';

  formatCategory = cat:
    let
      opts = groupedOptions.${cat};
      count = builtins.length opts;
    in ''
    ## ${lib.toUpper cat} (${toString count} options)

    ${lib.concatStringsSep "\n" (map formatOption opts)}
  '';

  markdownArgs = map formatCategory categories;

  # Table of contents
  toc = lib.concatStringsSep "\n" (map (cat:
    let count = builtins.length groupedOptions.${cat};
    in "- [${lib.toUpper cat}](#${lib.toLower cat}-${toString count}-options) (${toString count} options)"
  ) categories);

  totalCount = builtins.length allOptions;

  docTitle = ''
    # NixOS Custom Modules Documentation

    > Auto-generated from `myModules` option definitions. ${toString totalCount} options across ${toString (builtins.length categories)} categories.
    >
    > Regenerate: `bash scripts/update-docs.sh`

    ## Table of Contents

    ${toc}

    ---
  '';
in
  pkgs.writeText "OPTIONS.md" (docTitle + (lib.concatStringsSep "\n" markdownArgs))
