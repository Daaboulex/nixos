# /modules/nixos/yeetmouse.nix
# Configuration for the YeetMouse input driver using its NixOS module options.
# This leverages the new driver implementation that modifies input events directly.
{ config, pkgs, inputs, lib, ... }:

{
  options.myModules.hardware.yeetmouse = {
    enable = lib.mkEnableOption "YeetMouse input driver";
  };

  imports = [
    ./driver.nix
    ./devices/g502.nix
  ];

  config = lib.mkIf (config.myModules.hardware.yeetmouse.enable || config.myModules.hardware.yeetmouse.devices.g502.enable) {
    # Enable the driver
    hardware.yeetmouse.enable = true;

    # Apply overlay - use system kernel and detect LLVM automatically
    nixpkgs.overlays = [
      (final: prev: let
        # Get the actual kernel being used
        actualKernel = config.boot.kernelPackages.kernel;
        
        # Detect if kernel was built with LLVM
        # CachyOS kernels are always LLVM-built - check derivation name or modDirVersion
        # Also check makeFlags as fallback for other LLVM kernels
        kernelNameLower = lib.toLower (actualKernel.pname or actualKernel.name or "");
        kernelVersionLower = lib.toLower (actualKernel.modDirVersion or "");
        
        kernelUsesLLVM = 
          (builtins.match ".*cachyos.*" kernelNameLower != null) ||
          (builtins.match ".*cachyos.*" kernelVersionLower != null) ||
          (builtins.any (flag: 
            builtins.match ".*LLVM=1.*" (toString flag) != null || 
            builtins.match ".*CC=clang.*" (toString flag) != null
          ) (actualKernel.makeFlags or []));
        
        # Only use LLVM stdenv and flags if kernel was built with LLVM
        buildStdenv = if kernelUsesLLVM 
          then final.llvmPackages_latest.stdenv 
          else final.stdenv;
        
        # Build makeFlags based on kernel's compiler
        buildMakeFlags = if kernelUsesLLVM then [
          "LLVM=1"
          "CC=clang"
          "LD=ld.lld"
          "KCFLAGS=-Wno-unused-command-line-argument"
        ] else [];
        
      in {
        yeetmouse = (final.callPackage ./package.nix {
          stdenv = buildStdenv;
          kernel = actualKernel;
          kernelModuleMakeFlags = buildMakeFlags;
        }).overrideAttrs (old: {
          src = inputs.yeetmouse-src;
          nativeBuildInputs = (old.nativeBuildInputs or []) 
            ++ lib.optionals kernelUsesLLVM [ final.llvmPackages_latest.lld ];
          # Use appropriate compiler for GUI
          postBuild = if kernelUsesLLVM then ''
            make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL" "CXX=clang++"
          '' else ''
            make "-j$NIX_BUILD_CORES" -C $sourceRoot/gui "M=$sourceRoot/gui" "LIBS=-lglfw -lGL"
          '';
        });
      })
    ];
  };
}

# Example

  # Ensure the YeetMouse module (imported via flake.nix) handles dependencies.
  # The following are likely redundant IF the module does its job:
  # services.udev.packages = [ pkgs.yeetmouse ];
  #  boot.kernelModules = [ "yeetmouse" ];
  #  environment.systemPackages = [ pkgs.yeetmouse ];

  # hardware.yeetmouse = {
    # 1. Enable the YeetMouse module and driver
    #enable = true;

    # 2. Configure Global Parameters (Refer to YeetMouse README for exact names/units)
    # --- Sensitivity ---
    # Simple isotropic sensitivity:
    # sensitivity = 0.5;


    # --- Rotation ---
    # rotation = {
      # Angle should be in DEGREES as per README
      # angle = -3.0;
      # Optional snapping:
      # snappingAngle = 45.0;
      # snappingThreshold = 2.0;
    # };

    # --- Other Global Options ---
    # preScale = 1.0;    # Default: 1.0 (no scaling)
    # offset = 0.0;      # Default: 0.0 (no offset)
    # inputCap = 0.0;    # Default: 0.0 (disabled)
    # outputCap = 0.0;   # Default: 0.0 (disabled)


    # 3. Configure Acceleration Mode (Choose ONE block)
    # --- Jump Mode ---
    # mode.jump = {
      # acceleration = 1.5;  # Gain applied AFTER midpoint (Raw Accel Output 1.5)
      # midpoint = 6.65;     # Input speed threshold where jump starts (Raw Accel Input 6.65)
      # useSmoothing = false;# Disable smoothing at the midpoint threshold (Raw Accel Smooth 0)
      # smoothness = 0.2;  # Optional: Overall curve smoothness (Default likely fine if useSmoothing=false)
    # };

    # --- Other Modes (Commented Out) ---
    # mode.linear = { acceleration = 1.2; };
    # mode.power = { acceleration = 1.2; exponent = 0.2; };
    # mode.classic = { acceleration = 1.2; exponent = 0.2; };
    # mode.motivity = { acceleration = 1.2; start = 10.0; };
    # mode.lut = { data = [ [1.1 1.2] [5.2 4.8] ]; };
