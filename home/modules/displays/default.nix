# Display arrangement, toggle scripts, tiling activation, and systemd services.
# All config is derived from osConfig.myModules.desktop.displays (NixOS module).
{ config, pkgs, lib, osConfig, ... }:

let
  cfg = osConfig.myModules.desktop.displays;

  # Convert millihertz to kscreen-doctor refresh rate string (e.g. 239757 → "239.76")
  mhzToRefresh = mhz:
    let
      rounded = (mhz + 5) / 10; # integer division with rounding
      whole = rounded / 100;
      frac = rounded - (whole * 100);
      fracStr = if frac < 10 then "0${toString frac}" else toString frac;
    in "${toString whole}.${fracStr}";

  # Rotation → kscreen-doctor rotation argument
  rotationToKscreen = r: {
    normal = "none";
    right = "right";
    left = "left";
    inverted = "inverted";
  }.${r};

  # All monitors sorted by priority
  sortedMonitors = lib.sort (a: b: a.priority < b.priority) (lib.attrValues cfg.monitors);

  # Enabled monitors (for display-arrange)
  enabledMonitors = builtins.filter (m: m.enabled) sortedMonitors;
  disabledMonitors = builtins.filter (m: !m.enabled) sortedMonitors;

  # Monitors with tiling layouts
  tilingMonitors = builtins.filter (m: m.tiling.layout != null && m.uuid != null) sortedMonitors;

  # Monitors with toggle scripts
  toggleMonitors = builtins.filter (m: m.toggle.enable) sortedMonitors;

  # Generate kscreen-doctor commands for a single monitor
  monitorArrangeCmd = m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
      rotationArgs = lib.optionalString (m.rotation != "normal")
        "output.${m.connector}.rotation.${rotationToKscreen m.rotation} \\";
    in ''
      # ${m.connector}: priority ${toString m.priority}
      kscreen-doctor \
        output.${m.connector}.enable \
        output.${m.connector}.mode.${modeStr} \
        ${lib.optionalString (m.rotation != "normal") "output.${m.connector}.rotation.${rotationToKscreen m.rotation} \\"}
        output.${m.connector}.position.${toString m.position.x},${toString m.position.y} \
        output.${m.connector}.priority.${toString m.priority} \
        2>/dev/null || true
    '';

  monitorDisableCmd = m: ''
    kscreen-doctor output.${m.connector}.disable 2>/dev/null || true
  '';

  # Build display-arrange script
  displayArrangeScript = pkgs.writeShellScriptBin "display-arrange" (
    lib.concatMapStrings monitorArrangeCmd enabledMonitors
    + lib.concatMapStrings monitorDisableCmd disabledMonitors
  );

  # Build toggle script for a monitor
  mkToggleScript = m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
      # Reposition commands when toggling ON
      repositionOn = lib.concatStringsSep " \\\n          " (
        lib.mapAttrsToList (conn: pos:
          "\"output.${conn}.position.${toString pos.x},${toString pos.y}\""
        ) m.toggle.repositions
      );
      # Default positions (from monitor definitions) when toggling OFF
      repositionOff = lib.concatStringsSep " \\\n          " (
        builtins.map (om:
          "\"output.${om.connector}.position.${toString om.position.x},${toString om.position.y}\""
        ) (builtins.filter (om: builtins.hasAttr om.connector m.toggle.repositions) sortedMonitors)
      );
    in pkgs.writeShellScriptBin m.toggle.scriptName ''
      export PATH="${lib.makeBinPath [ pkgs.kdePackages.qttools ]}"''${PATH:+:$PATH}
      output="${m.connector}"
      if kscreen-doctor --outputs 2>/dev/null | grep -A1 "$output" | grep -q "enabled"; then
        # Disable ${m.connector}, restore default positions
        kscreen-doctor \
          "output.$output.disable" \
          ${repositionOff} \
          2>/dev/null
        echo "${m.connector} disabled"
      else
        # Enable ${m.connector}, reposition other monitors
        kscreen-doctor \
          "output.$output.enable" \
          "output.$output.mode.${modeStr}" \
          "output.$output.position.${toString m.position.x},${toString m.position.y}" \
          "output.$output.priority.${toString m.priority}" \
          ${repositionOn} \
          2>/dev/null
        echo "${m.connector} enabled"
      fi
      # Nudge KWin to re-read tiling config for the new screen layout
      qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
    '';

  # Tiling activation script
  tilingActivation = let
    kwc = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
    sed = "${pkgs.gnused}/bin/sed";

    # Write tile layout for each monitor
    tileCommands = lib.concatMapStrings (m: ''
      $KWC --file "$KWINRC" \
        --group Tiling --group Desktop_1 --group "${m.uuid}" \
        --key tiles '${m.tiling.layout}'
      $KWC --file "$KWINRC" \
        --group Tiling --group Desktop_1 --group "${m.uuid}" \
        --key padding ${toString m.tiling.padding}
    '') tilingMonitors;

    # Purge phantom UUIDs
    phantomPurge = lib.concatMapStrings (uuid: ''
      $SED -i '/${uuid}/,/^$/d' "$KWINRC" 2>/dev/null || true
    '') cfg.phantomUuids;
  in ''
    KWINRC="$HOME/.config/kwinrc"
    KWC="${kwc}"
    SED="${sed}"

    # ── Purge ALL stale Tiling entries (plasma-manager ][  escaping bug) ──
    $SED -i '/Tiling.*\\\\x5d\\\\x5b/,/^$/d' "$KWINRC" 2>/dev/null || true
    $SED -i '/Tiling.*x5d.*x5b/,/^$/d' "$KWINRC" 2>/dev/null || true
    $SED -i '/^\[Tiling\]\[[^D]/,/^$/d' "$KWINRC" 2>/dev/null || true
    $SED -i '/^\[Tiling\]\[Desktop_1\]\[\]$/,/^$/d' "$KWINRC" 2>/dev/null || true

    # ── Write per-monitor tile layouts ──
    ${tileCommands}
    # ── Purge phantom UUIDs ──
    ${phantomPurge}
  '';

in lib.mkIf cfg.enable {

  # Packages: display-arrange + toggle scripts
  home.packages = [ displayArrangeScript ]
    ++ builtins.map mkToggleScript toggleMonitors;

  # Tiling activation (runs on Home Manager switch)
  home.activation.configureTiling = lib.hm.dag.entryAfter [ "writeBoundary" ] tilingActivation;

  # Run display-arrange on login
  systemd.user.services.display-arrange = {
    Unit = {
      Description = "Enforce display arrangement";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "display-arrange-exec" ''
        # Brief delay for KScreen to initialize outputs
        sleep 2
        display-arrange
      ''}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Run display-arrange on wake from sleep/suspend
  systemd.user.services.display-arrange-wake = {
    Unit = {
      Description = "Enforce display arrangement after wake";
      After = [ "sleep.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "display-arrange-wake-exec" ''
        sleep 3
        if kscreen-doctor --outputs 2>/dev/null | grep -q "Output:"; then
          display-arrange
        else
          echo "display-arrange-wake: no outputs detected, skipping" >&2
        fi
      ''}";
    };
    Install.WantedBy = [ "sleep.target" ];
  };
}
