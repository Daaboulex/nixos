# libinput — touchpad/trackpad behaviour (natural scrolling, tap-to-click).
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
      cfg = config.myModules.input.libinput;
    in
    {
      _class = "nixos";
      options.myModules.input.libinput = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "libinput touchpad with natural scrolling and tap-to-click";
        };
        naturalScrolling = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Natural (reverse) scrolling direction";
        };
        tapping = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Tap-to-click";
        };
      };
      config = lib.mkIf cfg.enable {
        services.libinput = {
          enable = true;
          touchpad = {
            inherit (cfg) naturalScrolling;
            inherit (cfg) tapping;
            clickMethod = "clickfinger";
            disableWhileTyping = true;
          };
        };
      };
    };
in
{
  flake.modules.nixos.input-libinput = mod;
}
