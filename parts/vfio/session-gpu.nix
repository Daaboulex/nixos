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
          trigger an SDDM infinite-login loop. Prefer the stable ':'-free PCI aliases from
          myModules.desktop.displays.gpuAliases (/dev/dri/by-gpu/<name>) over /dev/dri/cardN
          — cardN renumbers when a GPU is captured by vfio-pci.
        '';
      };

      config = lib.mkIf (cfg.enable && cfg.sessionGpuDevices != null) {
        assertions = [
          {
            assertion = !(lib.any (p: lib.hasInfix ":" p) cfg.sessionGpuDevices);
            message = "myModules.vfio.sessionGpuDevices must not contain ':' — KWIN_DRM_DEVICES splits on ':'. Use /dev/dri/cardN, not /dev/dri/by-path/pci-…";
          }
          (
            # Every /dev/dri/by-gpu/<name> path must name a declared alias. A typo there
            # resolves to a nonexistent DRM node -> KWin finds no device and SDDM enters a
            # login loop. attrByPath fails closed to {} when displays is absent, so an
            # unknown alias is still caught. Non-by-gpu paths (cardN) are not checked.
            let
              gpuAliases = lib.attrByPath [ "myModules" "desktop" "displays" "gpuAliases" ] { } config;
              unknownAliasDevices = lib.filter (
                p:
                lib.hasPrefix "/dev/dri/by-gpu/" p
                && !(builtins.hasAttr (lib.removePrefix "/dev/dri/by-gpu/" p) gpuAliases)
              ) cfg.sessionGpuDevices;
            in
            {
              assertion = unknownAliasDevices == [ ];
              message =
                "myModules.vfio.sessionGpuDevices references /dev/dri/by-gpu aliases not declared in "
                + "myModules.desktop.displays.gpuAliases: ${lib.concatStringsSep ", " unknownAliasDevices}. "
                + "A typo yields a nonexistent DRM node -> KWin finds no device and SDDM enters a login loop.";
            }
          )
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
