{ config, pkgs, lib, inputs, ... }:
let
  cachyosSettings = inputs.cachyos-settings;

  # Safety filters
  dangerousSettings = [ "kernel.panic" "vm.drop_caches" "kernel.sysrq" "net.ipv4.ip_forward" ];
  nixosConflictSettings = [ "systemd.manager.LogLevel" "systemd.manager.LogTarget" ];
  
  # Parse sysctl configuration files
  parseSysctlSettings = settingsFile:
    let
      settingsPath = "${cachyosSettings}/${settingsFile}";
      content = if builtins.pathExists settingsPath then builtins.readFile settingsPath else "";
      lines = lib.splitString "\n" content;
      validLines = lib.filter (line: line != "" && !(lib.hasPrefix "#" line) && !(lib.hasPrefix ";" line) && lib.hasInfix "=" line) lines;
      parseValue = valueStr:
        let trimmed = lib.trim valueStr; in
        if trimmed == "1" || trimmed == "true" || trimmed == "yes" then true
        else if trimmed == "0" || trimmed == "false" || trimmed == "no" then false
        else if lib.match "^[0-9]+$" trimmed != null then lib.toInt trimmed
        else if lib.match "^-?[0-9]+$" trimmed != null then lib.toInt trimmed
        else trimmed;
      parseKeyValue = line:
        let parts = lib.splitString "=" line; key = lib.trim (lib.head parts); valueStr = lib.trim (lib.concatStringsSep "=" (lib.tail parts)); in lib.nameValuePair key (parseValue valueStr);
    in if content != "" then lib.listToAttrs (map parseKeyValue validLines) else {};
  
  # Safety filter for sysctl settings
  isSafeSetting = allowUnsafe: name: value:
    if allowUnsafe then true
    else let isDangerous = lib.any (pattern: lib.hasInfix pattern name) dangerousSettings; isNixosConflict = lib.elem name nixosConflictSettings; in !isDangerous && !isNixosConflict;
  
  # Dynamically discover all sysctl files
  discoverSysctlFiles = 
    let
      sysctlDir = "${cachyosSettings}/usr/lib/sysctl.d";
      dirExists = builtins.pathExists sysctlDir;
    in if dirExists then
      builtins.attrNames (builtins.readDir sysctlDir)
    else [];
  
  # Get all sysctl settings from all discovered files
  getAllSysctlSettings = allowUnsafe:
    let
      sysctlFiles = discoverSysctlFiles;
      allSettings = lib.foldl' (acc: file:
        acc // (parseSysctlSettings "usr/lib/sysctl.d/${file}")
      ) {} sysctlFiles;
    in lib.filterAttrs (isSafeSetting allowUnsafe) allSettings;
  
  # Category-based filtering
  getSettingsForCategory = category: enabled: settings:
    let categoryPatterns = { gaming = [ "vm.max_map_count" "vm.swappiness" "kernel.sched" ]; desktop = [ "vm.vfs_cache_pressure" "vm.dirty" ]; server = [ "net." "kernel.shmmax" ]; networking = [ "net." ]; storage = [ "vm.dirty" ]; };
        patterns = categoryPatterns.${category} or []; matchesCategory = name: lib.any (pattern: lib.hasInfix pattern name) patterns; in
    if enabled then lib.filterAttrs (name: value: matchesCategory name) settings else {};
  
  # Dynamically discover udev rules
  discoverUdevRules =
    let
      udevDir = "${cachyosSettings}/usr/lib/udev/rules.d";
      dirExists = builtins.pathExists udevDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${udevDir}/${name}";
      }) (builtins.readDir udevDir)
    else [];
  
  # Dynamically discover modprobe configs
  discoverModprobeConfigs =
    let
      modprobeDir = "${cachyosSettings}/usr/lib/modprobe.d";
      dirExists = builtins.pathExists modprobeDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${modprobeDir}/${name}";
      }) (builtins.readDir modprobeDir)
    else [];
  
  # Dynamically discover tmpfiles configs
  discoverTmpfilesConfigs =
    let
      tmpfilesDir = "${cachyosSettings}/usr/lib/tmpfiles.d";
      dirExists = builtins.pathExists tmpfilesDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${tmpfilesDir}/${name}";
      }) (builtins.readDir tmpfilesDir)
    else [];
  
  # Dynamically discover modules-load configs
  discoverModulesLoadConfigs =
    let
      modulesLoadDir = "${cachyosSettings}/usr/lib/modules-load.d";
      dirExists = builtins.pathExists modulesLoadDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${modulesLoadDir}/${name}";
      }) (builtins.readDir modulesLoadDir)
    else [];
  
  # Dynamically discover systemd .conf files (NOT .service files)
  discoverSystemdConfigs =
    let
      systemdDir = "${cachyosSettings}/usr/lib/systemd";
      dirExists = builtins.pathExists systemdDir;
      findConfigs = dir:
        let entries = if builtins.pathExists dir then builtins.readDir dir else {}; in
        lib.flatten (lib.mapAttrsToList (name: type:
          if type == "directory" && !(lib.hasSuffix ".d" name) then findConfigs "${dir}/${name}"
          # Only apply .conf files, not .service files (services handled separately)
          else if type == "regular" && lib.hasSuffix ".conf" name
          then 
            # EXCLUDE timesyncd, zram-generator, and resolved (conflicts with NixOS modules)
            if lib.hasInfix "timesyncd" name || lib.hasInfix "zram-generator" name || lib.hasInfix "resolved" name then []
            else [{ inherit name; path = "${dir}/${name}"; relPath = lib.removePrefix "${systemdDir}/" "${dir}/${name}"; }]
          else []
        ) entries);
    in if dirExists then findConfigs systemdDir else [];
  
  # Dynamically discover systemd .service files
  discoverSystemdServices =
    let
      systemdDir = "${cachyosSettings}/usr/lib/systemd";
      dirExists = builtins.pathExists systemdDir;
      findServices = dir:
        let entries = if builtins.pathExists dir then builtins.readDir dir else {}; in
        lib.flatten (lib.mapAttrsToList (name: type:
          if type == "directory" then findServices "${dir}/${name}"
          else if type == "regular" && lib.hasSuffix ".service" name
          then [{ inherit name; path = "${dir}/${name}"; serviceName = lib.removeSuffix ".service" name; }]
          else []
        ) entries);
    in if dirExists then findServices systemdDir else [];
  
  # Dynamically discover NetworkManager configs
  discoverNetworkManagerConfigs =
    let
      nmDir = "${cachyosSettings}/usr/lib/NetworkManager/conf.d";
      dirExists = builtins.pathExists nmDir;
    in if dirExists then
      lib.flatten (lib.mapAttrsToList (name: type: 
        # EXCLUDE DNS related configs (conflicts with Portmaster/NixOS DNS)
        if lib.hasInfix "dns" (lib.toLower name) || lib.hasInfix "resolved" (lib.toLower name) then []
        else [{
          inherit name;
          path = "${nmDir}/${name}";
        }]
      ) (builtins.readDir nmDir))
    else [];
  
  # Dynamically discover security limits
  discoverSecurityLimits =
    let
      limitsDir = "${cachyosSettings}/etc/security/limits.d";
      dirExists = builtins.pathExists limitsDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${limitsDir}/${name}";
      }) (builtins.readDir limitsDir)
    else [];
  
  # Dynamically discover utility scripts
  discoverUtilityScripts =
    let
      binDir = "${cachyosSettings}/usr/bin";
      dirExists = builtins.pathExists binDir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${binDir}/${name}";
      }) (builtins.readDir binDir)
    else [];
  
  # Dynamically discover X11 configs
  discoverX11Configs =
    let
      x11Dir = "${cachyosSettings}/usr/share/X11/xorg.conf.d";
      dirExists = builtins.pathExists x11Dir;
    in if dirExists then
      lib.mapAttrsToList (name: type: {
        inherit name;
        path = "${x11Dir}/${name}";
      }) (builtins.readDir x11Dir)
    else [];

