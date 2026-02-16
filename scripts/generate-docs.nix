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

  # Format as Markdown with Grouping
  # Group by top-level module (e.g. "myModules.hardware" vs "myModules.system")
  
  groupByCategory = opts:
    lib.groupBy (opt: 
      let parts = lib.splitString "." opt.name; 
      in if builtins.length parts > 1 then builtins.elemAt parts 1 else "misc"
    ) opts;

  groupedOptions = groupByCategory allOptions;
  categories = builtins.sort (a: b: a < b) (builtins.attrNames groupedOptions);

  formatOption = opt: ''
    #### `${opt.name}`
    
    **Description**: ${opt.description}
    - **Type**: `${opt.type}`
    - **Default**: `${builtins.toJSON opt.default}`
    
  '';

  formatCategory = cat: ''
    ## ${lib.toUpper cat}
    
    ${lib.concatStringsSep "\n" (map formatOption (groupedOptions.${cat}))}
  '';

  markdownArgs = map formatCategory categories;
  
  docTitle = ''
    # NixOS Custom Modules Documentation
    
    This file documents all custom configuration options available under `myModules`.
    
    ---
  '';
in
  pkgs.writeText "OPTIONS.md" (docTitle + (lib.concatStringsSep "\n" markdownArgs))
