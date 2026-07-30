# wine — Wine installation with variant selection and optional Bottles frontend.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myModules.home.wine;

  winePackage =
    if cfg.variant == "cachyos" then
      inputs.wine-cachyos-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    else
      pkgs.wineWow64Packages.${cfg.variant};
in
{
  options.myModules.home.wine = {
    enable = lib.mkEnableOption "Wine installation";
    variant = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "stableFull"
        "unstable"
        "unstableFull"
        "staging"
        "stagingFull"
        "wayland"
        "waylandFull"
        "cachyos"
      ];
      default = "stagingFull";
      description = ''
        Which Wine to install, as a new-WoW64 build (one 64-bit tree that also
        runs 32-bit Windows programs).

        Release axis: `stable` is the numbered Wine release, `unstable` its
        development series, `staging` adds the wine-staging patch set, and
        `wayland` is `stable` built without X11. `cachyos` is CachyOS's
        Proton-derived build from Daaboulex/wine-cachyos-nix, compiled from
        source rather than taken from nixpkgs.

        The `Full` suffix adds the optional dependencies (GStreamer, OpenCL,
        ODBC, SANE, v4l, gphoto2, Kerberos, smartcard) and embeds the Gecko and
        Mono installers; without it only the core set is built. `cachyos`
        carries no suffix because it is always that full set — upstream ships a
        single build, so there is no reduced variant to distinguish it from.

        Every variant here supports both Wayland and X11. The `wayland` ones are
        not "Wayland-enabled" but X11-*disabled*, so pick them only to force
        Wayland-only behaviour.

        Only this package provides `wine` in the profile — Bottles, WineASIO
        and the Proton compatibility tools each carry their own Wine.
      '';
    };
    bottles.enable = lib.mkEnableOption "Bottles installation";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ winePackage ];
    })
    (lib.mkIf cfg.bottles.enable {
      home.packages = [ pkgs.bottles ];
    })
  ];
}
