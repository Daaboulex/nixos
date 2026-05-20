# cachyos-v2 — wrapping overlay that adds x86_64-v2 cachyOS kernel variants.
#
# Why we own this in-tree
# -----------------------
# xddxdd/nix-cachyos-kernel PR #50 (2026-05) removed the v2 variant entries
# from `kernel-cachyos/default.nix` to reclaim build compute for the new
# BORE × v3/v4/zen4 matrix. CachyOS upstream binary mirrors stopped shipping
# v1/v2 around the same time. None of this is technical impossibility — the
# infrastructure to BUILD v2 (mkCachyKernel + cachySettings.processorOpt.v2
# + CachyOS upstream kconfig support) is intact. Only pre-built binaries
# were dropped. We've been local-compiling v2 the entire time (xddxdd's
# cache never carried v2 either), so re-materializing v2 here keeps the
# existing workflow unchanged on hosts where v2 ISA matters (MBP 9,2 Ivy
# Bridge — performance-first: scheduler + LTO + BBR3 + SSE4.2 codegen).
#
# What it builds
# --------------
# The 4 v2 variants PR #50 removed: linux-cachyos-{latest,latest-lto,lts,
# lts-lto}-x86_64-v2 plus their linuxPackages-* mirrors. Stacked on top of
# xddxdd's full set so all v3/v4/zen4/bore/etc attrs remain available — the
# existing kernel selection logic in parts/boot/kernel.nix (cachyosArch
# suffix → attr lookup) works unchanged for all hosts.
#
# Why a wrapping overlay (not a sibling overlay)
# ----------------------------------------------
# parts/_build/overlays.nix uses a custom flat compose pattern
# (`acc // (o final prev)`) that shallow-merges overlay outputs. Two
# sibling overlays both returning `cachyosKernels = {...}` would have the
# later one OVERWRITE the earlier — not merge — because `//` is top-level.
# So we apply xddxdd's overlay INSIDE this file, union its cachyosKernels
# set with our v2 additions, and emit the union. overlays.nix then
# references ONLY this file (not xddxdd's overlay directly).
#
# Dependency surface
# ------------------
# - inputs.nix-cachyos-kernel  — mkCachyKernel.nix, helpers.nix, version.json,
#   and overlays.pinned all imported from xddxdd HEAD. A reorganization of
#   xddxdd's file layout or overlay API would require updating this file.
# - inputs.cachyos-kernel + inputs.cachyos-kernel-patches  — CachyOS
#   upstream sources as top-level flake inputs, locked independently of
#   xddxdd's internal pins.
{ inputs }:
final: prev:
let
  inherit (final)
    lib
    callPackage
    linuxKernel
    fetchurl
    ;
  xddxdd = inputs.nix-cachyos-kernel;

  # Apply xddxdd's overlay first so we can stack v2 on top of its output.
  xddxddPinned = xddxdd.overlays.pinned final prev;

  mkCachyKernel = callPackage "${xddxdd}/kernel-cachyos/mkCachyKernel.nix" {
    inputs = {
      inherit (inputs) cachyos-kernel cachyos-kernel-patches;
    };
  };

  helpers = callPackage "${xddxdd}/helpers.nix" { };
  inherit (helpers) kernelModuleLLVMOverride;

  linuxSources = lib.mapAttrs (_: v: {
    inherit (v) version;
    src = fetchurl { inherit (v) url hash; };
  }) (lib.importJSON "${xddxdd}/kernel-cachyos/version.json");

  v2Variants = {
    "linux-cachyos-latest-x86_64-v2" = {
      source = "latest";
      lto = "none";
      configVariant = "linux-cachyos";
    };
    "linux-cachyos-latest-lto-x86_64-v2" = {
      source = "latest";
      lto = "thin";
      configVariant = "linux-cachyos";
    };
    "linux-cachyos-lts-x86_64-v2" = {
      source = "lts";
      lto = "none";
      configVariant = "linux-cachyos-lts";
    };
    "linux-cachyos-lts-lto-x86_64-v2" = {
      source = "lts";
      lto = "thin";
      configVariant = "linux-cachyos-lts";
    };
  };

  mkV2 =
    pname:
    {
      source,
      lto,
      configVariant,
    }:
    mkCachyKernel {
      inherit pname lto configVariant;
      inherit (linuxSources.${source}) version src;
      processorOpt = "x86_64-v2";
    };

  kernels = lib.mapAttrs mkV2 v2Variants;

  # Mirror xddxdd/kernel-cachyos/packages.nix shape (minus zfs_cachyos —
  # not used on any v2 host; replicate the packages.nix zfs branch if a
  # v2 host ever needs it).
  packages = lib.mapAttrs' (
    n: v:
    lib.nameValuePair "linuxPackages-${lib.removePrefix "linux-" n}" (
      kernelModuleLLVMOverride (linuxKernel.packagesFor v)
    )
  ) kernels;
in
xddxddPinned
// {
  cachyosKernels = xddxddPinned.cachyosKernels // kernels // packages;
}
