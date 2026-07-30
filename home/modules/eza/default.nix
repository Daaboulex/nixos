# eza — modern ls replacement with theme-derived color scheme.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.eza;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;

  # eza capitalize: "blue" → "Blue", then "Magenta" → "Purple" (eza naming)
  eza =
    ansi:
    let
      n = lib.strings.toSentenceCase ansi;
    in
    if n == "Magenta" then "Purple" else n;

  # Semantic roles → eza color names (derived from theme ANSI map)
  accent = eza c.blue-ansi;
  accentAlt = eza c.blue-alt-ansi;
  err = eza c.red-ansi;
  warn = eza c.orange-ansi;
  ok = eza c.green-ansi;
  special = eza c.purple-ansi;
  dim = eza c.foreground-dim-ansi;
in
{
  options.myModules.home.eza.enable = lib.mkEnableOption "eza modern ls replacement";
  config = lib.mkIf cfg.enable {
    programs.eza = {
      enable = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;
      icons = lib.mkDefault "auto";
      git = lib.mkDefault true;
      extraOptions = lib.mkDefault [
        "--group-directories-first"
      ];
    }
    // lib.optionalAttrs hasTheme {
      # Colors derived from myModules.home.theme.colors ANSI map
      theme = {
        filekinds = {
          normal = {
            foreground = dim;
          };
          directory = {
            foreground = accent;
            is_bold = true;
          };
          symlink = {
            foreground = accentAlt;
          };
          pipe = {
            foreground = warn;
          };
          block_device = {
            foreground = warn;
            is_bold = true;
          };
          char_device = {
            foreground = warn;
            is_bold = true;
          };
          socket = {
            foreground = err;
            is_bold = true;
          };
          special = {
            foreground = warn;
          };
          executable = {
            foreground = ok;
            is_bold = true;
          };
          mount_point = {
            foreground = accent;
            is_bold = true;
            is_underline = true;
          };
        };
        perms = {
          user_read = {
            foreground = ok;
          };
          user_write = {
            foreground = warn;
          };
          user_execute_file = {
            foreground = err;
          };
          user_execute_other = {
            foreground = err;
          };
          group_read = {
            foreground = ok;
          };
          group_write = {
            foreground = warn;
          };
          group_execute = {
            foreground = err;
          };
          other_read = {
            foreground = ok;
          };
          other_write = {
            foreground = warn;
          };
          other_execute = {
            foreground = err;
          };
          special_user_file = {
            foreground = warn;
            is_bold = true;
          };
          special_other = {
            foreground = warn;
            is_bold = true;
          };
          attribute = {
            foreground = dim;
            is_dimmed = true;
          };
        };
        size = {
          number_byte = {
            foreground = ok;
          };
          number_kilo = {
            foreground = ok;
          };
          number_mega = {
            foreground = warn;
          };
          number_giga = {
            foreground = err;
          };
          number_huge = {
            foreground = err;
            is_bold = true;
          };
          unit_byte = {
            foreground = ok;
            is_dimmed = true;
          };
          unit_kilo = {
            foreground = ok;
            is_dimmed = true;
          };
          unit_mega = {
            foreground = warn;
            is_dimmed = true;
          };
          unit_giga = {
            foreground = err;
            is_dimmed = true;
          };
          unit_huge = {
            foreground = err;
            is_dimmed = true;
          };
        };
        users = {
          user_you = {
            foreground = warn;
            is_bold = true;
          };
          user_other = {
            foreground = dim;
            is_dimmed = true;
          };
          group_yours = {
            foreground = warn;
          };
          group_other = {
            foreground = dim;
            is_dimmed = true;
          };
        };
        git = {
          new = {
            foreground = ok;
          };
          modified = {
            foreground = warn;
          };
          deleted = {
            foreground = err;
          };
          renamed = {
            foreground = warn;
          };
          typechange = {
            foreground = special;
          };
          ignored = {
            foreground = dim;
            is_dimmed = true;
          };
          conflicted = {
            foreground = err;
            is_bold = true;
          };
        };
        git_repo = {
          branch_main = {
            foreground = ok;
            is_bold = true;
          };
          branch_other = {
            foreground = special;
          };
          git_clean = {
            foreground = ok;
          };
          git_dirty = {
            foreground = warn;
          };
        };
      };
    };
  };
}
