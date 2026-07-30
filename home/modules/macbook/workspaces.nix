# workspaces — MacBook Mac-like virtual desktops (KWin Spaces emulation).
#
# Configures KWin virtual desktops to behave like macOS Spaces:
#
#   - Multiple horizontal desktops (default 4) so the built-in KWin
#     4-finger touchpad swipe (Plasma 6 Wayland default) has somewhere
#     to swipe between.
#   - RollOverDesktops = true so swiping past the last desktop wraps
#     around to the first, matching macOS behavior.
#
# The touchpad gesture itself is a Plasma default; no extra binding is
# needed. If the default 4-finger swipe feels wrong it can be changed
# in System Settings → Touchpad → Gestures per-user.
{ config, lib, ... }:
let
  cfg = config.myModules.home.macbook.workspaces;
in
{
  options.myModules.home.macbook.workspaces = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.myModules.home.macbook.enable;
      description = "Enable Mac-like virtual desktops (horizontal Spaces with wrap-around).";
    };
    count = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of virtual desktops to create.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.kwin.virtualDesktops = {
      number = cfg.count;
      rows = lib.mkDefault 1;
    };
    programs.plasma.configFile."kwinrc"."Windows"."RollOverDesktops" = lib.mkDefault true;
  };
}
