{ inputs, withSystem, ... }:
{
  flake.nixosModules.input-streamcontroller =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.input.streamcontroller;
      perSystem = withSystem pkgs.stdenv.hostPlatform.system ({ inputs', ... }: inputs');
      streamcontrollerPkg = perSystem.streamcontroller-nix.packages.streamcontroller;
    in
    {
      _class = "nixos";
      options.myModules.input.streamcontroller = {
        enable = lib.mkEnableOption "StreamController (Elgato Stream Deck)";
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          streamcontrollerPkg
          pkgs.kdotool
        ];
        services.udev.packages = [ streamcontrollerPkg ];
      };
    };
}
