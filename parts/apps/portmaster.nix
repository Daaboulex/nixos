{ inputs, ... }: {
  flake.nixosModules.apps-portmaster = { config, lib, ... }:
    let
      cfg = config.myModules.security.portmaster;
    in {
      # Thin wrapper: map myModules namespace → services.portmaster (v2)
      options.myModules.security.portmaster = {
        enable = lib.mkEnableOption "Portmaster privacy firewall";
        notifier = lib.mkEnableOption "Portmaster system tray notifier (autostart)";
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

        # XDG autostart for the Portmaster notifier (system tray icon)
        # Uses portmaster-start notifier — lightweight tray-only, no full UI window.
        # Delay ensures KDE Plasma's system tray is ready to accept the icon.
        environment.etc."xdg/autostart/portmaster-notifier.desktop" = lib.mkIf cfg.notifier {
          text = ''
            [Desktop Entry]
            Name=Portmaster Notifier
            Comment=Portmaster system tray notifier
            Exec=/bin/sh -c 'sleep 3; /opt/safing/portmaster/portmaster-start notifier'
            Type=Application
            X-KDE-autostart-phase=2
            X-KDE-StartupNotify=false
            NoDisplay=true
          '';
        };
      };
    };
}
