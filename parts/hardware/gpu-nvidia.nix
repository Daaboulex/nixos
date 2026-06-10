# gpu-nvidia — NVIDIA proprietary driver and CUDA runtime.
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
      cfg = config.myModules.hardware.gpuNvidia;
      mkPkg =
        mode:
        if mode == "beta" then
          config.boot.kernelPackages.nvidiaPackages.beta
        else
          config.boot.kernelPackages.nvidiaPackages.stable;
    in
    {
      _class = "nixos";
      options.myModules.hardware.gpuNvidia = {
        enable = lib.mkEnableOption "Nvidia Graphics configuration";
        initrd.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Load the nvidia DRM modules in the initrd so Plymouth (and the
            early-boot fbcon / LUKS prompt) render on an nvidia-driven head.
            Needed only where nvidia scans out the host display BEFORE the
            stage-2 switch-root — e.g. the vfio-amd profile, where the 9070 XT
            is vfio-bound and the 1660S is the host's only display. amdgpu-driven
            profiles (normal / vfio-nvidia) don't need it: gpu-amd already loads
            amdgpu early, and nvidia in compute mode drives no display there.
          '';
        };
        profile = {
          mode = lib.mkOption {
            type = lib.types.enum [
              "sync"
              "offload"
              "compute"
            ];
            default = "sync";
            description = "PRIME render mode (sync/offload), or 'compute' = load the driver with NO PRIME — a secondary compute/NVENC card while another GPU drives the display.";
          };
          packageChannel = lib.mkOption {
            type = lib.types.enum [
              "beta"
              "stable"
            ];
            default = "beta";
            description = "Nvidia driver channel";
          };
          persistenced = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Nvidia persistenced daemon";
          };
          settings = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Nvidia settings GUI";
          };
          videoAcceleration = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Hardware video acceleration";
          };
          nvidiaBusId = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "PCI bus ID for Nvidia GPU";
          };
          intelBusId = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "PCI bus ID for Intel iGPU";
          };
          nvregEnable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "NVreg module parameters (VRAM preservation, firmware, power management)";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # videoDrivers is NixOS's activation switch for the nvidia driver —
            # without "nvidia" here, hardware.nvidia is configured but INERT (no
            # kernel module / userspace pulled in). List-merges with gpu-amd's
            # "amdgpu" → both GPUs' drivers load (correct for this dual-dGPU host).
            services.xserver.videoDrivers = [ "nvidia" ];
            hardware.nvidia =
              let
                pkg = mkPkg cfg.profile.packageChannel;
              in
              {
                open = true; # open GPU kernel module — tracks new-kernel APIs better than the proprietary one (7.0 broke the latter); fully supported on Turing (1660S)
                package = pkg;
                modesetting.enable = true;
                powerManagement.enable = true;
                powerManagement.finegrained = false;
                dynamicBoost.enable = false;
                prime =
                  if cfg.profile.mode == "sync" then
                    {
                      offload.enable = false;
                      offload.enableOffloadCmd = false;
                      sync.enable = true;
                      reverseSync.enable = false;
                      nvidiaBusId = lib.mkIf (cfg.profile.nvidiaBusId != "") cfg.profile.nvidiaBusId;
                      intelBusId = lib.mkIf (cfg.profile.intelBusId != "") cfg.profile.intelBusId;
                      allowExternalGpu = true;
                    }
                  else if cfg.profile.mode == "offload" then
                    {
                      offload.enable = true;
                      offload.enableOffloadCmd = true;
                      sync.enable = false;
                      reverseSync.enable = false;
                    }
                  else
                    {
                      # compute: NO PRIME — driver loads for CUDA/NVENC/manual
                      # offload; another GPU (the AMD RX 9070 XT) drives the display.
                      offload.enable = false;
                      sync.enable = false;
                      reverseSync.enable = false;
                    };
                nvidiaSettings = cfg.profile.settings;
                nvidiaPersistenced = cfg.profile.persistenced;
                forceFullCompositionPipeline = false;
                inherit (cfg.profile) videoAcceleration;
              };
            # Early KMS on an nvidia head (Plymouth / fbcon / LUKS) — see initrd.enable.
            # modeset=1 is already set by hardware.nvidia.modesetting; fbdev=1 is the
            # framebuffer the splash actually draws on. Both gated so normal/compute
            # profiles keep a slim, amdgpu-only initrd.
            boot.initrd.kernelModules = lib.mkIf cfg.initrd.enable [
              "nvidia"
              "nvidia_modeset"
              "nvidia_uvm"
              "nvidia_drm"
            ];
            boot.kernelParams = lib.mkIf cfg.initrd.enable [ "nvidia-drm.fbdev=1" ];
          }
          (lib.mkIf cfg.profile.nvregEnable {
            boot.extraModprobeConfig = ''
              options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp NVreg_EnableGpuFirmware=1 NVreg_DynamicPowerManagement=0x00
            '';
          })
        ]
      );
    };
in
{
  flake.modules.nixos.hardware-gpu-nvidia = mod;

}
