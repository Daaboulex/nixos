# kernelModuleGuards — eval-time guards against mis-layered / conflicting kernel
# modules. Returns `{ assertions; warnings; }` for a host's `config`, driven by a
# declarative `registry` so the checks scale as parts/modules grow: add a row, every
# host that imports `boot-module-guards` is checked automatically.
#
# Severity split:
#   assertions (fail the build) — genuinely broken states that would misbehave at boot.
#   warnings   (surface drift)  — misplacement that is wasteful but not breaking.
#
# Consumed by parts/boot/module-guards.nix as
#   inherit (myLib.kernelModuleGuards { inherit config; }) assertions warnings;
{ lib }:
{ config }:
let
  inherit (lib)
    concatStringsSep
    filter
    elem
    optional
    ;
  inherit (builtins) elemAt;

  # ── Declarative registry — the scaling knob ──
  registry = {
    # Modules that must load LATE (boot.kernelModules), never from the initrd:
    # out-of-tree sensor / peripheral drivers with no role before switch-root.
    # (amdgpu/nvidia are deliberately absent — early-KMS for Plymouth is a valid
    # initrd use; the passed-GPU case is covered by the nvidia-passthrough check.)
    lateOnly = [
      "it87"
      "zenpower"
      "ryzen_smu"
      "nct6775"
      "drivetemp"
      "kvmfr"
      "yeetmouse"
      "b43"
      "amd_3d_vcache"
    ];
    # Driver pairs that bind the same hardware and must not co-load.
    mutuallyExclusive = [
      [
        "zenpower"
        "k10temp"
      ]
      [
        "nouveau"
        "nvidia"
      ]
    ];
    # Modules whose presence in BOTH initrd and late lists is intentional and so
    # must not be flagged as a redundant dual-load: GPU drivers (early-KMS), and
    # the vfio core (initrd capture before the host driver + the late base set).
    legitDualLoad = [
      "amdgpu"
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
      "vfio"
      "vfio_pci"
      "vfio-pci"
      "vfio_iommu_type1"
    ];
  };

  loadEarly = config.boot.initrd.kernelModules or [ ];
  loadLate = config.boot.kernelModules or [ ];
  loadSet = loadEarly ++ loadLate;
  blacklist = config.boot.blacklistedKernelModules or [ ];

  # intersection of list `a` with list `b`
  intersect = a: b: filter (m: elem m b) a;

  # ── Hard conflicts (assertions) ──

  # A blacklisted module listed in kernelModules/initrd.kernelModules still loads.
  loadBlacklistConflicts = intersect loadSet blacklist;

  # Mutually-exclusive pairs both present in the load set.
  exclusiveHits = filter (
    pair: elem (elemAt pair 0) loadSet && elem (elemAt pair 1) loadSet
  ) registry.mutuallyExclusive;

  # Nvidia passthrough must release the card cleanly: no nvidia* in the initrd and
  # nouveau blacklisted, else a host driver can claim the card before vfio-pci.
  nvPass = config.myModules.hardware.gpuNvidia.passthrough.enable or false;
  nvEarly = intersect loadEarly [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  nvNouveauBlacklisted = elem "nouveau" blacklist;
  nvClean = nvEarly == [ ] && nvNouveauBlacklisted;

  # ── Soft drift (warnings) ──

  lateOnlyEarly = intersect loadEarly registry.lateOnly;
  redundantDual = filter (m: !(elem m registry.legitDualLoad)) (intersect loadEarly loadLate);
in
{
  assertions = [
    {
      assertion = loadBlacklistConflicts == [ ];
      message = "myModules.boot.moduleGuards: module(s) both loaded and blacklisted: ${concatStringsSep ", " loadBlacklistConflicts}. A blacklisted module in boot.kernelModules / boot.initrd.kernelModules still loads — remove it from one side.";
    }
    {
      assertion = exclusiveHits == [ ];
      message = "myModules.boot.moduleGuards: mutually-exclusive kernel modules co-loaded: ${
        concatStringsSep "; " (map (p: concatStringsSep " + " p) exclusiveHits)
      }. These drivers bind the same hardware — blacklist one.";
    }
    {
      assertion = !nvPass || nvClean;
      message = "myModules.boot.moduleGuards: gpuNvidia.passthrough.enable is set but the Nvidia card is not cleanly released for vfio-pci.${
        lib.optionalString (nvEarly != [ ])
          " nvidia driver in initrd: ${concatStringsSep ", " nvEarly} (move out of boot.initrd.kernelModules)."
      }${lib.optionalString (!nvNouveauBlacklisted) " nouveau is not in boot.blacklistedKernelModules."}";
    }
  ];

  warnings =
    optional (lateOnlyEarly != [ ])
      "myModules.boot.moduleGuards: late-only module(s) found in boot.initrd.kernelModules: ${concatStringsSep ", " lateOnlyEarly}. These have no role before switch-root — move them to boot.kernelModules."
    ++
      optional (redundantDual != [ ])
        "myModules.boot.moduleGuards: module(s) in BOTH boot.initrd.kernelModules and boot.kernelModules (redundant late load): ${concatStringsSep ", " redundantDual}.";
}
