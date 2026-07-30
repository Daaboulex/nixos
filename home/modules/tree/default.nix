# tree — recursive directory listing with theme-derived LS_COLORS mapping.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.tree;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;

  # ANSI codes mapped from theme ANSI names
  # di=directories, ln=symlinks, ex=executables, fi=files, pi=pipes, so=sockets, bd=block, cd=char
  ansiCode =
    name:
    {
      "blue" = "34";
      "red" = "31";
      "green" = "32";
      "yellow" = "33";
      "magenta" = "35";
      "cyan" = "36";
      "white" = "37";
      "black" = "90";
    }
    .${name} or "0";
in
{
  options.myModules.home.tree.enable = lib.mkEnableOption "tree — recursive directory listing";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = with pkgs; [
          tree
        ];
      }
      # LS_COLORS derived from theme ANSI map — used by tree, zsh completions, and ls
      (myLib.mkSessionVars (
        lib.mkIf hasTheme {
          LS_COLORS = lib.concatStringsSep ":" [
            "di=1;${ansiCode c.blue-ansi}" # directories: bold accent
            "ln=${ansiCode c.blue-alt-ansi}" # symlinks: secondary accent
            "ex=1;${ansiCode c.green-ansi}" # executables: bold success
            "fi=0" # regular files: default
            "pi=${ansiCode c.orange-ansi}" # pipes: warning
            "so=1;${ansiCode c.red-ansi}" # sockets: bold error
            "bd=1;${ansiCode c.orange-ansi}" # block devices: bold warning
            "cd=1;${ansiCode c.orange-ansi}" # char devices: bold warning
            "or=${ansiCode c.red-ansi}" # orphan symlinks: error
            "mi=${ansiCode c.red-ansi}" # missing targets: error
            "*.nix=${ansiCode c.green-ansi}" # nix files: success
            "*.md=${ansiCode c.orange-ansi}" # markdown: warning/neutral
            "*.json=${ansiCode c.orange-ansi}" # config: warning/neutral
            "*.yaml=${ansiCode c.orange-ansi}"
            "*.toml=${ansiCode c.orange-ansi}"
            "*.tar=${ansiCode c.purple-ansi}" # archives: special
            "*.gz=${ansiCode c.purple-ansi}"
            "*.zip=${ansiCode c.purple-ansi}"
            "*.png=${ansiCode c.green-ansi}" # images: success
            "*.jpg=${ansiCode c.green-ansi}"
            "*.svg=${ansiCode c.green-ansi}"
          ];
        }
      ))
    ]
  );
}
