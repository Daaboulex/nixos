# xrizer -- OpenVR-to-OpenXR translation layer: Steam OpenVR titles run on the
# system OpenXR runtime instead of SteamVR (which never supported the Rift CV1
# on Linux). Requires an active system OpenXR runtime. Per-game Steam launch
# options must expose the Monado IPC socket to pressure-vessel:
#   PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc %command%
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.xrizer;
in
{
  options.myModules.home.xrizer = {
    enable = lib.mkEnableOption "xrizer OpenVR-to-OpenXR layer for Steam VR titles";
  };
  config = lib.mkIf cfg.enable {
    # Steam resolves its OpenVR runtime from this file.
    xdg.configFile."openvr/openvrpaths.vrpath".text = builtins.toJSON {
      version = 1;
      runtime = [ "${pkgs.xrizer}/lib/xrizer" ];
    };
  };
}
