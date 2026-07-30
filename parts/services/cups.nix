# cups — CUPS printing server with vendor drivers.
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
      cfg = config.myModules.services.cups;
    in
    {
      _class = "nixos";
      options.myModules.services.cups = {
        enable = lib.mkEnableOption "Printing support (CUPS)";
        browsing = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Run cups-browsed to auto-discover network printers.
            Set false on hosts with no printers to silence periodic
            Create-Printer-Subscriptions client-error-bad-request
            churn in cupsd logs (cups-browsed renews stale leases
            every few hours; with no targets the first Create probe
            carries a short-form payload cupsd rejects before the
            retry with full attrs succeeds).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.printing = {
          enable = true;
          inherit (cfg) browsing;
          defaultShared = false;
          drivers = [
            pkgs.gutenprint
            pkgs.gutenprintBin
          ];
        };
      };
    };
in
{
  flake.modules.nixos.services-cups = mod;
}
