{ inputs, ... }: {
  flake.nixosModules.hardware-yeetmouse = { config, lib, pkgs, ... }: {
    options.myModules.hardware.yeetmouse = {
      enable = lib.mkEnableOption "YeetMouse input driver";
    };

    imports = [
      ./driver.nix
      ./devices/g502.nix
    ];

    config = lib.mkIf (config.myModules.hardware.yeetmouse.enable || config.myModules.hardware.yeetmouse.devices.g502.enable) {
      hardware.yeetmouse.enable = true;

      nixpkgs.overlays = [
        (final: prev: let
          actualKernel = config.boot.kernelPackages.kernel;
          kernelNameLower = lib.toLower (actualKernel.pname or actualKernel.name or "");
          kernelVersionLower = lib.toLower (actualKernel.modDirVersion or "");
          
          kernelUsesLLVM = 
            (builtins.match ".*cachyos.*" kernelNameLower != null) ||
            (builtins.match ".*cachyos.*" kernelVersionLower != null) ||
            (builtins.any (flag: 
              builtins.match ".*LLVM=1.*" (toString flag) != null || 
              builtins.match ".*CC=clang.*" (toString flag) != null
            ) (actualKernel.makeFlags or []));
          
          buildStdenv = if kernelUsesLLVM then final.llvmPackages_latest.stdenv else final.stdenv;
          
          buildMakeFlags = if kernelUsesLLVM then [
            "LLVM=1" "CC=clang" "LD=ld.lld" "KCFLAGS=-Wno-unused-command-line-argument"
          ] else [];
          
        in {
          yeetmouse = (final.callPackage ./package.nix {
            stdenv = buildStdenv;
            kernel = actualKernel;
            kernelModuleMakeFlags = buildMakeFlags;
          }).overrideAttrs (old: {
            src = inputs.yeetmouse-src;
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ lib.optionals kernelUsesLLVM [ final.llvmPackages_latest.lld ];
            postBuild = if kernelUsesLLVM then ''
              make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL" "CXX=clang++"
            '' else ''
              make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL"
            '';
          });
        })
      ];
    };
  };
}
