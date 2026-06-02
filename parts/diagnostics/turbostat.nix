# turbostat — Intel/AMD per-core frequency + C-state + thermal monitoring CLI.
#
# Ships the kernel-matched turbostat build (tracks running kernel's MSR
# layout + CPU model tables) through the generic `withStdenvCC` lib
# helper, which force-injects stdenv.cc into nativeBuildInputs so
# builds don't fail with `gcc: command not found` on kernel flakes
# that strip stdenv's cc-wrapper under strictDeps=true (e.g.
# nix-cachyos-kernel's 7.0.0 turbostat).
_: {
  flake.modules.nixos.diagnostics-turbostat =
    {
      lib,
      pkgs,
      config,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.diagnostics.turbostat;
    in
    {
      _class = "nixos";
      options.myModules.diagnostics.turbostat.enable =
        lib.mkEnableOption "turbostat CPU diagnostics tool";

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          (myLib.withStdenvCC {
            inherit pkgs;
            drv = config.boot.kernelPackages.turbostat;
          })
        ];
      };
    };
}
