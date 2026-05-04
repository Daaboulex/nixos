# session-gpu — KWIN_DRM_DEVICES primary-render GPU selection for safe passthrough.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.vfio;
    in
    {
      _class = "nixos";

      options.myModules.vfio.sessionGpuDevices = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = [
          "/dev/dri/card0"
          "/dev/dri/card1"
        ];
        description = ''
          DRM device paths for KWIN_DRM_DEVICES. First device is primary render GPU —
          set iGPU first for safe GPU passthrough. null = KWin auto-detects (unsafe).

          WARNING: KWIN_DRM_DEVICES uses ':' as separator. Do NOT use /dev/dri/by-path/
          paths — they contain ':' in the PCI address and will be split into garbage,
          causing KWin to fail with "No suitable DRM devices have been found" and
          trigger an SDDM infinite-login loop. Use /dev/dri/cardN instead.
        '';
      };

      config = lib.mkIf (cfg.enable && cfg.sessionGpuDevices != null) {
        assertions = [
          {
            assertion = !(lib.any (p: lib.hasInfix ":" p) cfg.sessionGpuDevices);
            message = "myModules.vfio.sessionGpuDevices must not contain ':' — KWIN_DRM_DEVICES splits on ':'. Use /dev/dri/cardN, not /dev/dri/by-path/pci-…";
          }
        ];
        # Set KWIN_DRM_DEVICES so KWin uses iGPU as primary render device.
        # The first device in the list becomes the primary — when the dGPU
        # is removed for passthrough, KWin loses those outputs but keeps
        # rendering on the iGPU. Without this, KWin crashes on GPU removal.
        environment.variables.KWIN_DRM_DEVICES = lib.concatStringsSep ":" cfg.sessionGpuDevices;
      };
    };
in
{
  flake.modules.nixos.vfio-session-gpu = mod;

}
