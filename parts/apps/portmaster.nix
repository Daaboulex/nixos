{ inputs, ... }: {
  flake.nixosModules.apps-portmaster = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.security.portmaster;
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
          autostart = cfg.autostart;
          notifier.enable = cfg.notifier;
          settings = cfg.settings;
          extraArgs = cfg.extraArgs;
        };
      };
    };
}
