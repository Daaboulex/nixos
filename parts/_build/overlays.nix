# overlays.nix — canonical overlay composition for the whole flake.
#
# Every flake input that ships an overlay is composed here and exposed as
# `flake.overlays.default`. Both hosts set `nixpkgs.overlays = [
# inputs.self.overlays.default ];` and the `perSystem.pkgs` uses the same
# list — so `checks.*`, `devShells.*`, and `nixosConfigurations.*` all
# see identical package sets.
#
# Overlays are lazy: listing one doesn't evaluate it unless some consumer
# references an attribute from it. Safe to list everything.
{ inputs, ... }:
{
  flake.overlays.default =
    final: prev:
    let
      compose = overlays: builtins.foldl' (acc: o: acc // (o final prev)) { } overlays;
    in
    compose [
      inputs.vfio-stealth.overlays.default
      inputs.linux-corecycler.overlays.default
      inputs.nix-cachyos-kernel.overlays.pinned
      inputs.tidalcycles.overlays.default
      inputs.antigravity.overlays.default
      inputs.portmaster.overlays.default
      inputs.occt-nix.overlays.default
      inputs.llm-agents.overlays.default
      inputs.lsfg-vk.overlays.default
      inputs.vkbasalt-overlay.overlays.default
      inputs.mesa-git-nix.overlays.default
      inputs.coolercontrol.overlays.default
      inputs.openviking.overlays.default
      inputs.lmstudio.overlays.default
      inputs.nix-vscode-extensions.overlays.default
      inputs.models-nix.overlays.default
      inputs.ripgrep-nix.overlays.default
      inputs.durdraw-nix.overlays.default
      inputs.streamcontroller-nix.overlays.default
      inputs.yeetmouse-nix.overlays.default
      inputs.rocksmith-nix.overlays.default
      inputs.eden.overlays.default
      inputs.mullvad-vpn-nix.overlays.default

      # nixpkgs#513245: openldap test017-syncreplication-refresh fails
      # consistently on i686 (32-bit cross-build). Only affects bottles/wine
      # FHS envs that pull pkgsi686Linux.openldap. 64-bit keeps tests.
      # Remove when nixpkgs merges a fix.
      (_final: prev: {
        openldap = prev.openldap.overrideAttrs {
          doCheck = !prev.stdenv.hostPlatform.isi686;
        };
      })

      # Local overlay — MUST be last in compose (compose pattern
      # `acc // (o final prev)` overwrites attrs from earlier overlays).
      # Currently empty — add local overrides here when needed.
    ];
}
