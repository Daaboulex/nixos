# fstrim — periodic SSD TRIM timer for flash longevity.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.storage.fstrim;
    in
    {
      _class = "nixos";
      options.myModules.storage.fstrim = {
        enable = lib.mkEnableOption "Periodic SSD TRIM";

        interval = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "How often to run fstrim";
        };
      };

      config = lib.mkIf cfg.enable {
        services.fstrim = {
          enable = true;
          inherit (cfg) interval;
        };
      };
    };
in
{
  flake.modules.nixos.storage-fstrim = mod;

}
