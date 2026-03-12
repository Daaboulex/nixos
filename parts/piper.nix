{ inputs, ... }:
{
  flake.nixosModules.piper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.piper;
    in
    {
      _class = "nixos";
      options.myModules.piper.enable = lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";

      config = lib.mkIf cfg.enable {
        services.ratbagd.enable = true;
        environment.systemPackages = [ pkgs.piper ];
      };
    };
}
