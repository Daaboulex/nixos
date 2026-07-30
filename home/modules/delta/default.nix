# delta — syntax-highlighting git diff pager with theme integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.delta;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.delta = {
    enable = lib.mkEnableOption "delta syntax-highlighting git diff pager";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.delta = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableGitIntegration = true;
        options = {
          navigate = true;
          line-numbers = true;
          side-by-side = false;
          hyperlinks = true;
        }
        // lib.optionalAttrs hasTheme {
          syntax-theme = "base16";
          minus-style = "syntax \"${c.background-alt}\"";
          minus-emph-style = "syntax \"${c.selection-alt}\"";
          plus-style = "syntax \"${c.background-alt}\"";
          plus-emph-style = "syntax \"${c.selection-alt}\"";
          line-numbers-minus-style = c.red;
          line-numbers-plus-style = c.green;
          line-numbers-zero-style = c.comment;
          hunk-header-decoration-style = "${c.blue} box";
        };
      };
      overrides = cfg.settings;
    };

    programs.git.settings = lib.mkIf config.programs.git.enable {
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };
}
