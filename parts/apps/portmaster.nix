{ inputs, ... }: {
  flake.nixosModules.apps-portmaster = { config, lib, ... }:
    let
      cfg = config.myModules.security.portmaster;
    in {
      # Thin wrapper: map myModules namespace → services.portmaster (v2)
      options.myModules.security.portmaster = {
        enable = lib.mkEnableOption "Portmaster privacy firewall";
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
      };
    };
}
