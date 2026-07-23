# overlays — canonical overlay composition for the whole flake.
#
# Every flake input that ships an overlay is composed here and exposed as
# `flake.overlays.default`. Each host includes it in `nixpkgs.overlays`
# and `perSystem.pkgs` uses the same default, so `checks.*`, `devShells.*`,
# and `nixosConfigurations.*` share the composed package set.
#
# Overlays are lazy: listing one doesn't evaluate it unless some consumer
# references an attribute from it. Safe to list everything.
#
# Placement rule: an input consumed through module option references
# (pkgs.<name>) composes here; a package with a single point of use is
# referenced there directly (scx-git, openhmd-rift) — no overlay entry
# for one caller.
#
# Temporary fixes live in _fixes/<package>.nix, one per file, each declaring
# { dropWhen, overlay }. They compose AFTER the input overlays (so they can
# override anything the inputs provide). The overlay-fixes-current check in
# _build/tests.nix evaluates every dropWhen against a probe pkgs WITHOUT the
# fixes and fails naming the file to delete once upstream has healed — a
# temporary override cannot silently outlive its reason.
{ inputs, lib, ... }:
let
  fixesDir = ./_fixes;
  loadFix =
    name:
    let
      v = import (fixesDir + "/${name}");
    in
    assert lib.assertMsg (
      v ? dropWhen && v ? overlay
    ) "overlay fix ${name} must declare dropWhen and overlay";
    v // { inherit name; };
  fixes = map loadFix (
    lib.filter (n: lib.hasSuffix ".nix" n) (lib.attrNames (builtins.readDir fixesDir))
  );

  inputOverlays = [
    inputs.vfio-stealth.overlays.default
    inputs.linux-corecycler.overlays.default
    inputs.nix-cachyos-kernel.overlays.pinned
    inputs.portmaster.overlays.default
    inputs.occt-nix.overlays.default
    # shared-nixpkgs, not .default: builds their package tree against OUR
    # `final` (one nixpkgs, deps shared, the _fixes below apply to their
    # packages too); .default would instantiate their own nixpkgs.
    inputs.llm-agents.overlays.shared-nixpkgs
    inputs.lsfg-vk.overlays.default
    inputs.proton-ge.overlays.default
    inputs.proton-cachyos.overlays.default
    inputs.umu-proton.overlays.default
    inputs.vkbasalt-overlay.overlays.default
    inputs.mesa-git-nix.overlays.default
    inputs.coolercontrol.overlays.default
    inputs.openviking.overlays.default
    inputs.lmstudio.overlays.default
    inputs.free-claude-code.overlays.default
    inputs.nix-vscode-extensions.overlays.default
    inputs.models-nix.overlays.default
    inputs.ripgrep-nix.overlays.default
    inputs.durdraw-nix.overlays.default
    inputs.streamcontroller-nix.overlays.default
    inputs.yeetmouse-nix.overlays.default
    inputs.rocksmith-nix.overlays.default
    inputs.eden.overlays.default
    inputs.mullvad-vpn-nix.overlays.default
  ];
in
{
  # composeManyExtensions threads each overlay's `prev` through the prior
  # overlays' outputs and keeps last-overwrites-earlier. A plain
  # `acc // (o final prev)` foldl fed every overlay the BASE prev, so any
  # future overlay reading a prior overlay's attr would silently see nixpkgs.
  flake.overlays.default = inputs.nixpkgs.lib.composeManyExtensions (
    inputOverlays ++ map (f: f.overlay) fixes
  );

  # Input overlays WITHOUT the fixes: the probe the overlay-fixes-current
  # check (_build/tests.nix) evaluates each dropWhen against.
  flake.overlays.probe = inputs.nixpkgs.lib.composeManyExtensions inputOverlays;
}
