# corecycler — per-core CPU stability tester and PBO Curve Optimizer tuner.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.corecycler;
  package = if cfg.unfreeBackends then pkgs.linux-corecycler-full else pkgs.linux-corecycler;
in
{
  options.myModules.home.corecycler = {
    enable = lib.mkEnableOption "CoreCyclerLx per-core CPU stability tester and PBO Curve Optimizer tuner";
    unfreeBackends = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to include unfree backends (mprime). When false, only FOSS backends (stress-ng) are bundled.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ package ];
  };
}
