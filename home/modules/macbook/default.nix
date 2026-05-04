# macbook — HM ergonomics umbrella for Apple hardware.
#
# Home Manager counterpart to parts/macbook/ on the NixOS side. Bundles
# sub-modules that make Plasma feel more like macOS on Apple hardware:
#
#   - macbook.keyboard    Cmd (⌘) → Ctrl remap via xkb
#   - macbook.workspaces  Mac-like Spaces: 4 horizontal virtual desktops
#                         with wrap-around for touchpad swipe gestures
#   - macbook.dock        Remove the virtual desktop pager widget
#
# Each sub-module has its own enable that defaults to this umbrella's enable,
# so hosts normally only need `myModules.home.macbook.enable = true;` —
# individual sub-modules can still be disabled explicitly if desired.
{ config, lib, ... }:
let
  cfg = config.myModules.home.macbook;
in
{
  imports = [
    ./keyboard.nix
    ./workspaces.nix
    ./dock.nix
  ];

  options.myModules.home.macbook = {
    enable = lib.mkEnableOption "MacBook HM ergonomics (keyboard remap, Mac-like workspaces, dock tweaks)";
  };

  # No top-level config — each sub-module has its own config block gated on
  # its own enable (which defaults to cfg.enable).
  config = lib.mkIf cfg.enable { };
}