in {
  imports = [ ./kernel.nix ];

  options.myModules.cachyos.settings.enable = lib.mkEnableOption "CachyOS settings integration";
  options.myModules.cachyos.settings.autoUpdate = lib.mkOption { type = lib.types.bool; default = true; };
  options.myModules.cachyos.settings.allowUnsafe = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = lib.mdDoc ''
      **WARNING: FOR TESTING ONLY!**
      
      When enabled, disables all safety filters and applies ALL CachyOS sysctl settings,
      including potentially dangerous ones like kernel.panic, vm.drop_caches, kernel.sysrq,
      and settings that may conflict with NixOS's systemd management.
      
      This is useful for testing the full CachyOS experience and comparing system behavior,
      but should NOT be used in production without careful review of what's being applied.
      
      Enable debug mode to see exactly which settings are being applied.
    '';
  };
  options.myModules.cachyos.settings.applyAllConfigs = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = lib.mdDoc ''
      **EXPERIMENTAL: Truly Dynamic Mode**
      
      When enabled, automatically discovers and applies ALL configuration files from CachyOS:
      - All sysctl.d files (not just 99-cachyos-settings.conf)
      - All udev rules
      - All modprobe configurations
      - All tmpfiles configurations
      
      This makes the integration truly future-proof - any new files CachyOS adds will be
      automatically discovered and applied on the next flake update.
      
      **WARNING:** This is experimental and may conflict with your existing NixOS configuration.
      Enable debug mode to see what's being applied.
    '';
  };
  options.myModules.cachyos.settings.categories.gaming = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.categories.desktop = lib.mkOption { type = lib.types.bool; default = true; };
  options.myModules.cachyos.settings.categories.server = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.categories.networking = lib.mkOption { type = lib.types.bool; default = true; };
  options.myModules.cachyos.settings.categories.storage = lib.mkOption { type = lib.types.bool; default = true; };
  options.myModules.cachyos.settings.debug = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.capJournald = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.applyTmpfilesTHP = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.x11TapToClick = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.applyUdevIOSchedulers = lib.mkOption { type = lib.types.bool; default = false; };
  options.myModules.cachyos.settings.applySATAALPM = lib.mkOption { type = lib.types.bool; default = false; };
  
  config = let cfg = config.myModules.cachyos.settings; in lib.mkIf cfg.enable ( {
    boot.kernel.sysctl = let
      cfg = config.myModules.cachyos.settings;
      cachyosSysctlSettings = getAllSysctlSettings cfg.allowUnsafe;
      gamingSettings = getSettingsForCategory "gaming" (cfg.categories.gaming or false) cachyosSysctlSettings;
      desktopSettings = getSettingsForCategory "desktop" (cfg.categories.desktop or true) cachyosSysctlSettings;
      serverSettings = getSettingsForCategory "server" (cfg.categories.server or false) cachyosSysctlSettings;
      networkingSettings = getSettingsForCategory "networking" (cfg.categories.networking or true) cachyosSysctlSettings;
      storageSettings = getSettingsForCategory "storage" (cfg.categories.storage or true) cachyosSysctlSettings;
      applied = gamingSettings // desktopSettings // serverSettings // networkingSettings // storageSettings;
    in lib.mkMerge [ applied (lib.optionalAttrs cfg.debug { "# CachyOS settings applied" = 1; }) ];
    
    assertions = [
      { assertion = (!cfg.enable) || (lib.any (cat: (cfg.categories.${cat} or false)) (lib.attrNames cfg.categories)); message = "CachyOS settings enabled but no categories selected."; }
      { assertion = !cfg.allowUnsafe || cfg.debug; message = "CachyOS allowUnsafe mode requires debug mode to be enabled for safety tracking."; }
      { assertion = !cfg.applyAllConfigs || cfg.debug; message = "CachyOS applyAllConfigs mode requires debug mode to be enabled for tracking."; }
    ];
    
    warnings = 
      (lib.optional cfg.allowUnsafe ''
        CachyOS settings: allowUnsafe is enabled! All safety filters are disabled.
        This applies potentially dangerous settings including kernel.panic, vm.drop_caches,
        kernel.sysrq, and settings that may conflict with NixOS management.
        Review /etc/cachyos-settings-info.txt to see what's being applied.
        This mode is FOR TESTING ONLY and should not be used in production!
      '') ++
      (lib.optional cfg.applyAllConfigs ''
        CachyOS settings: applyAllConfigs is enabled! This is EXPERIMENTAL.
        All configuration files from CachyOS repository are being automatically discovered and applied.
        This includes udev rules, modprobe configs, and tmpfiles that may conflict with your system.
        Review /etc/cachyos-settings-info.txt to see what's being applied.
      '');
    
    # Apply X11 configs dynamically if applyAllConfigs is enabled
    services.xserver.config = lib.mkIf cfg.applyAllConfigs (
      lib.concatStringsSep "\n" (map (conf: builtins.readFile conf.path) (discoverX11Configs))
    );
    
    # Apply tmpfiles rules dynamically if applyAllConfigs is enabled
    systemd.tmpfiles.rules = 
      (lib.optionals cfg.applyTmpfilesTHP [
        "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
        "w! /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
        "w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409"
      ]) ++
      (lib.optionals cfg.applyAllConfigs (
        lib.flatten (map (conf: 
          let content = builtins.readFile conf.path;
              lines = lib.splitString "\n" content;
          in lib.filter (line: line != "" && !(lib.hasPrefix "#" line)) lines
        ) (discoverTmpfilesConfigs))
      ));
    
    # Dynamically create systemd services from CachyOS .service files
    # Wrap scripts with bash to fix shebang issues (e.g., pci-latency)
    # Also strip DOS line endings (\r) which cause "command not found" errors
    systemd.services = lib.mkIf cfg.applyAllConfigs (
      lib.listToAttrs (map (svc:
        let
          # Read the script content
          scriptContent = builtins.readFile "${cachyosSettings}/usr/bin/${svc.serviceName}";
          # Strip \r characters
          cleanScriptContent = lib.replaceStrings ["\r"] [""] scriptContent;
          # Create a new script file with clean content
          actualScript = pkgs.writeScriptBin svc.serviceName cleanScriptContent;
          
          # Create a wrapper script that executes the clean script through bash
          # and ensures pciutils (for setpci) is in the path
          wrappedScript = pkgs.writeShellScript "${svc.serviceName}-wrapper" ''
            export PATH=$PATH:${lib.makeBinPath [ pkgs.pciutils pkgs.bash ]}
            exec ${pkgs.bash}/bin/bash ${actualScript}/bin/${svc.serviceName} "$@"
          '';
        in
        lib.nameValuePair svc.serviceName {
          description = "CachyOS ${svc.serviceName} service";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${wrappedScript}";
          };
          wantedBy = [ "multi-user.target" ];
        }
      ) (discoverSystemdServices))
    );
    
    environment.etc = lib.mkMerge [
      (lib.mkIf cfg.debug {
        "cachyos-settings-info.txt".text = let
          cfg = config.myModules.cachyos.settings;
          cachyosSysctlSettings = getAllSysctlSettings cfg.allowUnsafe;
          allSysctlFiles = discoverSysctlFiles;
          allUdevRules = discoverUdevRules;
          allModprobeConfigs = discoverModprobeConfigs;
          allTmpfilesConfigs = discoverTmpfilesConfigs;
          allModulesLoadConfigs = discoverModulesLoadConfigs;
          allSystemdConfigs = discoverSystemdConfigs;
          allSystemdServices = discoverSystemdServices;
          allNetworkManagerConfigs = discoverNetworkManagerConfigs;
          allSecurityLimits = discoverSecurityLimits;
          allUtilityScripts = discoverUtilityScripts;
          allX11Configs = discoverX11Configs;
          allSettings = lib.foldl' (acc: file: acc // (parseSysctlSettings "usr/lib/sysctl.d/${file}")) {} allSysctlFiles;
          filteredOutSettings = lib.filterAttrs (n: v: !(isSafeSetting cfg.allowUnsafe n v)) allSettings;
          gamingSettings = getSettingsForCategory "gaming" (cfg.categories.gaming or false) cachyosSysctlSettings;
          desktopSettings = getSettingsForCategory "desktop" (cfg.categories.desktop or true) cachyosSysctlSettings;
          serverSettings = getSettingsForCategory "server" (cfg.categories.server or false) cachyosSysctlSettings;
          networkingSettings = getSettingsForCategory "networking" (cfg.categories.networking or true) cachyosSysctlSettings;
          storageSettings = getSettingsForCategory "storage" (cfg.categories.storage or true) cachyosSysctlSettings;
          applied = gamingSettings // desktopSettings // serverSettings // networkingSettings // storageSettings;
          totalFiles = (lib.length allSysctlFiles) + (lib.length allUdevRules) + (lib.length allModprobeConfigs) + 
                       (lib.length allTmpfilesConfigs) + (lib.length allModulesLoadConfigs) + (lib.length allSystemdConfigs) + 
                       (lib.length allSystemdServices) + (lib.length allNetworkManagerConfigs) + (lib.length allSecurityLimits) + 
                       (lib.length allUtilityScripts) + (lib.length allX11Configs);
        in ''
          CachyOS Settings Integration Status
          ==================================
          Repository: ${cachyosSettings}
          Unsafe Mode: ${if cfg.allowUnsafe then "ENABLED (ALL FILTERS DISABLED!)" else "Disabled (Safe mode)"}
          Apply All Configs: ${if cfg.applyAllConfigs then "ENABLED (EXPERIMENTAL)" else "Disabled"}
          Categories enabled: ${lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (n: v: v) cfg.categories))}
          
          Discovered Configuration Files (TOTAL: ${toString totalFiles})
          ==============================
          Sysctl files (${toString (lib.length allSysctlFiles)}):
          ${lib.concatStringsSep "\n" (map (f: "  - ${f}") allSysctlFiles)}
          
          Udev rules (${toString (lib.length allUdevRules)}):
          ${lib.concatStringsSep "\n" (map (r: "  - ${r.name}") allUdevRules)}
          
          Modprobe configs (${toString (lib.length allModprobeConfigs)}):
          ${lib.concatStringsSep "\n" (map (m: "  - ${m.name}") allModprobeConfigs)}
          
          Tmpfiles configs (${toString (lib.length allTmpfilesConfigs)}):
          ${lib.concatStringsSep "\n" (map (t: "  - ${t.name}") allTmpfilesConfigs)}
          
          Modules-load configs (${toString (lib.length allModulesLoadConfigs)}):
          ${lib.concatStringsSep "\n" (map (m: "  - ${m.name}") allModulesLoadConfigs)}
          
          Systemd configs (${toString (lib.length allSystemdConfigs)}):
          ${lib.concatStringsSep "\n" (map (s: "  - ${s.relPath}") allSystemdConfigs)}
          
          Systemd services (${toString (lib.length allSystemdServices)}):
          ${lib.concatStringsSep "\n" (map (s: "  - ${s.name}") allSystemdServices)}
          
          NetworkManager configs (${toString (lib.length allNetworkManagerConfigs)}):
          ${lib.concatStringsSep "\n" (map (n: "  - ${n.name}") allNetworkManagerConfigs)}
          
          Security limits (${toString (lib.length allSecurityLimits)}):
          ${lib.concatStringsSep "\n" (map (l: "  - ${l.name}") allSecurityLimits)}
          
          Utility scripts (${toString (lib.length allUtilityScripts)}):
          ${lib.concatStringsSep "\n" (map (u: "  - ${u.name}") allUtilityScripts)}
          
          X11 configs (${toString (lib.length allX11Configs)}):
          ${lib.concatStringsSep "\n" (map (x: "  - ${x.name}") allX11Configs)}
          
          Applied Sysctl Settings (${toString (lib.length (lib.attrNames applied))})
          =====================
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "  ${name} = ${toString value}") applied)}
          ${lib.optionalString (!cfg.allowUnsafe && (lib.length (lib.attrNames filteredOutSettings)) > 0) ''
          
          Filtered Out (unsafe/conflicting) Settings (${toString (lib.length (lib.attrNames filteredOutSettings))})
          ==========================================
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "  ${name} = ${toString value} (FILTERED)") filteredOutSettings)}
          ''}
        '';
      })

      # Apply modules-load configs dynamically if applyAllConfigs is enabled
      (lib.mkIf cfg.applyAllConfigs (
        lib.listToAttrs (map (conf: {
          name = "modules-load.d/${conf.name}";
          value = { source = conf.path; };
        }) (discoverModulesLoadConfigs))
      ))

      # Apply systemd configs dynamically if applyAllConfigs is enabled
      (lib.mkIf cfg.applyAllConfigs (
        lib.listToAttrs (map (conf: {
          name = "systemd/${builtins.unsafeDiscardStringContext conf.relPath}";
          value = { source = conf.path; };
        }) (discoverSystemdConfigs))
      ))

      # Apply NetworkManager configs dynamically if applyAllConfigs is enabled
      (lib.mkIf cfg.applyAllConfigs (
        lib.listToAttrs (map (conf: {
          name = "NetworkManager/conf.d/${conf.name}";
          value = { source = conf.path; };
        }) (discoverNetworkManagerConfigs))
      ))

      # Apply security limits dynamically if applyAllConfigs is enabled
      (lib.mkIf cfg.applyAllConfigs (
        lib.listToAttrs (map (conf: {
          name = "security/limits.d/${conf.name}";
          value = { source = conf.path; };
        }) (discoverSecurityLimits))
      ))
    ];
    
    environment.systemPackages = lib.optionals cfg.debug [ (pkgs.writeShellScriptBin "cachyos-settings-info" (lib.replaceStrings ["\r\n" "\r"] ["\n" ""] ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      echo "CachyOS Settings Integration Info:"
      echo "Repository: ${cachyosSettings}"
      echo "Settings file: /etc/cachyos-settings-info.txt"
      [ -f /etc/cachyos-settings-info.txt ] && cat /etc/cachyos-settings-info.txt || true
    '' )) ] ++ (lib.optionals cfg.applyAllConfigs (
      map (script: pkgs.writeScriptBin script.name (
        lib.replaceStrings ["\r"] [""] (builtins.readFile script.path)
      )) (discoverUtilityScripts)
    ));

    # Apply udev rules dynamically if applyAllConfigs is enabled
    # Patch absolute paths to use Nix store paths
    services.udev.extraRules = let
      schedRules = ''
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*", ATTR{queue/rotational}=="1", RUN+="/bin/sh -c 'echo bfq > /sys$devpath/queue/scheduler'"
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*", ATTR{queue/rotational}=="0", RUN+="/bin/sh -c 'echo mq-deadline > /sys$devpath/queue/scheduler'"
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme*", RUN+="/bin/sh -c 'echo none > /sys$devpath/queue/scheduler'"
      '';
      alpmRules = ''
        ACTION=="add", SUBSYSTEM=="scsi_host", TEST=="/sys$devpath/link_power_management_policy", RUN+="/bin/sh -c 'echo max_performance > /sys$devpath/link_power_management_policy'"
      '';
      dynamicUdevRules = if cfg.applyAllConfigs then
        lib.concatStringsSep "\n" (map (rule: 
          let content = builtins.readFile rule.path; in
          lib.replaceStrings 
            ["/usr/bin/bash" "/usr/bin/hdparm"] 
            ["${pkgs.bash}/bin/bash" "${pkgs.hdparm}/bin/hdparm"] 
            content
        ) (discoverUdevRules))
      else "";
      addSched = lib.optionalString cfg.applyUdevIOSchedulers schedRules;
      addAlpm = lib.optionalString cfg.applySATAALPM alpmRules;
    in addSched + addAlpm + dynamicUdevRules;
    
    # Apply modprobe configs dynamically if applyAllConfigs is enabled
    boot.extraModprobeConfig = lib.mkIf cfg.applyAllConfigs (
      lib.concatStringsSep "\n" (map (conf: builtins.readFile conf.path) (discoverModprobeConfigs))
    );

    services.journald = lib.mkIf cfg.capJournald { extraConfig = "SystemMaxUse=50M"; };
    services.libinput = lib.mkIf cfg.x11TapToClick { touchpad.tapping = true; };
    
    # Apply CachyOS zram settings (from zram-generator.conf)
    # CachyOS uses: compression-algorithm=zstd, zram-size=ram (100%), swap-priority=100
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 100;
      priority = 100;
    };
  } );
}