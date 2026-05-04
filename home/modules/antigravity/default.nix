# antigravity — Google Antigravity with `agy` CLI wrapper.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.antigravity;
in
{
  options.myModules.home.antigravity = {
    enable = lib.mkEnableOption "Google Antigravity (agy wrapper)";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.symlinkJoin {
        name = "agy-wrapper";
        paths = [ pkgs.google-antigravity ];
        postBuild = ''
          ln -s $out/bin/antigravity $out/bin/agy
        '';
      })
    ];
  };
}
