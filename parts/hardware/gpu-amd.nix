# gpu-amd — AMD Graphics (amdgpu) with Mesa/Vulkan and ROCm compute.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.gpuAmd;
    in
    {
      _class = "nixos";
      options.myModules.hardware.gpuAmd = {
        enable = lib.mkEnableOption "AMD Graphics configuration";

        vulkanDeviceId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "1002:7550";
          description = "Vulkan device vendor:device ID for MESA_VK_DEVICE_SELECT (forces discrete GPU on dual-AMD systems)";
        };

        vulkanDeviceName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "AMD Radeon RX 9070 XT";
          description = "Vulkan device name substring for DXVK_FILTER_DEVICE_NAME and VKD3D_FILTER_DEVICE_NAME (forces dGPU for translated DX9-12 games)";
        };

        lact = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "LACT daemon for AMD GPU control/overclocking";
          };
        };

        initrd = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.myModules.boot.boot.plymouth.enable or false;
            description = "Load amdgpu in initrd (required for Plymouth)";
          };
        };

        enablePPFeatureMask = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "AMD GPU power management features with overdrive (ppfeaturemask=0xffff7fff — kernel default + overdrive, GFXOFF excluded)";
        };

        rdna4Fixes = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply RDNA 4 (GFX12) stability kernel params: disable scatter-gather display and GFX OFF";
        };

        drmDebug = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "DRM debug logging (drm.debug=0x1e) for diagnosing display black screens";
        };

        disableHDCP = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Disable HDCP (amdgpu.dc_hdcp_enable=0) — fixes handshake bugs on RDNA 4";
        };

        openCL = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "OpenCL support via RustiCL (Mesa) radeonsi driver";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.initrd.kernelModules = lib.mkIf cfg.initrd.enable [ "amdgpu" ];
        boot.kernelModules = [ "amdgpu" ];

        boot.kernelParams =
          lib.optionals cfg.enablePPFeatureMask [
            "amdgpu.ppfeaturemask=0xffff7fff"
          ]
          ++ lib.optionals cfg.rdna4Fixes [
            # Disable scatter-gather display — known to cause corruption/crashes on RDNA 4
            "amdgpu.sg_display=0"
            # Disable GFX OFF power state — prevents MES INVALIDATE_TLBS timeouts on RDNA 3/4
            "amdgpu.gfxoff=0"
          ]
          ++ lib.optionals cfg.disableHDCP [
            "amdgpu.dc_hdcp_enable=0"
          ]
          ++ lib.optionals cfg.drmDebug [
            # DRM subsystem debug logging — captures display engine events for black screen diagnosis
            "drm.debug=0x1e"
          ];

        services.xserver.videoDrivers = [ "amdgpu" ];

        # lact GUI moved to HM module home/modules/lact/

        systemd.services.lactd = lib.mkIf cfg.lact.enable {
          description = "AMDGPU Control Daemon";
          after = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.lact}/bin/lact daemon";
            Restart = "always";
            RestartSec = 5;
          };
        };

        # Contribute radeonsi to the shared RustiCL driver list in graphics.nix
        myModules.hardware.graphics.openCL.rusticlDrivers = lib.mkIf cfg.openCL [ "radeonsi" ];

        # Force Vulkan device selection on dual-AMD systems (iGPU + dGPU)
        # MESA_VK_DEVICE_SELECT is system-level (affects all Vulkan apps)
        # DXVK/VKD3D filters are user-level (Wine/Proton only) — moved to HM radv module
        environment.sessionVariables = lib.optionalAttrs (cfg.vulkanDeviceId != null) {
          MESA_VK_DEVICE_SELECT = cfg.vulkanDeviceId;
        };

        hardware.enableRedistributableFirmware = true;
      };
    };
in
{
  flake.modules.nixos.hardware-gpu-amd = mod;

}
