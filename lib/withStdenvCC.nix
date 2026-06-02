# withStdenvCC — force-inject stdenv.cc into a derivation's nativeBuildInputs.
#
# Workaround for third-party packages (e.g. kernel-packages that ship
# with empty `nativeBuildInputs = []` under `strictDeps = true`) that
# strip stdenv's default cc-wrapper from the build environment and
# fail with:
#
#     bash: line 1: gcc: command not found
#     make: *** [...] Error 127
#
# This helper takes any derivation and re-adds pkgs.stdenv.cc to its
# nativeBuildInputs so gcc + friends are always on PATH at build time.
# Safe on packages that already build fine — the extra entry is a no-op
# there.
#
# Signature:
#   withStdenvCC { pkgs, drv }  →  derivation
#
# Usage (from a NixOS module):
#   environment.systemPackages = [
#     (inputs.self.lib.withStdenvCC {
#       inherit pkgs;
#       drv = config.boot.kernelPackages.turbostat;
#     })
#   ];
#
# Known users:
#   - parts/diagnostics/turbostat.nix — nix-cachyos-kernel 7.0.0 turbostat
#     derivation ships with empty nativeBuildInputs + strictDeps=true.
{ pkgs, drv }:
drv.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.stdenv.cc ];
})
