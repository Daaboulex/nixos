# gdb — GNU debugger with custom ~/.gdbinit and theme integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.gdb;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.gdb = {
    enable = lib.mkEnableOption "GDB debugger with custom init";
    extraInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to .gdbinit.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.gdb ];
    home.file.".gdbinit".text = ''
      # Allow auto-loading debug helper scripts from any path (Nix store)
      set auto-load safe-path /

      # Auto-download debug symbols from CachyOS debuginfod
      set debuginfod enabled on
      set debuginfod urls https://debuginfod.cachyos.org
    ''
    + lib.optionalString hasTheme ''

      # Breeze Dark styling (derived from myModules.home.theme ANSI map)
      set style address foreground ${c.blue-ansi}
      set style function foreground ${c.blue-alt-ansi}
      set style variable foreground ${c.orange-ansi}
      set style string foreground ${c.green-ansi}
      set style filename foreground ${c.green-ansi}
      set style highlight foreground ${c.red-ansi}
      set style metadata foreground ${c.purple-ansi}
      set style tui-border foreground ${c.blue-alt-ansi}
      set style tui-active-border foreground ${c.blue-ansi} bold
    ''
    + lib.optionalString (cfg.extraInit != "") "\n${cfg.extraInit}\n";
  };
}
