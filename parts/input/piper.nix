{ inputs, ... }:
{
  flake.nixosModules.input-piper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.input.piper;
    in
    {
      _class = "nixos";
      options.myModules.input.piper.enable =
        lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";

      config = lib.mkIf cfg.enable {
        services.ratbagd.enable = true;
        environment.systemPackages = [ pkgs.piper ];
      };
    };
}
