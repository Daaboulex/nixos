{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.macbook.patches;
  kernel = config.boot.kernelPackages.kernel;
  
  # Add LLVM=1 flag for Clang-based kernels
  # The kernel's build system will handle compiler selection when LLVM=1 is set
  extraMakeFlags = if (kernel.stdenv.cc.isClang or false) then [ "LLVM=1" ] else [];
  
  # Add compiler tools when building kernel modules
  # Use unwrapped versions to avoid Nix wrapper flags that conflict with kernel builds
  # The kernel's build system handles all compiler flags and library paths itself
  extraBuildInputs = if (kernel.stdenv.cc.isClang or false) 
    then [ 
      pkgs.llvmPackages.clang-unwrapped 
      pkgs.llvmPackages.bintools-unwrapped 
      pkgs.llvmPackages.lld  # Linker for LLVM
    ]
    else [ 
      pkgs.gcc-unwrapped 
      pkgs.binutils-unwrapped 
    ];

  
  # Build patched applesmc driver
  applesmc-patched = pkgs.stdenv.mkDerivation {
    pname = "applesmc-patched";
    version = "${kernel.version}-patched";
    src = kernel.src;
    nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
    patches = [ ./applesmc-comprehensive-fixes.patch ];
    
    buildPhase = ''
      # Use the kernel's build system which automatically applies the correct flags
      make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/drivers/hwmon \
        ${lib.concatStringsSep " " extraMakeFlags} \
        KBUILD_MODPOST_WARN=1 \
        modules
    '';
    
    installPhase = ''
      mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
      cp drivers/hwmon/applesmc.ko $out/lib/modules/${kernel.modDirVersion}/extra/
    '';
  };
  
  # Build patched at24 driver
  at24-patched = pkgs.stdenv.mkDerivation {
    pname = "at24-patched";
    version = "${kernel.version}-patched";
    src = kernel.src;
    nativeBuildInputs = kernel.moduleBuildDependencies ++ extraBuildInputs;
    patches = [ ./at24-suppress-regulator-warning.patch ];
    
    buildPhase = ''
      # Use the kernel's build system which automatically applies the correct flags
      make -j$NIX_BUILD_CORES -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/drivers/misc/eeprom \
        ${lib.concatStringsSep " " extraMakeFlags} \
        KBUILD_MODPOST_WARN=1 \
        modules
    '';
    
    installPhase = ''
      mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
      cp drivers/misc/eeprom/at24.ko $out/lib/modules/${kernel.modDirVersion}/extra/
    '';
  };
in
{
  options.myModules.hardware.macbook.patches = {
    enable = lib.mkEnableOption "MacBook-specific kernel patches (AppleSMC fix + AT24 warning suppression)";
  };

  config = lib.mkIf cfg.enable {
    # Load our patched modules - they will override stock modules
    boot.extraModulePackages = [ applesmc-patched at24-patched ];
    
    # Force load the modules at boot
    boot.kernelModules = [ "applesmc" "at24" ];
  };
}
