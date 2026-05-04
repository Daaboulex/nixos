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
    + lib.optionalString hasTheme (
      let
        a = c;
      in
      ''

        # Breeze Dark UI colors (derived from myModules.home.theme ANSI map)
        set titlecolor brightwhite,${a.blue-ansi}
        set statuscolor brightwhite,${a.blue-ansi}
        set errorcolor brightwhite,${a.red-ansi}
        set selectedcolor brightwhite,${a.purple-ansi}
        set stripecolor ,${a.orange-ansi}
        set numbercolor ${a.blue-alt-ansi}
        set keycolor ${a.blue-alt-ansi}
        set functioncolor ${a.blue-ansi}
        set promptcolor ${a.blue-alt-ansi}
        set spotlightcolor ${a.comment-ansi},${a.orange-ansi}
      ''
    )
    + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";
  };
}
