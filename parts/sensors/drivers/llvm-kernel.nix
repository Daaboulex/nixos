# llvm-kernel — shared CachyOS/LLVM toolchain detection + clang build wiring for
# the out-of-tree sensor kernel modules (it87, zenpower, ryzen-smu). CachyOS LTO
# kernels are built with Clang; a GCC-built module won't load against them, so a
# driver must follow the running kernel's toolchain. This detection was
# triplicated across the drivers — single-sourced here.
#
# Returns: usesLLVM (bool), buildStdenv, and the LLVM-conditional nativeBuildInputs
# / makeFlags additions. Per-driver KCFLAGS stay in each driver (they differ).
{
  lib,
  kernel,
  stdenv,
  llvmPackages_latest,
}:
let
  # Canonical ground truth: did the kernel build with Clang? Verified true for the
  # CachyOS LTO kernel and false for a stock GCC kernel -- replaces the old fragile
  # kernel-name / makeFlags string-match heuristic (whose CC=clang branch was dead).
  usesLLVM = kernel.stdenv.cc.isClang or false;
in
{
  inherit usesLLVM;
  buildStdenv = if usesLLVM then llvmPackages_latest.stdenv else stdenv;
  nativeBuildInputs = lib.optionals usesLLVM [ llvmPackages_latest.lld ];
  makeFlags = lib.optionals usesLLVM [
    "LLVM=1"
    "CC=clang"
    "LD=ld.lld"
  ];
}
