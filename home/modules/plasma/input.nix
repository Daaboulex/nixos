# Plasma Input Devices & KRunner
# Keyboard, mouse, touchpad, and KRunner settings
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
        # XKB options — override per-host (e.g. laptop might not remap caps)
        options = lib.mkDefault [ "caps:super" ];
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
