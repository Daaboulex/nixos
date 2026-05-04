# generate-readme-sections.nix — produce markdown for README's
# auto-generated sections (module-reference, directory-layout, flake-inputs).
#
# Pure-nix walker: zero derivation builds. Walks the tree via
# `builtins.readDir`, reads first-line docstrings via `builtins.readFile`,
# and returns markdown strings. The `update-docs` hook calls this with
# `nix eval --raw` and splices the output between BEGIN/END markers in
# README.md.
#
# Usage:
#   nix eval --raw --impure --file scripts/generate-readme-sections.nix moduleReference
#   nix eval --raw --impure --file scripts/generate-readme-sections.nix directoryLayout
#   nix eval --raw --impure --file scripts/generate-readme-sections.nix flakeInputs
#
# The `--impure` is required because `builtins.getFlake` on a relative path
# reads the working directory, not the pure eval sandbox. Same pattern as
# scripts/generate-docs.nix and scripts/generate-host-template.nix.

let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  # ---------- helpers ----------

  # Extract first-line docstring (`# name — purpose.`) from a file. Returns
  # the text after `# ` (full first-line body) or "" if no comment.
  getDocstring =
    path:
    let
      text = builtins.readFile path;
      firstLine = builtins.head (lib.splitString "\n" text);
    in
    if lib.hasPrefix "# " firstLine then lib.removePrefix "# " firstLine else "";

  # Extract just the purpose half after the em-dash. `# name — purpose.` → `purpose.`
  # Falls back to the full docstring if there's no em-dash.
  getPurpose =
    path:
    let
      doc = getDocstring path;
      parts = lib.splitString " — " doc;
    in
    if builtins.length parts >= 2 then lib.concatStringsSep " — " (builtins.tail parts) else doc;

  # mkSimplePackage wrappers: extract `description = "..."` argument.
  # Returns empty string if not a wrapper.
  getSimplePackageDesc =
    path:
    let
      text = builtins.readFile path;
      isWrapper = lib.hasInfix "mkSimplePackage" text;
      match = builtins.match ".*description[[:space:]]*=[[:space:]]*\"([^\"]+)\".*" text;
    in
    if isWrapper && match != null then builtins.head match else "";

  # Pick the best description source per file: mkSimplePackage arg wins,
  # then em-dash purpose, then full docstring, then "".
  describeFile =
    path:
    let
      simple = getSimplePackageDesc path;
      purpose = getPurpose path;
      doc = getDocstring path;
    in
    if simple != "" then
      simple
    else if purpose != "" then
      purpose
    else
      doc;

  # List ".nix" files directly under a dir (non-recursive), excluding
  # underscore-prefix helpers and `default.nix` / `flake-module.nix`.
  nixFilesIn =
    dir:
    let
      entries = builtins.readDir dir;
      keep =
        name: type:
        type == "regular"
        && lib.hasSuffix ".nix" name
        && !(lib.hasPrefix "_" name)
        && name != "flake-module.nix";
    in
    lib.attrNames (lib.filterAttrs keep entries);

  # Subdirectories of a dir (non-recursive), excluding underscore-prefix.
  subDirsOf =
    dir:
    let
      entries = builtins.readDir dir;
      keep = name: type: type == "directory" && !(lib.hasPrefix "_" name);
    in
    lib.attrNames (lib.filterAttrs keep entries);

  # ---------- module reference ----------

  # Walk parts/<scope>/*.nix → entries of { scope, name, file, desc }.
  partsModules =
    let
      topLevel = map (n: {
        scope = lib.removeSuffix ".nix" n;
        name = lib.removeSuffix ".nix" n;
        file = "parts/${n}";
        desc = describeFile (../parts + "/${n}");
      }) (nixFilesIn ../parts);
      nested = lib.concatMap (
        scope:
        if scope == "hosts" || scope == "_build" then
          [ ]
        else
          map (n: {
            inherit scope;
            name = lib.removeSuffix ".nix" n;
            file = "parts/${scope}/${n}";
            desc = describeFile (../parts + "/${scope}/${n}");
          }) (nixFilesIn (../parts + "/${scope}"))
      ) (subDirsOf ../parts);
    in
    topLevel ++ nested;

  # Walk home/modules/<name>/default.nix and umbrella sub-modules.
  homeModules =
    let
      dirs = subDirsOf ../home/modules;
      perDir =
        dir:
        let
          defaultNix = ../home/modules + "/${dir}/default.nix";
          defaultExists = builtins.pathExists defaultNix;
          defaultEntry = lib.optional defaultExists {
            umbrella = null;
            name = dir;
            file = "home/modules/${dir}/default.nix";
            desc = describeFile defaultNix;
          };
          # Umbrella sub-modules (sibling .nix files)
          subNames = builtins.filter (n: n != "default.nix") (nixFilesIn (../home/modules + "/${dir}"));
          subEntries = map (n: {
            umbrella = dir;
            name = "${dir}.${lib.removeSuffix ".nix" n}";
            file = "home/modules/${dir}/${n}";
            desc = describeFile (../home/modules + "/${dir}/${n}");
          }) subNames;
        in
        defaultEntry ++ subEntries;
    in
    lib.concatMap perDir dirs;

  # Group parts modules by scope.
  partsByScope = builtins.groupBy (m: m.scope) partsModules;

  # Render one row of the module table.
  mkRow =
    { name, desc, ... }:
    let
      safeDesc = if desc == "" then "(no docstring)" else desc;
    in
    "| `${name}` | ${safeDesc} |";

  # Render a sorted section for one parts scope.
  mkPartsSection =
    scope:
    let
      mods = lib.sort (a: b: a.name < b.name) (partsByScope.${scope} or [ ]);
      header = ''
        ### ${lib.toUpper (builtins.substring 0 1 scope)}${
          builtins.substring 1 (builtins.stringLength scope - 1) scope
        } modules

        | Module | Description |
        | ------ | ----------- |
      '';
      rows = lib.concatStringsSep "\n" (map mkRow mods);
    in
    "${header}${rows}\n";

  partsScopes = lib.sort (a: b: a < b) (builtins.attrNames partsByScope);

  mkHmSection =
    let
      sorted = lib.sort (a: b: a.name < b.name) homeModules;
      header = ''
        ### Home-Manager modules

        | Module (option leaf) | Description |
        | -------------------- | ----------- |
      '';
      rows = lib.concatStringsSep "\n" (
        map (
          m: "| `myModules.home.${m.name}` | ${if m.desc == "" then "(no docstring)" else m.desc} |"
        ) sorted
      );
    in
    "${header}${rows}\n";

  moduleReferenceMarkdown =
    let
      parts = lib.concatStringsSep "\n" (map mkPartsSection partsScopes);
    in
    ''
      ## NixOS modules (`parts/`)

      ${parts}

      ## Home-Manager modules (`home/modules/`)

      ${mkHmSection}
    '';

  # ---------- directory layout ----------

  mkDirLayout =
    let
      # One line per parts/<scope>/<file> or parts/<file>
      partsLines = map (
        m:
        let
          pad = 60 - lib.stringLength m.file;
          spaces = lib.concatStrings (lib.genList (_: " ") (lib.max 1 pad));
        in
        "${m.file}${spaces}# ${if m.desc == "" then "(no docstring)" else m.desc}"
      ) (lib.sort (a: b: a.file < b.file) partsModules);

      homeLines = map (
        m:
        let
          pad = 60 - lib.stringLength m.file;
          spaces = lib.concatStrings (lib.genList (_: " ") (lib.max 1 pad));
        in
        "${m.file}${spaces}# ${if m.desc == "" then "(no docstring)" else m.desc}"
      ) (lib.sort (a: b: a.file < b.file) homeModules);
    in
    ''
      ```
      ${lib.concatStringsSep "\n" partsLines}

      ${lib.concatStringsSep "\n" homeLines}
      ```
    '';

  # ---------- flake inputs ----------

  flakeInputsMarkdown =
    let
      inputNames = lib.sort (a: b: a < b) (builtins.attrNames flake.inputs);
      row = name: "- `${name}`";
    in
    ''
      ${lib.concatStringsSep "\n" (map row inputNames)}

      _Total: ${toString (builtins.length inputNames)} flake inputs. Run `nix flake metadata` for pinned revisions + URLs._
    '';

in
{
  moduleReference = moduleReferenceMarkdown;
  directoryLayout = mkDirLayout;
  flakeInputs = flakeInputsMarkdown;
}
