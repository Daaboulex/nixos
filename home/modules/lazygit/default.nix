# lazygit — terminal Git UI with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.lazygit;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.lazygit = {
    enable = lib.mkEnableOption "lazygit terminal Git UI";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;
      }
      // lib.optionalAttrs hasTheme {
        settings.gui.theme = {
          lightTheme = false;
          activeBorderColor = [
            c.blue
            "bold"
          ];
          inactiveBorderColor = [ c.foreground-dim ];
          optionsTextColor = [ c.blue ];
          selectedLineBgColor = [ c.surface ];
          selectedRangeBgColor = [ c.selection-alt ];
          cherryPickedCommitBgColor = [ c.selection-alt ];
          cherryPickedCommitFgColor = [ c.blue ];
          unstagedChangesColor = [ c.red ];
          defaultFgColor = [ c.foreground ];
        };
      };
      overrides = cfg.settings;
    };
  };
}
