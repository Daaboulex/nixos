# Plasma Input Devices & KRunner
# Keyboard, mouse, touchpad, and KRunner settings
{ config, pkgs, lib, ... }:

{
  programs.plasma = {
    # ==========================================================================
    # Input Devices
    # ==========================================================================
    input = {
      keyboard = {
        numlockOnStartup = lib.mkDefault "on";
        # layouts = [
        #   { layout = "us"; }
        #   { layout = "de"; }
        # ];
        # repeatDelay = 600;
        # repeatRate = 25.0;
      };
      # mice = [
      #   {
      #     name = "Logitech G502";
      #     vendorId = "046d";
      #     productId = "c077";
      #     acceleration = 0.0;
      #     accelerationProfile = "none";
      #   }
      # ];
      # touchpads = [];
    };

    # ==========================================================================
    # KRunner
    # ==========================================================================
    krunner = {
      position = lib.mkDefault "center"; # Migrated from krunnerrc.General.FreeFloating
      historyBehavior = null; # null = default ("enableSuggestions")
      activateWhenTypingOnDesktop = null; # null = default
      shortcuts = {
        launch = lib.mkDefault "Alt+Space";
        runCommandOnClipboard = null;
      };
    };

    # ==========================================================================
    # Keyboard Layout & XKB Options (configFile — no native option)
    # ==========================================================================
    configFile."kxkbrc"."Layout" = {
      Options = lib.mkDefault "caps:super";    # Override per-host (e.g. laptop might not remap caps)
      ResetOldOptions = lib.mkDefault true;
      Use = lib.mkDefault true;
    };
  };
}
