# ryzen_smu kernel module — builds with gcc or clang depending on kernel toolchain.
# CachyOS LTO kernels use clang, so out-of-tree modules must match.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  llvmPackages_latest,
}:
let
  kernelNameLower = lib.toLower (kernel.pname or kernel.name or "");
  kernelVersionLower = lib.toLower (kernel.modDirVersion or "");

  kernelUsesLLVM =
    (builtins.match ".*cachyos.*" kernelNameLower != null)
    || (builtins.match ".*cachyos.*" kernelVersionLower != null)
    || (builtins.any (
      flag:
      builtins.match ".*LLVM=1.*" (toString flag) != null
      || builtins.match ".*CC=clang.*" (toString flag) != null
    ) (kernel.makeFlags or [ ]));

  buildStdenv = if kernelUsesLLVM then llvmPackages_latest.stdenv else stdenv;

  version = "0.1.7-unstable-2025-10-22";

  src = fetchFromGitHub {
    owner = "amkillam";
    repo = "ryzen_smu";
    rev = "21c1e2c51832dccfac64981b345745ce0cccf524";
    hash = "sha256-JA7dH958IceuBvHTp4lPlHolzLN9bXDt9hmhxITvvJA=";
  };
in
buildStdenv.mkDerivation {
  pname = "ryzen-smu-${kernel.version}";
  inherit version src;

  hardeningDisable = [ "pic" ];

  nativeBuildInputs =
    kernel.moduleBuildDependencies
    ++ lib.optionals kernelUsesLLVM [
      llvmPackages_latest.lld
    ];

  makeFlags = [
    "TARGET=${kernel.modDirVersion}"
    "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ]
  ++ lib.optionals kernelUsesLLVM [
    "LLVM=1"
    "CC=clang"
    "LD=ld.lld"
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
  };
}
