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
          type = lib.types.nullOr (lib.types.either lib.types.package (lib.types.listOf lib.types.package));
          default = with pkgs.proton-ge; [
            latest
            v11
            v10
            v9
          ];
          defaultText = lib.literalExpression "with pkgs.proton-ge; [ latest v11 v10 v9 ]";
          description = ''
            GE-Proton for Steam's compatibility list (null = omit). Defaults to a
            Steam-style menu of majors: latest (rolling newest, version-free
            "GE-Proton" identity) plus a stable "GE-Proton <major>" per line, each
            riding its line's newest point release. A single package or a list; set
            to `pkgs.proton-ge` for latest only, or trim the list per host.
          '';
        };
        cachyos = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.package (lib.types.listOf lib.types.package));
          default = pkgs.proton-cachyos-v3;
          defaultText = lib.literalExpression "pkgs.proton-cachyos-v3";
          description = ''
            Proton-CachyOS for Steam's compatibility list (null = omit). Defaults to
            the x86-64-v3 (AVX2) build, best for modern gaming CPUs. Override per host
            to the baseline `pkgs.proton-cachyos` on a pre-AVX2 CPU, or pass a list of
            CPU variants. CachyOS ships one rolling Proton major (it sunsets old
            lines), so there is no per-major menu here as there is for GE-Proton.
          '';
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
          lib.optionals (cfg.ge != null) (lib.toList cfg.ge)
          ++ lib.optionals (cfg.cachyos != null) (lib.toList cfg.cachyos);
      };
    };
in
{
  flake.modules.nixos.gaming-proton = mod;
}
