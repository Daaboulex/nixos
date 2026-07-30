# proton — declarative Proton compatibility tools for Steam's dropdown (GE-Proton, Proton-CachyOS, UMU-Proton; fleet-tracked daily).
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
      familyType = lib.types.nullOr (
        lib.types.either lib.types.package (lib.types.listOf lib.types.package)
      );
    in
    {
      _class = "nixos";
      options.myModules.gaming.proton = {
        enable = lib.mkEnableOption "declarative Proton compatibility tools (GE-Proton, Proton-CachyOS, UMU-Proton)";
        ge = lib.mkOption {
          type = familyType;
          default = with pkgs.proton-ge; [
            latest
            v11
            v10
            v9
            v8
            v7
          ];
          defaultText = lib.literalExpression "with pkgs.proton-ge; [ latest v11 v10 v9 v8 v7 ]";
          description = ''
            GE-Proton for Steam's compatibility list (null = omit). Defaults to the
            full Steam-style back-catalog: latest (the rolling newest, shown as
            "GE-Proton-latest") plus one frozen pin per major shown by its exact
            version ("GE-Proton 11-1" through "GE-Proton 7-55"). A single package or
            a list; set to `pkgs.proton-ge` for latest only, or trim the list per host.
          '';
        };
        cachyos = lib.mkOption {
          type = familyType;
          default = with pkgs.proton-cachyos-v3; [
            latest
            v11
            v10
          ];
          defaultText = lib.literalExpression "with pkgs.proton-cachyos-v3; [ latest v11 v10 ]";
          description = ''
            Proton-CachyOS for Steam's compatibility list (null = omit). Defaults to
            the x86-64-v3 (AVX2) back-catalog, best for modern gaming CPUs: latest
            ("Proton-CachyOS-latest v3") plus a frozen pin per packaged major
            ("Proton-CachyOS 11.0-20260702 v3", "Proton-CachyOS 10.0-sunset v3").
            Override per host to the baseline `pkgs.proton-cachyos` variant on a
            pre-AVX2 CPU, or trim the list.
          '';
        };
        umu = lib.mkOption {
          type = familyType;
          default = with pkgs.umu-proton; [
            latest
            v10
            v9
          ];
          defaultText = lib.literalExpression "with pkgs.umu-proton; [ latest v10 v9 ]";
          description = ''
            UMU-Proton for Steam's compatibility list (null = omit). Defaults to the
            full back-catalog: latest ("UMU-Proton-latest") plus a frozen pin per
            packaged major ("UMU-Proton 10.0-4", "UMU-Proton 9.0-4e"). Stock Valve
            Proton with no GE patch set - the clean A/B arm for isolating a GE-side
            regression. A single package or a list; trim per host.
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
          lib.concatMap (fam: lib.optionals (fam != null) (lib.toList fam))
            [
              cfg.ge
              cfg.cachyos
              cfg.umu
            ];
      };
    };
in
{
  flake.modules.nixos.gaming-proton = mod;
}
