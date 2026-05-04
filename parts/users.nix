# users — primary user account, groups, and shell configuration.
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
      cfg = config.myModules.users;
    in
    {
      _class = "nixos";
      options.myModules.users = {
        enable = lib.mkEnableOption "User configuration";
      };

      options.myModules.primaryUser = lib.mkOption {
        type = lib.types.str;
        default = "user";
        description = "Primary system username used across all modules";
      };

      config = lib.mkIf cfg.enable {
        programs.zsh.enable = true;

        users.groups = {
          networkmanager = { };
          wheel = { };
          video = { };
          input = { };
          disk = { };
          bluetooth = { };
          dialout = { };
          i2c = { };
        };

        users.users.${config.myModules.primaryUser} = {
          isNormalUser = true;
          uid = 1000;
          description = config.myModules.primaryUser;
          extraGroups = [
            "networkmanager"
            "wheel"
            "video"
            "input"
            "bluetooth"
            "dialout"
            "i2c"
          ];
          shell = pkgs.zsh;
        };
      };
    };
in
{
  flake.modules.nixos.users = mod;

}
