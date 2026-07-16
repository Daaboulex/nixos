# portmaster — Portmaster privacy firewall with per-app network rules.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.security.portmaster;
    in
    {
      _class = "nixos";
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
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = ''
            Soft declarative settings — seeded into /var/lib/portmaster/config.json
            on first boot, then UI edits win. Use for preferences the user may want
            to tweak live (filter list selections, expertise level, notifications).
          '';
        };
        forceSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = ''
            Hard declarative overrides — applied on every preStart, UI edits are
            reverted. Use for settings that MUST stay a specific value or the
            system breaks (Mullvad-compat DNS flags, kill switch, resolver
            listening address).
          '';
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
          inherit (cfg) autostart;
          notifier.enable = cfg.notifier;
          inherit (cfg) settings;
          inherit (cfg) forceSettings;
          inherit (cfg) extraArgs;
        };
      };
    };
in
{
  flake.modules.nixos.security-portmaster = mod;

}
