# zellij — terminal workspace/multiplexer with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.zellij;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.zellij = {
    enable = lib.mkEnableOption "Zellij terminal workspace (multiplexer)";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.zellij = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;
        exitShellOnExit = lib.mkDefault true; # one `exit` leaves zellij AND the launching shell (no double-exit)
        settings = {
          default_layout = "compact";
          default_mode = "locked"; # zellij grabs nothing but Ctrl+g until unlocked → no key clashes with nvim/fzf/zsh
          pane_frames = false;
          simplified_ui = false;
          mouse_mode = true;
          copy_on_select = true;
          show_release_notes = false; # no version-bump popup on startup
          show_startup_tips = false; # no tip-of-the-day popup either

          # --- Developer QoL ---
          scroll_buffer_size = 10000; # bounded scrollback per pane
          styled_underlines = true; # pass through undercurls (nvim LSP diagnostics)
          copy_command = "${pkgs.wl-clipboard}/bin/wl-copy"; # selection → Wayland system clipboard (self-contained)
        }
        # scrollback_editor → nvim only when neovim is enabled (else zellij's
        # $EDITOR default; guarded cross-module ref, AUDIT.md §19).
        // lib.optionalAttrs config.myModules.home.neovim.enable {
          scrollback_editor = "nvim";
        }
        // lib.optionalAttrs hasTheme {
          theme = "breeze-dark";
          themes.breeze-dark = {
            fg = c.foreground;
            bg = c.background;
            black = c.background;
            inherit (c) red;
            inherit (c) green;
            yellow = c.orange;
            inherit (c) blue;
            magenta = c.purple;
            cyan = c.blue-alt;
            white = c.foreground;
            inherit (c) orange;
          };
        };
      };
      overrides = cfg.settings;
    };
  };
}
