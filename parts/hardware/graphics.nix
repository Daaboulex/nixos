{ inputs, ... }: {
  flake.nixosModules.hardware-graphics = { config, lib, pkgs, ... }:
  let
    cfg = config.myModules.hardware.graphics;

    mesaPkg = if cfg.mesaGit.drivers == [] then
      pkgs.mesa-git
    else
      pkgs.mkMesaGit { vendors = cfg.mesaGit.drivers; };

    mesaPkg32 = if cfg.mesaGit.drivers == [] then
      pkgs.mesa-git-32
    else
      pkgs.mkMesaGit32 { vendors = cfg.mesaGit.drivers; };
  in {
    options.myModules.hardware.graphics = {
      enable = lib.mkEnableOption "Graphics support";
      enable32Bit = lib.mkOption { type = lib.types.bool; default = true; description = "Enable 32-bit graphics support"; };
      mesaGit = {
        enable = lib.mkEnableOption "Use mesa-git (bleeding-edge) instead of nixpkgs mesa";
        drivers = lib.mkOption {
          type = lib.types.listOf (lib.types.enum [ "amd" "intel" "nvidia" ]);
          default = [];
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

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        hardware.graphics = {
          enable = true;
          enable32Bit = cfg.enable32Bit;
          extraPackages = with pkgs; [
            libvdpau-va-gl # VDPAU via VA-API
            libva-vdpau-driver # VA-API VDPAU backend
          ];
          extraPackages32 = lib.mkIf cfg.enable32Bit (with pkgs.pkgsi686Linux; [
            libvdpau-va-gl
            libva-vdpau-driver
          ]);
        };
      }
      (lib.mkIf cfg.mesaGit.enable {
        hardware.graphics.package = lib.mkForce mesaPkg;
        hardware.graphics.package32 = lib.mkIf cfg.enable32Bit (lib.mkForce mesaPkg32);
      })
    ]);
  };
}
