# proton — declarative Proton compatibility tools for Steam's dropdown (GE-Proton + Proton-CachyOS, fleet-tracked daily).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.gaming.proton;
    in
    {
      _class = "nixos";
      options.myModules.gaming.proton = {
        enable = lib.mkEnableOption "declarative Proton compatibility tools (GE-Proton + Proton-CachyOS)";
        ge = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = pkgs.proton-ge;
          defaultText = lib.literalExpression "pkgs.proton-ge";
          description = "GE-Proton package for Steam's compatibility list (null = omit)";
        };
        cachyos = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = pkgs.proton-cachyos;
          defaultText = lib.literalExpression "pkgs.proton-cachyos";
          description = "Proton-CachyOS package for Steam's compatibility list (null = omit; pkgs.proton-cachyos-v3 on x86-64-v3 CPUs)";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.myModules.gaming.steam.enable;
            message = "myModules.gaming.proton: requires myModules.gaming.steam.enable = true. Enable Steam or disable the Proton tools.";
          }
        ];
        programs.steam.extraCompatPackages =
          lib.optional (cfg.ge != null) cfg.ge ++ lib.optional (cfg.cachyos != null) cfg.cachyos;
      };
    };
in
{
  flake.modules.nixos.gaming-proton = mod;
}
