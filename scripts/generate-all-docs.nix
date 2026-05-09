# generate-all-docs.nix — single-eval doc generator for ALL outputs.
#
# Merges generate-docs.nix, generate-hm-template.nix, generate-host-template.nix,
# and generate-readme-sections.nix into ONE flake evaluation. Previous setup
# called builtins.getFlake 4× (7 nix eval calls) — ~144s on MacBook.
# This file: 1 eval, ~40-70s.
#
# Usage:
#   nix eval --raw --impure --file scripts/generate-all-docs.nix markdown
#   nix eval --json --impure --file scripts/generate-all-docs.nix json
#   nix eval --raw --impure --file scripts/generate-all-docs.nix hostTemplate
#   nix eval --raw --impure --file scripts/generate-all-docs.nix hmTemplate
#   nix eval --raw --impure --file scripts/generate-all-docs.nix moduleReference
#   nix eval --raw --impure --file scripts/generate-all-docs.nix directoryLayout
#   nix eval --raw --impure --file scripts/generate-all-docs.nix flakeInputs
{
  pkgs ? import <nixpkgs> { },
  flake ? builtins.getFlake (toString ../.),
}:

let
  inherit (pkgs) lib;

  # ══════════════════════════════════════════════════════════════════════
  # Shared flake evaluation (done ONCE)
  # ══════════════════════════════════════════════════════════════════════
  hostNames = builtins.attrNames flake.nixosConfigurations;
  allConfigs = builtins.attrValues flake.nixosConfigurations;
  firstHost = builtins.head hostNames;
  firstEval = flake.nixosConfigurations.${firstHost};

  # ══════════════════════════════════════════════════════════════════════
  # OPTIONS.md + options.json (from generate-docs.nix)
  # ══════════════════════════════════════════════════════════════════════
  mergedOptions = lib.foldl' (acc: cfg: lib.recursiveUpdate acc cfg.options.myModules) { } allConfigs;

  isOption = v: lib.isAttrs v && (v._type or "") == "option";
  renderType = t: t.description or t.name or "<unknown>";
  renderDefault =
    opt:
    if !(opt ? default) then
      "—"
    else if lib.isFunction opt.default then
      "<function>"
    else if lib.isDerivation opt.default then
      "<derivation>"
    else if opt.default == null then
      "null"
    else if lib.isString opt.default then
      "\"${opt.default}\""
    else if lib.isBool opt.default then
      (if opt.default then "true" else "false")
    else if lib.isInt opt.default || lib.isFloat opt.default then
      toString opt.default
    else if lib.isList opt.default then
      "[${lib.concatMapStringsSep " " (x: "\"${toString x}\"") opt.default}]"
    else if lib.isAttrs opt.default then
      (
        let
          hasText = opt.default._type or "" == "literalExpression" || opt.default._type or "" == "literalMD";
        in
        if hasText then opt.default.text else "{ … }"
      )
    else
      "<complex>";

  renderDescription =
    opt:
    let
      d = opt.description or "";
    in
    if lib.isString d then
      d
    else if lib.isAttrs d && d ? _type && d ? text then
      d.text
    else
      "";

  locToPath = loc: lib.concatStringsSep "." loc;

  renderOptions =
    path: node:
    if isOption node then
      let
        name = locToPath path;
        desc = renderDescription node;
        typ = renderType node.type;
        def = renderDefault node;
      in
      ''
        ### `${name}`

        ${desc}

        - **Type:** `${typ}`
        - **Default:** `${def}`
      ''
    else if lib.isAttrs node then
      lib.concatStringsSep "\n" (map (n: renderOptions (path ++ [ n ]) node.${n}) (lib.attrNames node))
    else
      "";

  docsBody = renderOptions [ "myModules" ] mergedOptions;

  collectJson =
    path: node:
    if isOption node then
      [
        {
          name = locToPath path;
          type = renderType node.type;
          default = renderDefault node;
          description = renderDescription node;
        }
      ]
    else if lib.isAttrs node then
      lib.concatMap (n: collectJson (path ++ [ n ]) node.${n}) (lib.attrNames node)
    else
      [ ];

  # ══════════════════════════════════════════════════════════════════════
  # HM host template (from generate-hm-template.nix)
  # ══════════════════════════════════════════════════════════════════════
  inherit (firstEval.config.myModules) primaryUser;
  hmConfig = firstEval.config.home-manager.users.${primaryUser}.myModules.home;
  hmModuleNames = builtins.sort (a: b: a < b) (builtins.attrNames hmConfig);

  formatHmToggle =
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

  hmToggleBlock = lib.concatStringsSep "\n" (map formatHmToggle hmModuleNames);

  # ══════════════════════════════════════════════════════════════════════
  # NixOS host template (from generate-host-template.nix)
  # ══════════════════════════════════════════════════════════════════════
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

  optionsForHost = host: findOptions "" flake.nixosConfigurations.${host}.options.myModules;
  allRawOptions = lib.concatLists (map optionsForHost hostNames);
  allHostOptions = builtins.attrValues (
    builtins.listToAttrs (
      map (opt: {
        name = opt.path;
        value = opt;
      }) allRawOptions
    )
  );

  formatHostDefault =
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

  isSimpleHostDefault =
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

  groupedBySubNs = builtins.groupBy (opt: getSubNamespace opt.path) allHostOptions;
  subNamespaces = builtins.sort (a: b: a < b) (builtins.attrNames groupedBySubNs);

  formatHostOption =
    opt:
    let
      parts = lib.splitString "." opt.path;
      relParts = lib.drop 2 parts;
      relPath = lib.concatStringsSep "." relParts;
      displayPath = if relPath == "" then opt.path else relPath;
      defaultStr = formatHostDefault opt.default;
      simple = isSimpleHostDefault opt.default;
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

  formatSubNamespace =
    ns:
    let
      opts = groupedBySubNs.${ns};
      count = builtins.length opts;
      simpleOpts = builtins.filter (opt: isSimpleHostDefault opt.default) opts;
      complexCount = count - builtins.length simpleOpts;
      lines = map formatHostOption simpleOpts;
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

  # ══════════════════════════════════════════════════════════════════════
  # README sections (from generate-readme-sections.nix)
  # ══════════════════════════════════════════════════════════════════════
  getDocstring =
    path:
    let
      text = builtins.readFile path;
      firstLine = builtins.head (lib.splitString "\n" text);
    in
    if lib.hasPrefix "# " firstLine then lib.removePrefix "# " firstLine else "";

  getPurpose =
    path:
    let
      doc = getDocstring path;
      parts = lib.splitString " — " doc;
    in
    if builtins.length parts >= 2 then lib.concatStringsSep " — " (builtins.tail parts) else doc;

  getSimplePackageDesc =
    path:
    let
      text = builtins.readFile path;
      isWrapper = lib.hasInfix "mkSimplePackage" text;
      match = builtins.match ".*description[[:space:]]*=[[:space:]]*\"([^\"]+)\".*" text;
    in
    if isWrapper && match != null then builtins.head match else "";

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

  subDirsOf =
    dir:
    let
      entries = builtins.readDir dir;
      keep = name: type: type == "directory" && !(lib.hasPrefix "_" name);
    in
    lib.attrNames (lib.filterAttrs keep entries);

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

  partsByScope = builtins.groupBy (m: m.scope) partsModules;
  mkRow =
    { name, desc, ... }:
    let
      safeDesc = if desc == "" then "(no docstring)" else desc;
    in
    "| `${name}` | ${safeDesc} |";

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

