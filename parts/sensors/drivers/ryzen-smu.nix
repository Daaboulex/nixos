# ryzen_smu kernel module — exposes AMD SMU interface for Curve Optimizer,
# PBO limits, boost override, and PM table access.
#
# Supports both GCC (standard kernels) and Clang (CachyOS LTO kernels).
# Source: https://github.com/amkillam/ryzen_smu (amkillam fork with Zen 5 support)
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
  pname = "ryzen-smu-${kernel.version}";
  version = "0.1.7-unstable-2025-10-22";

  src = fetchFromGitHub {
    owner = "amkillam";
    repo = "ryzen_smu";
    rev = "21c1e2c51832dccfac64981b345745ce0cccf524";
    hash = "sha256-JA7dH958IceuBvHTp4lPlHolzLN9bXDt9hmhxITvvJA=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ llvm.nativeBuildInputs;

  makeFlags = [
    "TARGET=${kernel.modDirVersion}"
    "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ]
  ++ llvm.makeFlags
  ++ lib.optionals llvm.usesLLVM [
    "KCFLAGS=-Wno-unused-command-line-argument"
  ];

  installPhase = ''
    runHook preInstall
    install ryzen_smu.ko -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/ryzen_smu
    runHook postInstall
  '';

  meta = {
    description = "Linux kernel driver that exposes access to the SMU for AMD Ryzen Processors";
    homepage = "https://github.com/amkillam/ryzen_smu";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    # Zen 5 SMU decoding in this fork relies on cpufeature flags and
    # msr.h APIs that stabilized in 6.0. Build silently mis-detects on
    # older kernels — gate explicitly.
    broken = lib.versionOlder kernel.version "6.0";
  };
}
