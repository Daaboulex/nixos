# dock — MacBook dock tweaks (remove virtual desktop pager on small screens).
#
# Currently only one tweak: remove the virtual desktop pager widget from
# the bottom panel. Dock real estate is tight on the 1280×800 MacBook
# Pro 9,2 built-in display, and the pager adds little value when the
# macbook.workspaces sub-module already provides touchpad-swipe
# navigation between Spaces.
#
# Implementation: sets the `showPager` option exposed by
# myModules.home.plasma.panels, which rebuilds its widget list without
# the pager entry.
{ config, lib, ... }:
let
  cfg = config.myModules.home.macbook.dock;
in
{
  options.myModules.home.macbook.dock = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.myModules.home.macbook.enable;
      description = "Apply MacBook-specific dock tweaks (hide virtual desktop pager).";
    };
  };

  config = lib.mkIf cfg.enable {
    myModules.home.plasma.panels.showPager = false;
  };
}
