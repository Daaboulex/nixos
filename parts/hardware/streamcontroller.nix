{ inputs, ... }: {
  flake.nixosModules.hardware-streamcontroller = { config, lib, pkgs, ... }: {
    options.myModules.hardware.streamcontroller = {
      enable = lib.mkEnableOption "StreamController (Elgato Stream Deck)";
    };

    config = lib.mkIf config.myModules.hardware.streamcontroller.enable (let
      streamcontrollerPatched = pkgs.streamcontroller.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ pkgs.python3Packages.websockets ];
        postPatch = (old.postPatch or "") + ''
          find . -name "*.py" -exec sed -i 's/DeviceManager.USB_VID_ELGATO/0x0fd9/g' {} +
        '';
      });
    in {
      environment.systemPackages = [ streamcontrollerPatched pkgs.kdotool ];
      services.udev.packages = [ streamcontrollerPatched ];
    });
  };
}
