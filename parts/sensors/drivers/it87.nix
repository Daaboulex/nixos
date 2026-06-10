# it87 kernel module — out-of-tree fork with support for newer ITE Super I/O chips.
# Provides temperature, fan speed, and voltage monitoring (in0 = Vcore on most boards).
#
# The in-tree it87 driver lags behind on newer chip IDs (IT8686E, IT8689E, etc.).
# This fork by Frank Crawford adds 12+ additional chips common on Gigabyte AM5/AM4 boards.
#
# Supports both GCC (standard kernels) and Clang (CachyOS LTO kernels).
# Source: https://github.com/frankcrawford/it87
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  llvmPackages_latest,
}:
let
  llvm = import ./llvm-kernel.nix {
    inherit
      lib
      kernel
      stdenv
      llvmPackages_latest
      ;
  };
in
llvm.buildStdenv.mkDerivation {
  pname = "it87";
  version = "unstable-2025-12-26";

  src = fetchFromGitHub {
    owner = "frankcrawford";
    repo = "it87";
    rev = "a9eb2495220cba861ef3df63fa15265e878293b6";
    hash = "sha256-iWyOctK+TFhVCOw2LiV4NiNFEAqNXOpSdGY//VwO8Ko=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ llvm.nativeBuildInputs;

  makeFlags = [
    "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=${placeholder "out"}"
  ]
  ++ llvm.makeFlags
  ++ lib.optionals llvm.usesLLVM [
    "KCFLAGS=-Wno-unused-command-line-argument"
  ];

  installPhase = ''
    install -D it87.ko -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon/"
  '';

  meta = {
    homepage = "https://github.com/frankcrawford/it87";
    description = "ITE IT87xx Super I/O hwmon driver — extended fork with 38+ chip support";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    # Upstream claims 3.10+ but the frankcrawford fork's hwmon chip-info
    # table uses the post-5.x hwmon_sysfs interface. Gate to 5.10 (first
    # LTS with the stable API).
    broken = lib.versionOlder kernel.version "5.10";
  };
}
