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

        passthrough = {
          enable = lib.mkEnableOption ''
            handing an AMD dGPU to a guest. Unlike Nvidia, amdgpu is NOT
            blacklisted by default: a Ryzen/APU iGPU shares the same driver,
            so the passed dGPU is taken by per-device vfio-pci capture
            (vfio-pci.ids / libvirtManaged) instead, while amdgpu keeps
            driving the iGPU. This flag drops host GPU tooling (LACT) for the
            passed card and is asserted by boot.moduleGuards. Set
            blacklistAmdgpu for APU-less hosts
          '';
          blacklistAmdgpu = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Also blacklist amdgpu entirely (and skip loading it). ONLY for
              APU-less AMD hosts with no host display on amdgpu — on a host whose
              iGPU/APU uses amdgpu this would kill the host's own graphics. Leave
              false and rely on per-device vfio-pci capture.
            '';
          };
        };

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
          configFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            example = lib.literalExpression "./lact-config.yaml";
            description = ''
              Declarative source for /etc/lact/config.yaml (LACT's source of truth:
              power cap, voltage offset, performance level, fan curve). null = LACT
              manages its own config (GUI-writable). When set, Nix owns the file as a
              read-only /etc symlink: the daemon reads + applies it; GUI edits will not
              persist (edit the file instead). Held verbatim rather than generated from
              a Nix attrset because LACT's parser is strict about the fan-curve integer
              keys and float formatting.
            '';
          };
        };

        initrd = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.myModules.boot.loader.plymouth.enable or false;
            description = "Load amdgpu in initrd (required for Plymouth)";
          };
        };

        enablePPFeatureMask = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "AMD GPU PowerPlay mask 0xfff77fff: OverDrive (0x4000) ON so LACT can undervolt/power-cap, GFXOFF (0x8000) OFF for RDNA stability, no overreach bits (kernel default is 0xfff7bfff)";
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
        # amdgpu is fully removed only on an APU-less host that hands its sole
        # AMD card to a guest; otherwise it always loads (the iGPU needs it) and
        # the passed dGPU is captured per-device by vfio-pci. Gating the load
        # keeps it out of the load set when blacklisted (boot.moduleGuards would
        # otherwise flag a load+blacklist conflict).
        boot.blacklistedKernelModules =
          lib.mkIf (cfg.passthrough.enable && cfg.passthrough.blacklistAmdgpu)
            [
              "amdgpu"
            ];
        boot.initrd.kernelModules = lib.mkIf (
          cfg.initrd.enable && !(cfg.passthrough.enable && cfg.passthrough.blacklistAmdgpu)
        ) [ "amdgpu" ];
        boot.kernelModules = lib.mkIf (!(cfg.passthrough.enable && cfg.passthrough.blacklistAmdgpu)) [
          "amdgpu"
        ];

        boot.kernelParams =
          lib.optionals cfg.enablePPFeatureMask [
            "amdgpu.ppfeaturemask=0xfff77fff"
          ]
          ++ lib.optionals cfg.disableHDCP [
            "amdgpu.dc_hdcp_enable=0"
          ]
          ++ lib.optionals cfg.drmDebug [
            # DRM subsystem debug logging — captures display engine events for black screen diagnosis
            "drm.debug=0x1e"
          ];

        services.xserver.videoDrivers = [ "amdgpu" ];

        # lact GUI is the HM module home/modules/lact/

        # LACT daemon via the stock NixOS module: it supplies the unit from the
        # packaged lactd.service (ExecStart = lact daemon). settings stays empty so
        # the stock /etc/lact/config.yaml writer is inert and the verbatim configFile
        # below owns the file -- LACT's parser needs it held byte-for-byte.
        # LACT is host GPU control for the AMD card; pointless (and a device
        # reference that can block a clean vfio unbind) once the card is passed.
        services.lact.enable = cfg.lact.enable && !cfg.passthrough.enable;

        # A stale /run/lactd.sock after an unclean stop (observed at a live
        # switch) blocks every restart until systemd's start-limit trips;
        # lact does not unlink it itself. Clear it before each start.
        systemd.services.lactd.serviceConfig.ExecStartPre = lib.mkIf (
          cfg.lact.enable && !cfg.passthrough.enable
        ) "${pkgs.coreutils}/bin/rm -f /run/lactd.sock";

        # Declarative LACT config — Nix owns /etc/lact/config.yaml when lact.configFile is
        # set (read-only /etc symlink); the daemon reads + applies it on boot. GUI saves
        # will not persist (the symlink is read-only) — change the file, not the GUI.
        environment.etc."lact/config.yaml" =
          lib.mkIf (cfg.lact.enable && !cfg.passthrough.enable && cfg.lact.configFile != null)
            {
              source = cfg.lact.configFile;
            };

        # Contribute radeonsi to the shared RustiCL driver list in graphics.nix
        myModules.hardware.graphics.openCL.rusticlDrivers = lib.mkIf cfg.openCL [ "radeonsi" ]; # foreign-ok: graphics.nix rusticlDrivers accumulator

        # Force Vulkan device selection on dual-AMD systems (iGPU + dGPU)
        # MESA_VK_DEVICE_SELECT is system-level (affects all Vulkan apps)
        # DXVK/VKD3D filters are user-level (Wine/Proton only) — provided by the HM radv module
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
