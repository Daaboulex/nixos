# mkDotfileModule — factory for HM modules that install one package plus an
# optional whole-file dotfile driven by an extraConfig option. The option's
# value becomes the ENTIRE file (no base config); an empty string writes no
# file at all. Collapses the identical curl/wget/minicom scaffold.
#
# Consumer files follow the mkSimplePackage wrapper shape:
#
#   # home/modules/curl/default.nix
#   { config, lib, pkgs, myLib, ... }@args:
#   (myLib.mkDotfileModule {
#     name = "curl";
#     description = "curl HTTP client";
#     file = ".curlrc";
#     exampleLines = "`--compressed`, `--location`, `--max-time 30`.";
#   }) args
{ lib }:
{
  name,
  description,
  file,
  package ? null,
  exampleLines ? "",
}:
{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.${name};
  pkg = if package != null then package pkgs else pkgs.${name};
in
{
  options.myModules.home.${name} = {
    enable = lib.mkEnableOption description;
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Full text content of `~/${file}`. There is no base config — the
        value here becomes the entire file. Setting an empty string
        leaves no `${file}` written at all.
        ${lib.optionalString (exampleLines != "") "Example lines: ${exampleLines}"}
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkg ];

    home.file.${file} = lib.mkIf (cfg.extraConfig != "") {
      text = cfg.extraConfig;
    };
  };
}
