# input — Plasma input devices (keyboard, mouse, touchpad) and KRunner settings.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.plasma = {
    # ==========================================================================
    # Input Devices
    # ==========================================================================
    input = {
      keyboard = {
        numlockOnStartup = lib.mkDefault "on";
        # XKB options — hard baseline, merged with anything added by other
        # modules (e.g. macbook.keyboard appends ctrl:swap_lwin_lctl). Hosts
        # that want to *remove* caps:super must use lib.mkForce.
        options = [ "caps:super" ];
        # layouts = [
        #   { layout = "us"; }
        #   { layout = "de"; }
        # ];
        # repeatDelay = 600;
        # repeatRate = 25.0;
      };
      # mice = [];      # Set per-host (device IDs are hardware-specific)
      # touchpads = []; # Set per-host
    };

    # ==========================================================================
    # KRunner
    # ==========================================================================
    krunner = {
      position = lib.mkDefault "center";
      historyBehavior = null;
      activateWhenTypingOnDesktop = null;
      shortcuts = {
        launch = lib.mkDefault "Alt+Space";
        runCommandOnClipboard = null;
      };
    };
  };
}
