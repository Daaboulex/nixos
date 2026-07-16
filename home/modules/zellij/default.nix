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
          default_mode = "normal"; # keep the keybind hint bar visible always (discoverability); watch Ctrl+t (fzf) / Ctrl+h (nvim) clashes, remap reactively
          pane_frames = true; # pane titles + focus highlight for traversal/info (stock default)
          ui.pane_frames = {
            rounded_corners = true;
            hide_session_name = false;
          };
          simplified_ui = false;
          mouse_mode = true;
          copy_on_select = true;
          show_release_notes = false; # no version-bump popup on startup
          show_startup_tips = false; # no tip-of-the-day popup either

          # --- Developer QoL ---
          scroll_buffer_size = 50000; # per-pane scrollback, RAM-resident (hosts may lower on low-RAM machines)
          styled_underlines = true; # pass through undercurls (nvim LSP diagnostics)
          copy_command = "${pkgs.wl-clipboard}/bin/wl-copy"; # selection → Wayland system clipboard (self-contained)

          # Session persistence: layout/panes/running-commands resurrect after detach/reboot.
          # (serialize_pane_viewport writes scrollback content to disk -- left OFF for privacy.)
          session_serialization = true;

          # Traversal: Alt+1..9 jumps straight to tab N. Additive -- zellij merges with its
          # built-in keybinds (no clear-defaults), so Alt+hjkl / Alt+[ ] stay intact.
          keybinds.normal._children = map (i: {
            bind = {
              _args = [ "Alt ${toString i}" ];
              GoToTab = [ i ];
            };
          }) (lib.range 1 9);
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
