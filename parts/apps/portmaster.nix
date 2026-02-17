{ inputs, ... }: {
  flake.nixosModules.apps-portmaster = { config, lib, ... }:
    let
      cfg = config.myModules.security.portmaster;
    in {
      # Thin wrapper: map myModules namespace → services.portmaster
      options.myModules.security.portmaster = {
        enable = lib.mkEnableOption "Portmaster privacy firewall";
        dataDir = lib.mkOption { type = lib.types.str; default = "/opt/safing/portmaster"; };
        ui.enable = lib.mkOption { type = lib.types.bool; default = false; };
        notifier.enable = lib.mkOption { type = lib.types.bool; default = false; };
      };

      config = lib.mkIf cfg.enable {
        services.portmaster = {
          enable = true;
          dataDir = cfg.dataDir;
          ui.enable = cfg.ui.enable;
          notifier.enable = cfg.notifier.enable;
        };
      };
    };
}
