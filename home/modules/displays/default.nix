# Display arrangement, toggle scripts, tiling activation, and systemd services.
# All config is derived from osConfig.myModules.desktop.displays (NixOS module).
{ config, pkgs, lib, osConfig, ... }:

let
  cfg = osConfig.myModules.desktop.displays;

  # Convert millihertz to kscreen-doctor refresh rate (rounded integer, e.g. 239757 → "240")
  # kscreen-doctor only accepts integer Hz and does fuzzy matching
  mhzToRefresh = mhz: toString ((mhz + 500) / 1000);

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
  # Disabled monitors that are NOT toggle-managed (toggle monitors are left as-is)
  disabledMonitors = builtins.filter (m: !m.enabled && !m.toggle.enable) sortedMonitors;

  # Monitors with tiling layouts
  tilingMonitors = builtins.filter (m: m.tiling.layout != null && m.uuid != null) sortedMonitors;

  # Monitors with toggle scripts
  toggleMonitors = builtins.filter (m: m.toggle.enable) sortedMonitors;

  # All connectors for a monitor (primary + alternates)
  allConnectors = m: [ m.connector ] ++ m.alternateConnectors;

  # All UUIDs for a monitor (primary + alternates)
  allUuids = m: (if m.uuid != null then [ m.uuid ] else []) ++ m.alternateUuids;

  # Generate kscreen-doctor commands for a single monitor
  monitorArrangeCmd = m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
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

  # Build toggle script for a monitor (supports multiple connectors)
  mkToggleScript = m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
      connectors = allConnectors m;
      connectorList = lib.concatStringsSep " " connectors;

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
      # Ensure Wayland session env is set (needed when invoked from StreamController/StreamDeck)
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-0}"
      export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
      export PATH="${lib.makeBinPath [ pkgs.kdePackages.qttools pkgs.jq ]}''${PATH:+:$PATH}"

      KWIN="org.kde.KWin"

      # Detect which connector the monitor is on
      outputs="$(kscreen-doctor --outputs 2>/dev/null)"
      output=""
      for conn in ${connectorList}; do
        if echo "$outputs" | grep -q "$conn"; then
          output="$conn"
          break
        fi
      done

      if [ -z "$output" ]; then
        echo "No monitor connected on any of: ${connectorList}"
        exit 0
      fi

      if echo "$outputs" | grep -A1 "$output" | grep -q "enabled"; then
        # ── DISABLING: migrate windows off this screen first ──
        # Get all window IDs on the screen being disabled via KWin scripting
        migrate_js="
          const out = '$output';
          const wins = workspace.stackingOrder.filter(w =>
            !w.minimized && !w.skipTaskbar && w.output?.name === out
          );
          // Move each window to the primary screen (priority 1)
          for (const w of wins) {
            w.output = workspace.screens.find(s => s.name !== out) ?? workspace.screens[0];
            w.tile = null; // Untile so Fluid Tile can re-place it
          }
          wins.length;
        "
        moved=$(qdbus $KWIN /Scripting org.kde.kwin.Scripting.loadScript /dev/stdin "" <<< "$migrate_js" 2>/dev/null || echo "")
        if [ -n "$moved" ]; then
          script_id="$moved"
          qdbus $KWIN "/$script_id" org.kde.kwin.Script.run 2>/dev/null || true
          qdbus $KWIN "/$script_id" org.kde.kwin.Script.stop 2>/dev/null || true
          sleep 0.3 # Let Fluid Tile settle before screen removal
        fi

        kscreen-doctor \
          "output.$output.disable" \
          ${repositionOff} \
          2>/dev/null
        echo "$output disabled (windows migrated)"
      else
        # ── ENABLING ──
        kscreen-doctor \
          "output.$output.enable" \
          "output.$output.mode.${modeStr}" \
          "output.$output.position.${toString m.position.x},${toString m.position.y}" \
          "output.$output.priority.${toString m.priority}" \
          ${repositionOn} \
          2>/dev/null
        echo "$output enabled"
      fi
      # Nudge KWin to re-read tiling config for the new screen layout
      sleep 0.3
      qdbus $KWIN /KWin reconfigure 2>/dev/null || true
    '';

  # Tiling activation script — writes layouts for ALL UUIDs (primary + alternates)
  tilingActivation = let
    kwc = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
    sed = "${pkgs.gnused}/bin/sed";

    # Write tile layout for each UUID of each monitor
    tileCommands = lib.concatMapStrings (m:
      lib.concatMapStrings (uuid: ''
        $KWC --file "$KWINRC" \
          --group Tiling --group Desktop_1 --group "${uuid}" \
          --key tiles '${m.tiling.layout}'
        $KWC --file "$KWINRC" \
          --group Tiling --group Desktop_1 --group "${uuid}" \
          --key padding ${toString m.tiling.padding}
      '') (allUuids m)
    ) tilingMonitors;

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

    # ── Write per-monitor tile layouts (all UUIDs) ──
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

  # No login service — KDE handles display layout at session start.
  # display-arrange is available as a manual command if needed.

  # Run display-arrange on wake from sleep/suspend (screens may need re-arrangement)
  systemd.user.services.display-arrange-wake = {
    Unit = {
      Description = "Enforce display arrangement after wake";
      After = [ "sleep.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "/run/current-system/sw/bin/sleep 3";
      ExecStart = "%h/.nix-profile/bin/display-arrange";
    };
    Install.WantedBy = [ "sleep.target" ];
  };
}
