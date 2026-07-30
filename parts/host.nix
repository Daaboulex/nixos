# host — typed per-host CPU capability declaration.
#
# Contract:
#   Options:  myModules.host.tier
#   Sets:     nothing (pure metadata; read by kernel.nix to derive mArch default)
#   Depends:  nothing
#
# `tier` is the single source of truth for CPU capability. kernel.mArch
# defaults from it; hosts can still mkForce/override for uarch-specific
# compile targets (e.g. "ZEN5" on Zen 5 boxes).
#
# No `role`/profile/host-class abstraction: capability is per-host. Hosts
# declare the specific capabilities they want via explicit toggles named
# for the capability (e.g. `myModules.hardware.power.tlp`), never for a
# machine class like "laptop" — the dendritically correct, granular shape.
_:
let
  mod =
    { lib, ... }:
    {
      _class = "nixos";

      options.myModules.host = {
        tier = lib.mkOption {
          type = lib.types.enum [
            "v2"
            "v3"
            "v4"
          ];
          description = ''
            CPU microarchitecture tier:
              - `v2` — x86-64-v2 (SSE4.2, no AVX2). Ivy Bridge / older AMD.
              - `v3` — x86-64-v3 (AVX2 + BMI2). Haswell+ / Zen+.
              - `v4` — x86-64-v4 (AVX-512). Zen4+ / Sapphire Rapids+.
            Consumed by kernel.nix as mArch default (see
            `parts/boot/kernel.nix`).
          '';
        };
      };
    };
in
{
  flake.modules.nixos.host = mod;

}
