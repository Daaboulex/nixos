{
  lib,
  options,
  ...
}:

{
  # ============================================================================
  # StreamController — Declarative Stream Deck page/key configuration
  # ============================================================================
  # Two-layer architecture:
  #   NixOS  (parts/input/streamcontroller.nix) → patched package, udev rules,
  #                                                kdotool, system packages
  #   HM     (this module)                       → page/key/action config
  #
  # The external streamcontroller-nix module (imported via sharedModules)
  # provides the full option interface with these sections:
  #   - package:      streamcontroller package to use
  #   - dataPath:     where StreamController stores data (str)
  #   - pages:        page definitions with keys and actions (attrsOf submodule)
  #   - defaultPages: which page each deck shows by default (attrsOf str)
  #   - assets:       icon/image files to deploy (attrsOf path)
  #   - extraCommands: additional setup commands (listOf str)
  #
  # Page structure:
  #   pages.<name> = {
  #     brightness = { value = int; overwrite = bool; };
  #     screensaver = nullable attrs;
  #     extraConfig = attrs;
  #     keys.<col>x<row> = {
  #       states.<id> = {
  #         label = {
  #           top/center/bottom = {
  #             text = str;
  #             size = int;
  #             color = str (hex);
  #             font-family = str;
  #             font-weight = str;
  #             outline_width = int;
  #           };
  #         };
  #         media = { path = str; size = float; valign = int; };
  #         background = nullable str (hex);
  #         actions = listOf attrs;
  #         image-control-action = int;
  #         label-control-actions = listOf int;
  #         background-control-action = nullable int;
  #       };
  #     };
  #   };
  #
  # Available action plugins:
  #   com_core447_OSPlugin::RunCommand       — run shell command
  #   com_core447_OSPlugin::Hotkey           — send keyboard shortcut
  #   com_core447_MediaPlugin::PlayPause     — media play/pause
  #   com_core447_MediaPlugin::Previous      — media previous track
  #   com_core447_MediaPlugin::Next          — media next track
  #   com_core447_Battery::BatteryPercentage — show device battery
  #   com_core447_DeckPlugin::ChangePage     — switch Stream Deck page
  #
  # Almost everything is per-host (device serials, pages, keys, assets,
  # actions). This wrapper only provides default brightness.
  #
  # Applied via systemd user service on login (generates JSON page files).
  #
  # Guarded: only applies when the streamcontroller-nix HM module is loaded.

  config = lib.optionalAttrs (options.programs ? streamcontroller) {
    programs.streamcontroller = {

      # ── Data path ──────────────────────────────────────────────────────
      # dataPath: str — where StreamController stores pages, assets, plugins.
      # Defaults to ${xdg.dataHome}/StreamController in the external module.
      # Override per-host if using Flatpak data directory:
      #   dataPath = "${config.home.homeDirectory}/.var/app/com.core447.StreamController/data";

      # ── Default pages ──────────────────────────────────────────────────
      # defaultPages: attrsOf str — maps deck serial numbers to page names.
      # Set per-host: serial numbers are unique to each physical Stream Deck.

      # ── Assets ─────────────────────────────────────────────────────────
      # assets: attrsOf path — icon/image files deployed to <dataPath>/assets/.
      # Set per-host: different hosts may use different icons.

      # ── Pages ──────────────────────────────────────────────────────────
      # pages: attrsOf submodule — page definitions with keys and actions.
      # Set per-host: page layouts, button functions, and Stream Deck
      # dimensions (5x3, 8x4, etc.) vary by device model and host.

      # ── Extra commands ─────────────────────────────────────────────────
      # extraCommands: listOf str — additional setup commands after
      # page generation. Set per-host.
    };
  };
}
