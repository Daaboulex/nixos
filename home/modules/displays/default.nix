# displays — display arrangement, toggle scripts, tiling activation, and systemd services.
# All config is derived from osConfig.myModules.desktop.displays (NixOS module).
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:

let
  cfg = config.myModules.home.displays;
  hasDisplays =
    osConfig ? myModules && osConfig.myModules ? desktop && osConfig.myModules.desktop ? displays;
  displaysCfg = if hasDisplays then osConfig.myModules.desktop.displays else { enable = false; };

  # Guard: all monitor-derived values are only evaluated when displays are enabled.
  # The let bindings must not access displaysCfg.monitors when enable = false.
  hasMonitors = displaysCfg.enable && displaysCfg.monitors != { };

  # Convert millihertz to kscreen-doctor refresh rate (rounded integer, e.g. 239757 → "240")
  # kscreen-doctor only accepts integer Hz and does fuzzy matching
  mhzToRefresh = mhz: toString ((mhz + 500) / 1000);

  # Rotation → kscreen-doctor rotation argument
  rotationToKscreen =
    r:
    {
      normal = "none";
      right = "right";
      left = "left";
      inverted = "inverted";
    }
    .${r};

  # All monitors sorted by priority (safe: only evaluated when hasMonitors is true via mkIf)
  sortedMonitors =
    if hasMonitors then
      lib.sort (a: b: a.priority < b.priority) (lib.attrValues displaysCfg.monitors)
    else
      [ ];

  # Enabled monitors (for display-arrange)
  enabledMonitors = builtins.filter (m: m.enabled) sortedMonitors;
  # Disabled monitors that are NOT toggle-managed (toggle monitors are left as-is)
  disabledMonitors = builtins.filter (m: !m.enabled && !m.toggle.enable) sortedMonitors;

  # Monitors with tiling layouts
  tilingMonitors = builtins.filter (m: m.tiling.layout != null && m.uuid != null) sortedMonitors;

  # Monitors with toggle scripts
  toggleMonitors = builtins.filter (m: m.toggle.enable) sortedMonitors;

  # Monitors whose panel power state is watched over DDC/CI
  watchMonitors = builtins.filter (m: m.toggle.powerWatch) sortedMonitors;

  # All connectors for a monitor (primary + alternates)
  allConnectors = m: [ m.connector ] ++ m.alternateConnectors;

  # All UUIDs for a monitor (primary + alternates)
  allUuids = m: (if m.uuid != null then [ m.uuid ] else [ ]) ++ m.alternateUuids;

  # Generate kscreen-doctor commands for a single monitor. The connector is
  # resolved from the monitor's EDID hash at apply time, because a connector
  # name changes when the cable moves port while the EDID does not. A monitor
  # that is absent (unplugged, or powered off on a driver that follows DP
  # hotplug) is skipped; one that is present but rejects the layout is an error.
  monitorArrangeCmd =
    m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
      hashArg = lib.optionalString (m.edidHash != null) m.edidHash;
      rotationArg = lib.optionalString (
        m.rotation != "normal"
      ) ''"output.$conn.rotation.${rotationToKscreen m.rotation}" '';
    in
    ''
      conn=$(resolve_connector ${lib.escapeShellArg hashArg} ${lib.escapeShellArg m.connector})
      if [ -z "$conn" ]; then
        echo "display-arrange: ${m.connector} not present, skipped" >&2
      else
        kscreen-doctor "output.$conn.enable" "output.$conn.mode.${modeStr}" ${rotationArg}"output.$conn.position.${toString m.position.x},${toString m.position.y}" "output.$conn.priority.${toString m.priority}" \
          || echo "display-arrange: ${m.connector} present as $conn but kscreen-doctor rejected the layout" >&2
      fi
    '';

  monitorDisableCmd = m: ''
    conn=$(resolve_connector ${
      lib.escapeShellArg (lib.optionalString (m.edidHash != null) m.edidHash)
    } ${lib.escapeShellArg m.connector})
    [ -n "$conn" ] && { kscreen-doctor "output.$conn.disable" || echo "display-arrange: could not disable $conn" >&2; }
  '';

  # md5 of a zero-length file: a connector with no monitor attached reads empty
  # rather than absent, so it must not be mistaken for a match.
  emptyEdidHash = "d41d8cd98f00b204e9800998ecf8427e";

  resolveConnectorFn = ''
    resolve_connector() {
      _want_hash="$1"
      _declared="$2"
      if [ -n "$_want_hash" ]; then
        for _d in /sys/class/drm/card*-*; do
          [ -e "$_d/edid" ] || continue
          _h=$(md5sum < "$_d/edid" 2>/dev/null | cut -d' ' -f1)
          [ "$_h" = "${emptyEdidHash}" ] && continue
          if [ "$_h" = "$_want_hash" ]; then
            _n=''${_d##*/}
            printf '%s' "''${_n#card*-}"
            return 0
          fi
        done
      fi
      for _d in /sys/class/drm/card*-"$_declared"; do
        [ "$(cat "$_d/status" 2>/dev/null)" = connected ] && { printf '%s' "$_declared"; return 0; }
      done
      return 1
    }
  '';

  # Build display-arrange script
  displayArrangeScript = pkgs.writeShellScriptBin "display-arrange" (
    ''
      export PATH="${
        lib.makeBinPath [
          pkgs.kdePackages.libkscreen
          pkgs.coreutils
        ]
      }''${PATH:+:$PATH}"
    ''
    + resolveConnectorFn
    + lib.concatMapStrings monitorArrangeCmd enabledMonitors
    + lib.concatMapStrings monitorDisableCmd disabledMonitors
  );

  # Build toggle script for a monitor (supports multiple connectors)
  mkToggleScript =
    m:
    let
      refreshStr = mhzToRefresh m.mode.refreshRate;
      modeStr = "${toString m.mode.width}x${toString m.mode.height}@${refreshStr}";
      connectors = allConnectors m;
      connectorList = lib.concatStringsSep " " connectors;

      # Reposition commands when toggling ON
      repositionOn = lib.concatStringsSep " " (
        lib.mapAttrsToList (
          conn: pos: "\"output.${conn}.position.${toString pos.x},${toString pos.y}\""
        ) m.toggle.repositions
      );
      # Default positions (from monitor definitions) when toggling OFF
      repositionOff = lib.concatStringsSep " " (
        map (
          om: "\"output.${om.connector}.position.${toString om.position.x},${toString om.position.y}\""
        ) (builtins.filter (om: builtins.hasAttr om.connector m.toggle.repositions) sortedMonitors)
      );
      rotationArg = lib.optionalString (
        m.rotation != "normal"
      ) ''"output.$output.rotation.${rotationToKscreen m.rotation}" '';
    in
    pkgs.writeShellScriptBin m.toggle.scriptName ''
      # Ensure Wayland session env is set (needed when invoked from StreamController/StreamDeck)
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-0}"
      export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
      export PATH="${
        lib.makeBinPath [
          pkgs.kdePackages.qttools
          pkgs.kdePackages.libkscreen
          pkgs.gnugrep
          pkgs.gnused
          pkgs.coreutils
        ]
      }''${PATH:+:$PATH}"

      want="''${1:-toggle}"
      case "$want" in
      on | off | toggle) ;;
      *)
        echo "usage: ${m.toggle.scriptName} [on|off|toggle]" >&2
        exit 2
        ;;
      esac

      KWIN="org.kde.KWin"

      # kscreen-doctor colorizes even without a tty; the escape's trailing 'm'
      # touches "enabled" and defeats word matching, so strip ANSI first.
      outputs="$(kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
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

      state=off
      if echo "$outputs" | grep -A1 "$output" | grep -qw "enabled"; then
        state=on
      fi
      if [ "$want" = toggle ]; then
        if [ "$state" = on ]; then want=off; else want=on; fi
      fi
      if [ "$want" = "$state" ]; then
        echo "$output already $state"
        exit 0
      fi

      if [ "$want" = off ]; then
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
          sleep 0.5 # Let Fluid Tile settle before screen removal
        fi

        kscreen-doctor "output.$output.disable" ${repositionOff} 2>/dev/null
        echo "$output disabled (windows migrated)"
      else
        # ── ENABLING ──
        kscreen-doctor "output.$output.enable" "output.$output.mode.${modeStr}" ${rotationArg}"output.$output.position.${toString m.position.x},${toString m.position.y}" "output.$output.priority.${toString m.priority}" ${repositionOn} 2>/dev/null
        echo "$output enabled"
      fi
      # Wait for KWin to process screen topology change, then re-read tiling config
      # 1s covers: kscreen-doctor → KWin output rebuild → Fluid Tile screen detection
      sleep 1
      qdbus $KWIN /KWin reconfigure 2>/dev/null || true
    '';

  # MCCS VCP D6: x01 on, x02-x04 DPMS sleep (panel still powered), x05 off at the power switch
  powerWatchScript = pkgs.writeShellScriptBin "display-power-watch" (
    ''
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-0}"
      export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
      export PATH="${
        lib.makeBinPath [
          pkgs.ddcutil
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
        ]
      }''${PATH:+:$PATH}"

      markdir="$XDG_RUNTIME_DIR/display-power-watch"
      mkdir -p "$markdir"

      resolve_bus() {
        ddcutil --syslog NEVER detect --brief 2>/dev/null | awk -v conns="$1" '
          /^Display / { bus = "" }
          /I2C bus:/ { bus = $NF; sub(".*i2c-", "", bus) }
          /DRM connector:/ {
            n = split(conns, a, " ")
            for (i = 1; i <= n; i++) if ($NF ~ ("-" a[i] "$")) { print bus; exit }
          }'
      }

    ''
    + lib.concatMapStrings (
      m:
      let
        sn = m.toggle.scriptName;
        fn = lib.replaceStrings [ "-" ] [ "_" ] sn;
        conns = lib.concatStringsSep " " (allConnectors m);
        toggleBin = "${mkToggleScript m}/bin/${sn}";
      in
      ''
        watch_${fn}() {
          busfile="$markdir/${sn}.bus"
          countfile="$markdir/${sn}.offcount"
          marker="$markdir/${sn}.off"
          bus=$(cat "$busfile" 2>/dev/null || true)
          if [ -z "$bus" ]; then
            bus=$(resolve_bus "${conns}")
            [ -n "$bus" ] || return 0
            printf '%s' "$bus" >"$busfile"
          fi
          if ! power=$(timeout 15 ddcutil --syslog NEVER getvcp d6 --bus "$bus" --brief 2>/dev/null); then
            rm -f "$busfile" "$countfile"
            return 0
          fi
          case "$power" in
          *x05)
            count=$(($(cat "$countfile" 2>/dev/null || echo 0) + 1))
            printf '%s' "$count" >"$countfile"
            if [ "$count" -eq 2 ] && [ ! -e "$marker" ]; then
              result=$(timeout 30 ${toggleBin} off 2>&1 || true)
              echo "power-watch ${sn}: panel powered off; $result"
              case "$result" in *disabled*) touch "$marker" ;; esac
            fi
            ;;
          *)
            rm -f "$countfile"
            if [ -e "$marker" ]; then
              result=$(timeout 30 ${toggleBin} on 2>&1 || true)
              echo "power-watch ${sn}: panel powered on; $result"
              rm -f "$marker"
            fi
            ;;
          esac
        }
      ''
    ) watchMonitors
    + ''
      while :; do
    ''
    + lib.concatMapStrings (
      m: "  watch_${lib.replaceStrings [ "-" ] [ "_" ] m.toggle.scriptName}\n"
    ) watchMonitors
    + ''
        sleep 5
      done
    ''
  );

  # Tiling activation script — writes layouts for ALL UUIDs (primary + alternates)
  tilingActivation =
    let
      kwc = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
      sed = "${pkgs.gnused}/bin/sed";

      # Write tile layout for each UUID of each monitor
      tileCommands = lib.concatMapStrings (
        m:
        lib.concatMapStrings (uuid: ''
          run $KWC --file "$KWINRC" \
            --group Tiling --group Desktop_1 --group "${uuid}" \
            --key tiles '${m.tiling.layout}'
          run $KWC --file "$KWINRC" \
            --group Tiling --group Desktop_1 --group "${uuid}" \
            --key padding ${toString m.tiling.padding}
        '') (allUuids m)
      ) tilingMonitors;

      # Purge phantom UUIDs
      phantomPurge = lib.concatMapStrings (uuid: ''
        run $SED -i '/${uuid}/,/^$/d' "$KWINRC" 2>/dev/null || true
      '') (if displaysCfg.enable then displaysCfg.phantomUuids else [ ]);
    in
    ''
      KWINRC="$HOME/.config/kwinrc"
      KWC="${kwc}"
      SED="${sed}"

      # ── Purge ALL stale Tiling entries (plasma-manager ][  escaping bug) ──
      run $SED -i '/Tiling.*\\\\x5d\\\\x5b/,/^$/d' "$KWINRC" 2>/dev/null || true
      run $SED -i '/Tiling.*x5d.*x5b/,/^$/d' "$KWINRC" 2>/dev/null || true
      run $SED -i '/^\[Tiling\]\[[^D]/,/^$/d' "$KWINRC" 2>/dev/null || true
      run $SED -i '/^\[Tiling\]\[Desktop_1\]\[\]$/,/^$/d' "$KWINRC" 2>/dev/null || true

      # ── Write per-monitor tile layouts (all UUIDs) ──
      ${tileCommands}
      # ── Purge phantom UUIDs ──
      ${phantomPurge}
    '';

