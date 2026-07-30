# nano — GNU nano text editor with theme-aware defaults.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.nano;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.nano = {
    enable = lib.mkEnableOption "GNU nano text editor";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to nanorc.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.nano ];
    xdg.configFile."nano/nanorc".text = ''
      set autoindent
      set tabsize 2
      set tabstospaces
      set linenumbers
      set mouse
      set smarthome
      set zap
      set atblanks
      set softwrap
      include "${pkgs.nano}/share/nano/*.nanorc"
    ''
    + lib.optionalString hasTheme ''

      # Breeze Dark UI colors (derived from myModules.home.theme ANSI map)
      set titlecolor brightwhite,${c.blue-ansi}
      set statuscolor brightwhite,${c.blue-ansi}
      set errorcolor brightwhite,${c.red-ansi}
      set selectedcolor brightwhite,${c.purple-ansi}
      set stripecolor ,${c.orange-ansi}
      set numbercolor ${c.blue-alt-ansi}
      set keycolor ${c.blue-alt-ansi}
      set functioncolor ${c.blue-ansi}
      set promptcolor ${c.blue-alt-ansi}
      set spotlightcolor ${c.comment-ansi},${c.orange-ansi}
    ''
    + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";
  };
}