in
{
  # ── OPTIONS.md ──
  markdown = ''
    # Options Reference

    > Auto-generated by `scripts/generate-all-docs.nix`. Do not edit manually.

    ---

    ${docsBody}
  '';

  # ── options.json ──
  json = collectJson [ "myModules" ] mergedOptions;

  # ── host-template.nix.example ──
  hostTemplate = ''
    # ==========================================================================
    # NixOS Host Configuration Template
    # ==========================================================================
    # Auto-generated from myModules option definitions.
    # ${toString (builtins.length allHostOptions)} options across ${toString (builtins.length subNamespaces)} groups.
    #
    # Copy to parts/hosts/<hostname>/default.nix and uncomment options to set.
    # Regenerate: pre-commit hook or nix eval --raw --impure -f scripts/generate-all-docs.nix hostTemplate
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
    ${lib.concatStringsSep "\n" (map formatSubNamespace subNamespaces)}
      };

      system.stateVersion = "26.05";
      networking.hostName = "<hostname>";
      time.timeZone = "Europe/Berlin";
    }
  '';

  # ── hm-host-template.nix.example ──
  hmTemplate = ''
    # ==========================================================================
    # Home Manager Host Configuration Template
    # ==========================================================================
    # Auto-generated from myModules.home option definitions.
    # ${toString (builtins.length hmModuleNames)} modules available.
    #
    # Copy to home/hosts/<hostname>/default.nix and customise.
    # Regenerate: pre-commit hook or nix eval --raw --impure -f scripts/generate-all-docs.nix hmTemplate
    # ==========================================================================
    {
      config,
      lib,
      ...
    }:
    {
      programs.git.settings.user = {
        name = "<username>";
        email = "<email>";
      };

    ${hmToggleBlock}
    }
  '';

  # ── README sections ──
  moduleReference = ''
    ## NixOS modules (`parts/`)

    ${lib.concatStringsSep "\n" (map mkPartsSection partsScopes)}

    ## Home-Manager modules (`home/modules/`)

    ${mkHmSection}
  '';

  directoryLayout = ''
    ```
    ${lib.concatStringsSep "\n" (
      map (
        m:
        let
          pad = 60 - lib.stringLength m.file;
          spaces = lib.concatStrings (lib.genList (_: " ") (lib.max 1 pad));
        in
        "${m.file}${spaces}# ${if m.desc == "" then "(no docstring)" else m.desc}"
      ) (lib.sort (a: b: a.file < b.file) partsModules)
    )}

    ${lib.concatStringsSep "\n" (
      map (
        m:
        let
          pad = 60 - lib.stringLength m.file;
          spaces = lib.concatStrings (lib.genList (_: " ") (lib.max 1 pad));
        in
        "${m.file}${spaces}# ${if m.desc == "" then "(no docstring)" else m.desc}"
      ) (lib.sort (a: b: a.file < b.file) homeModules)
    )}
    ```
  '';

  flakeInputs =
    let
      inputNames = lib.sort (a: b: a < b) (builtins.attrNames flake.inputs);
    in
    ''
      ${lib.concatStringsSep "\n" (map (name: "- `${name}`") inputNames)}

      _Total: ${toString (builtins.length inputNames)} flake inputs. Run `nix flake metadata` for pinned revisions + URLs._
    '';
}
