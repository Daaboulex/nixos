# Expose repo-local helpers under `flake.lib.*` so they are callable as
# `inputs.self.lib.<name>` from modules and reusable by downstream flakes.
#
# Helpers that only depend on `lib` are pre-applied here, so consumers
# can write `myLib.mkSettingsOption { }` without re-passing `{ inherit lib; }`.
# Helpers that need per-call runtime args (pkgs, config, drv) stay as
# factory functions.
#
# Consumers receive the full attrset as `myLib` via each host's
# `specialArgs` + `home-manager.extraSpecialArgs` — see
# `parts/hosts/<host>/flake-module.nix`.
{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  flake.lib = {
    # Factories — take runtime args (pkgs, config, drv) at call time.
    mkSimplePackage = import ../../home/lib/mkSimplePackage.nix;
    themeCtx = import ../../home/lib/themeCtx.nix;
    withStdenvCC = import ../../home/lib/withStdenvCC.nix;

    # Lib-applied — consumers call directly without re-passing lib.
    cap = (import ../../home/lib/cap.nix) { inherit lib; };
    mkSettingsOption = (import ../../home/lib/mkSettingsOption.nix) { inherit lib; };
    mergeSettings = (import ../../home/lib/mergeSettings.nix) { inherit lib; };
  };
}