in
{
  options.myModules.home.displays = {
    enable = lib.mkEnableOption "display arrangement, toggle scripts, and tiling activation";
  };

  config = lib.mkIf (cfg.enable && displaysCfg.enable && displaysCfg.monitors != { }) {

    assertions = [
      {
        assertion = lib.all (m: m.toggle.enable) watchMonitors;
        message = "myModules.home.displays: toggle.powerWatch requires toggle.enable on the same monitor (the watch drives its toggle script)";
      }
    ];

    # Packages: display-arrange + toggle scripts
    home.packages = [ displayArrangeScript ] ++ map mkToggleScript toggleMonitors;

    # Tiling activation (runs on Home Manager switch)
    home.activation.configureTiling = lib.hm.dag.entryAfter [ "writeBoundary" ] tilingActivation;

    # No login service — KDE handles display layout at session start.
    # display-arrange is available as a manual command if needed.

    systemd.user.services = {
      # Run display-arrange on wake from sleep/suspend (screens may need re-arrangement)
      display-arrange-wake = {
        Unit = {
          Description = "Enforce display arrangement after wake";
          After = [ "sleep.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStartPre = "/run/current-system/sw/bin/sleep 3";
          # Pin the immutable store path, not %h/.nix-profile (the mutable user
          # profile symlink): a user service must not depend on the profile being
          # maintained + on PATH, and use-xdg-base-directories stops updating it.
          ExecStart = "${displayArrangeScript}/bin/display-arrange";
        };
        Install.WantedBy = [ "sleep.target" ];
      };
    }
    // lib.optionalAttrs (watchMonitors != [ ]) {
      display-power-watch = {
        Unit = {
          Description = "Disable and restore outputs from the panel's DDC/CI power state";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${powerWatchScript}/bin/display-power-watch";
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
