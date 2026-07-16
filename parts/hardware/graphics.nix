# graphics — base graphics support (Mesa, 32-bit libs, VA-API/VDPAU).
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
      cfg = config.myModules.hardware.graphics;

      mesaPkg =
        if cfg.mesaGit.drivers == [ ] then
          pkgs.mesa-git
        else
          pkgs.mkMesaGit { vendors = cfg.mesaGit.drivers; };

      mesaPkg32 =
        if cfg.mesaGit.drivers == [ ] then
          pkgs.mesa-git-32
        else
          pkgs.mkMesaGit32 { vendors = cfg.mesaGit.drivers; };
    in
    {
      _class = "nixos";
      options.myModules.hardware.graphics = {
        enable = lib.mkEnableOption "Graphics support";
        enable32Bit = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "32-bit graphics support";
        };
        openCL = {
          rusticlDrivers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "radeonsi"
              "iris"
            ];
            description = ''
              Gallium drivers to enable in RustiCL (Mesa's OpenCL implementation).
              GPU vendor modules append their driver automatically when their openCL
              option is enabled. Set by gpu-amd (radeonsi) and gpu-intel (iris).
              Assembled into RUSTICL_ENABLE session variable as a comma-separated list.
            '';
          };
        };
        mesaGit = {
          enable = lib.mkEnableOption "mesa-git (bleeding-edge) instead of nixpkgs mesa";
          drivers = lib.mkOption {
            type = lib.types.listOf (
              lib.types.enum [
                "amd"
                "intel"
                "nvidia"
              ]
            );
            default = [ ];
            example = [ "amd" ];
            description = ''
              GPU vendors to compile drivers for. Only the selected vendor drivers
              plus common essentials (llvmpipe, zink, virgl, swrast) are built.

              Use multiple entries for multi-GPU setups (e.g. Intel iGPU + NVIDIA dGPU).
              An empty list (default) builds all drivers.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            hardware.graphics = {
              enable = true;
              inherit (cfg) enable32Bit;
              extraPackages =
                with pkgs;
                [
                  libvdpau-va-gl
                  libva-vdpau-driver
                ]
                ++ lib.optionals (!cfg.mesaGit.enable) [
                  pkgs.mesa.opencl
                ];
              extraPackages32 = lib.mkIf cfg.enable32Bit (
                with pkgs.pkgsi686Linux;
                [
                  libvdpau-va-gl
                  libva-vdpau-driver
                ]
              );
            };
          }
          (lib.mkIf cfg.mesaGit.enable {
            # Why: nixpkgs ships mesa as the default hardware.graphics.package.
            # mesaGit users want their self-compiled bleeding-edge mesa to WIN,
            # not merge — mkForce is the only way to replace the stock attr.
            hardware.graphics.package = lib.mkForce mesaPkg;
            hardware.graphics.package32 = lib.mkIf cfg.enable32Bit (lib.mkForce mesaPkg32);
            hardware.graphics.extraPackages = [ mesaPkg.opencl ];
          })
          (lib.mkIf (cfg.openCL.rusticlDrivers != [ ]) {
            environment.sessionVariables.RUSTICL_ENABLE = lib.concatStringsSep "," cfg.openCL.rusticlDrivers;
          })
          {
            # ADD (not replace) the driver's explicit Vulkan layer dir to the loader
            # search path; VK_ADD_LAYER_PATH preserves user layers (mangohud/vkbasalt),
            # unlike VK_LAYER_PATH which clobbers them. Owned here with the other
            # Mesa/Vulkan session vars.
            environment.sessionVariables.VK_ADD_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
          }
          {
            # vulkan-tools/mesa-demos are the HM module home/modules/vulkan-tools/
          }
        ]
      );
    };
in
{
  flake.modules.nixos.hardware-graphics = mod;

}
