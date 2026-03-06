{ inputs, ... }: {
  flake.nixosModules.apps-portmaster = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.security.portmaster;
      portmasterPkg = config.services.portmaster.package;
    in {
      # Thin wrapper: map myModules namespace → services.portmaster
      options.myModules.security.portmaster = {
        enable = lib.mkEnableOption "Portmaster privacy firewall";
        notifier = lib.mkEnableOption "Portmaster system tray notifier (autostart)";
        autostart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether portmaster.service starts automatically on boot. When false, the service is installed but must be started manually with `sudo systemctl start portmaster`.";
        };
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Portmaster settings passed to portmaster-core";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra command-line arguments for portmaster-core";
        };
      };

      config = lib.mkIf cfg.enable {
        services.portmaster = {
          enable = true;
          settings = cfg.settings;
          extraArgs = cfg.extraArgs;
        };

        # When autostart is false, remove portmaster from multi-user.target
        # so it doesn't start on boot. The service is still installed and
        # can be started manually: sudo systemctl start portmaster
        systemd.services.portmaster.wantedBy = lib.mkIf (!cfg.autostart) (lib.mkForce [ ]);

        # XDG autostart for the Portmaster desktop app (system tray icon)
        # Uses the Nix-packaged Tauri app — no hardcoded /opt paths.
        # Checks that portmaster.service is active before launching — prevents
        # "Could not connect to localhost" popup when the service is stopped.
        # TODO: Move this to portmaster-nix upstream module.nix as services.portmaster.notifier
        environment.etc."xdg/autostart/portmaster-notifier.desktop" = lib.mkIf cfg.notifier {
          text = ''
            [Desktop Entry]
            Name=Portmaster Notifier
            Comment=Portmaster system tray notifier
            Exec=/bin/sh -c 'sleep 3; systemctl is-active --quiet portmaster.service && exec ${portmasterPkg}/bin/portmaster --data /var/lib/portmaster'
            Type=Application
            X-KDE-autostart-phase=2
            X-KDE-StartupNotify=false
            NoDisplay=true
          '';
        };
      };
    };
}
