{ inputs, ... }:
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

      streamcontrollerPatched = pkgs.streamcontroller.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pkgs.python3Packages.websockets ];
        postPatch = (old.postPatch or "") + ''
          find . -name "*.py" -exec sed -i 's/DeviceManager.USB_VID_ELGATO/0x0fd9/g' {} +
        '';
      });
    in
    {
      _class = "nixos";
      options.myModules.input.streamcontroller = {
        enable = lib.mkEnableOption "StreamController (Elgato Stream Deck)";
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          streamcontrollerPatched
          pkgs.kdotool
        ];
        services.udev.packages = [ streamcontrollerPatched ];
      };
    };
}
