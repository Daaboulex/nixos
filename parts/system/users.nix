{ inputs, ... }: {
  flake.nixosModules.system-users = { config, lib, pkgs, ... }: {
    options.myModules.system.users = {
      enable = lib.mkEnableOption "User configuration";
    };

    options.myModules.primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Primary system username used across all modules";
    };

    config = lib.mkIf config.myModules.system.users.enable {
      programs.zsh.enable = true;

      users.groups = {
        networkmanager = {};
        wheel = {};
        video = {};
        input = {};
        disk = {};
        bluetooth = {};
        dialout = {};
        i2c = {};
      };

      users.users.${config.myModules.primaryUser} = {
        isNormalUser = true;
        description = config.myModules.primaryUser;
        extraGroups = [
          "networkmanager" "wheel" "video" "input" "disk" "bluetooth" "dialout" "i2c"
        ];
        shell = pkgs.zsh;
      };
      
      # Ensure primaryUser option exists if we deprecate global modules/default.nix
      # But for now we might still use it or move it here.
    };
  };
}
