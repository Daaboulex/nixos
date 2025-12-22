{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.myModules.hardware.streamcontroller;
in
{
  options.myModules.hardware.streamcontroller = {
    enable = mkEnableOption "StreamController (Basic Install)";
  };

  config = mkIf cfg.enable (let
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
}
