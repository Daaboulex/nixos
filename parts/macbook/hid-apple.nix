# hid-apple — Apple keyboard hid_apple configuration (fnMode, Option/Command swap).
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
      cfg = config.myModules.macbook.hidApple;
    in
    {
      _class = "nixos";
      options.myModules.macbook.hidApple = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apple keyboard hid_apple configuration (fnMode, Option/Command swap)";
        };
        fnMode = lib.mkOption {
          type = lib.types.enum [
            0
            1
            2
          ];
          default = 2;
          description = "Apple keyboard fn key behavior (0=disabled, 1=press fn for media, 2=press fn for F-keys)";
        };
        swapOptCmd = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Swap Option and Command keys (makes Cmd act as Alt)";
        };
      };
      config = lib.mkIf cfg.enable {
        boot.extraModprobeConfig = lib.mkAfter ''
          options hid_apple fnmode=${toString cfg.fnMode}
          ${lib.optionalString cfg.swapOptCmd "options hid_apple swap_opt_cmd=1"}
        '';
        boot.kernelModules = [ "hid_apple" ];
      };
    };
in
{
  flake.modules.nixos.macbook-hid-apple = mod;

}
