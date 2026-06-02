# yazi — terminal file manager with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.yazi;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
  defaultSettings = {
    mgr = {
      show_hidden = lib.mkDefault false;
      sort_by = lib.mkDefault "alphabetical";
      sort_dir_first = lib.mkDefault true;
      sort_reverse = lib.mkDefault false;
      linemode = lib.mkDefault "none";
      ratio = lib.mkDefault [
        1
        3
        4
      ];
    };
    log.enabled = false;
    # Yazi >= 26.1.22 dropped fetcher `id` and now requires `group` (git.yazi README).
    plugin.prepend_fetchers = [
      {
        url = "*";
        run = "git";
        group = "git";
      }
      {
        url = "*/";
        run = "git";
        group = "git";
      }
    ];
  };
in
{
  options.myModules.home.yazi = {
    enable = lib.mkEnableOption "yazi terminal file manager";
    settings = myLib.mkSettingsOption {
      description = "Overrides merged over module defaults (applied to programs.yazi.settings).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi.enable = true;
    # LOCKED: HM#5941 — manual y wrapper used instead
    programs.yazi.enableZshIntegration = false;

    programs.yazi.plugins = {
      inherit (pkgs.yaziPlugins) git;
      inherit (pkgs.yaziPlugins) smart-enter;
      inherit (pkgs.yaziPlugins) smart-filter;
    };

    programs.yazi.settings = myLib.mergeSettings {
      defaults = defaultSettings;
      overrides = cfg.settings;
    };

    programs.yazi.keymap.mgr.prepend_keymap = [
      {
        on = "l";
        run = "plugin smart-enter";
        desc = "Enter dir or open file";
      }
      {
        on = "F";
        run = "plugin smart-filter";
        desc = "Smart filter";
      }
    ];

    programs.yazi.initLua = ''
      ${lib.optionalString config.myModules.home.zoxide.enable ''require("zoxide"):setup { update_db = true }''}
      require("git"):setup {}
    '';

    programs.yazi.theme = lib.mkIf hasTheme {
      mgr = {
        cwd = {
          fg = c.blue;
        };
        border_symbol = "|";
        border_style = {
          fg = c.foreground-dim;
        };
        marker_copied = {
          fg = c.green;
          bg = c.green;
        };
        marker_cut = {
          fg = c.red;
          bg = c.red;
        };
        marker_marked = {
          fg = c.blue;
          bg = c.blue;
        };
        marker_selected = {
          fg = c.blue;
          bg = c.blue;
        };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = {
          fg = c.surface;
          bg = c.surface;
        };
        mode_normal = {
          bg = c.blue;
          fg = c.background;
          bold = true;
        };
        mode_select = {
          bg = c.green;
          fg = c.background;
          bold = true;
        };
        mode_unset = {
          bg = c.red;
          fg = c.background;
          bold = true;
        };
        progress_label = {
          fg = c.foreground;
          bold = true;
        };
        progress_normal = {
          fg = c.blue;
          bg = c.surface;
        };
        progress_error = {
          fg = c.red;
          bg = c.surface;
        };
        perm_type = {
          fg = c.blue;
        };
        perm_read = {
          fg = c.green;
        };
        perm_write = {
          fg = c.orange;
        };
        perm_exec = {
          fg = c.red;
        };
        perm_sep = {
          fg = c.foreground-dim;
        };
      };
      tabs = {
        active = {
          bg = c.blue;
          fg = c.background;
          bold = true;
        };
        inactive = {
          bg = c.surface;
          fg = c.foreground-dim;
        };
      };
      filetype.rules = [
        {
          fg = c.green;
          mime = "image/*";
        }
        {
          fg = c.blue;
          mime = "video/*";
        }
        {
          fg = c.blue;
          mime = "audio/*";
        }
        {
          fg = c.purple;
          mime = "application/zip";
        }
        {
          fg = c.purple;
          mime = "application/gzip";
        }
        {
          fg = c.purple;
          mime = "application/x-tar";
        }
        {
          fg = c.red;
          mime = "application/pdf";
        }
        {
          fg = c.green;
          name = "*.nix";
        }
        {
          fg = c.orange;
          name = "*.md";
        }
        {
          fg = c.blue;
          name = "*.lua";
        }
        {
          fg = c.orange;
          name = "*.json";
        }
        {
          fg = c.orange;
          name = "*.yaml";
        }
        {
          fg = c.orange;
          name = "*.toml";
        }
      ];
    };

    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
      lib.mkAfter ''
        function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
          command yazi "$@" --cwd-file="$tmp"
          if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
      ''
    );
  };
}
