{ inputs, ... }:
{
  flake.nixosModules.system-users =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.system.users;
    in
    {
      _class = "nixos";
      options.myModules.system.users = {
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
          description = config.myModules.primaryUser;
          extraGroups = [
            "networkmanager"
            "wheel"
            "video"
            "input"
            "disk"
            "bluetooth"
            "dialout"
            "i2c"
          ];
          shell = pkgs.zsh;
        };
      };
    };
}
