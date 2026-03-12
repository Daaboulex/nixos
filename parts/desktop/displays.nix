{ inputs, ... }:
{
  flake.nixosModules.desktop-displays =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.desktop.displays;

      monitorOpts =
        { name, ... }:
        {
          options = {
            connector = lib.mkOption {
              type = lib.types.str;
              description = "KMS connector name (e.g. DP-1, HDMI-A-1)";
            };

            alternateConnectors = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Alternate connector names (e.g. same CRT on motherboard HDMI vs GPU HDMI)";
            };

            mode = {
              width = lib.mkOption {
                type = lib.types.int;
                description = "Horizontal resolution";
              };
              height = lib.mkOption {
                type = lib.types.int;
                description = "Vertical resolution";
              };
              refreshRate = lib.mkOption {
                type = lib.types.int;
                description = "Refresh rate in millihertz (e.g. 239757 = ~240Hz)";
              };
            };

            position = {
              x = lib.mkOption {
                type = lib.types.int;
                default = 0;
                description = "X position in default layout";
              };
              y = lib.mkOption {
                type = lib.types.int;
                default = 0;
                description = "Y position in default layout";
              };
            };

            priority = lib.mkOption {
              type = lib.types.int;
              default = 1;
              description = "Output priority (1 = primary)";
            };

            rotation = lib.mkOption {
              type = lib.types.enum [
                "normal"
                "right"
                "left"
                "inverted"
              ];
              default = "normal";
              description = "Display rotation";
            };

            scale = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Output scale factor";
            };

            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the monitor is enabled by default";
            };

            vrr = lib.mkOption {
              type = lib.types.enum [
                "automatic"
                "always"
                "never"
              ];
              default = "automatic";
              description = "Variable refresh rate policy";
            };

            # SDDM / KWin identity (only monitors with these appear in SDDM config)
            edidHash = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "EDID hash for KWin output identification";
            };

            edidIdentifier = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "EDID identifier string for KWin";
            };

            uuid = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "KWin output UUID (also used for tiling config)";
            };

            alternateUuids = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Alternate UUIDs for the same monitor on different connectors";
            };

            # Tiling
            tiling = {
              layout = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "JSON tile layout for KWin";
              };
              padding = lib.mkOption {
                type = lib.types.int;
                default = 0;
                description = "Tile padding in pixels";
              };
            };

            # Toggle
            toggle = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Generate a toggle script for this monitor";
              };
              scriptName = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Name of the toggle script";
              };
              repositions = lib.mkOption {
                type = lib.types.lazyAttrsOf (
                  lib.types.submodule {
                    options = {
                      x = lib.mkOption { type = lib.types.int; };
                      y = lib.mkOption { type = lib.types.int; };
                    };
                  }
                );
                default = { };
                description = "Repositions for other monitors when this one is toggled on";
              };
            };
          };
        };

      # Monitors that have full EDID identity (included in SDDM config)
      sddmMonitors = lib.filterAttrs (_: m: m.edidHash != null && m.uuid != null) cfg.monitors;

      # Rotation → KWin transform string
      rotationToTransform =
        r:
        {
          normal = "Normal";
          right = "Rotated270";
          left = "Rotated90";
          inverted = "Rotated180";
        }
        .${r};

      # VRR → KWin policy string
      vrrToPolicy =
        v:
        {
          automatic = "Automatic";
          always = "Always";
          never = "Never";
        }
        .${v};

      # Build the kwinoutputconfig.json from monitor definitions
      sddmMonitorList = lib.attrValues sddmMonitors;
      sortedSddmMonitors = lib.sort (a: b: a.priority < b.priority) sddmMonitorList;

      outputsData = lib.imap0 (_i: m: {
        connectorName = m.connector;
        inherit (m) edidHash;
        inherit (m) edidIdentifier;
        mode = {
          inherit (m.mode) width;
          inherit (m.mode) height;
          inherit (m.mode) refreshRate;
        };
        inherit (m) scale;
        transform = rotationToTransform m.rotation;
        inherit (m) uuid;
        vrrPolicy = vrrToPolicy m.vrr;
      }) sortedSddmMonitors;

      setupsData = lib.imap0 (i: m: {
        inherit (m) enabled;
        outputIndex = i;
        position = { inherit (m.position) x y; };
        inherit (m) priority;
        replicationSource = "";
      }) sortedSddmMonitors;

      kwinOutputConfig = builtins.toJSON [
        {
          name = "outputs";
          data = outputsData;
        }
        {
          name = "setups";
          data = [
            {
              lidClosed = false;
              outputs = setupsData;
            }
          ];
        }
      ];

      # Monitors that need kernel rotation params
      rotatedMonitors = lib.filterAttrs (_: m: m.rotation != "normal") cfg.monitors;
    in
    {
      _class = "nixos";
      options.myModules.desktop.displays = {
        enable = lib.mkEnableOption "declarative display configuration";

        phantomUuids = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Stale monitor UUIDs to purge from tiling config";
        };

        monitors = lib.mkOption {
          type = lib.types.lazyAttrsOf (lib.types.submodule monitorOpts);
          default = { };
          description = "Monitor definitions";
        };
      };

      config = lib.mkIf cfg.enable {
        # Kernel video= params for rotated monitors
        boot.kernelParams = lib.mapAttrsToList (
          _: m: "video=${m.connector}:panel_orientation=right_side_up"
        ) rotatedMonitors;

        # SDDM display layout — written via tmpfiles.d (avoids activation read-only FS issues)
        systemd.tmpfiles.rules = lib.mkIf (sddmMonitors != { }) [
          "d /var/lib/sddm/.config 0700 sddm sddm -"
        ];

        environment.etc."sddm-kwinoutputconfig.json" = lib.mkIf (sddmMonitors != { }) {
          text = kwinOutputConfig;
          mode = "0644";
        };

        system.activationScripts.sddm-display-config = lib.mkIf (sddmMonitors != { }) {
          text = ''
            if [ -d /var/lib/sddm/.config ]; then
              rm -f /var/lib/sddm/.config/kwinoutputconfig.json
              cp /etc/sddm-kwinoutputconfig.json /var/lib/sddm/.config/kwinoutputconfig.json
              chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json
              chmod 0600 /var/lib/sddm/.config/kwinoutputconfig.json
            fi
          '';
          deps = [ "etc" ];
        };
      };
    };
}
