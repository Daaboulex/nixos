# nix-ld — dynamic linker shim for running unpatched FHS binaries on NixOS.
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
      cfg = config.myModules.nix.nixLd;
    in
    {
      _class = "nixos";
      options.myModules.nix.nixLd = {
        enable = lib.mkEnableOption "nix-ld for running unpatched binaries";
        libraries = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            stdenv.cc.cc
            zlib
            fuse3
            icu
            nss
            openssl
            curl
            expat
          ];
          description = "Libraries for nix-ld to provide to unpatched binaries";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.nix-ld.enable = true;
        programs.nix-ld.libraries = lib.mkDefault cfg.libraries;
      };
    };
in
{
  flake.modules.nixos.nix-nix-ld = mod;

}
