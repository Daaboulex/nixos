{ config, pkgs, lib, ... }:
{
  options.myModules.security.sops = {
    enable = lib.mkEnableOption "sops-nix secret management";
    
    defaultSopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/secrets.yaml;
      description = "Default sops file containing encrypted secrets";
    };
    
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "Path to the age key file for decryption";
    };
  };

  config = lib.mkIf config.myModules.security.sops.enable {
    # Configure sops-nix
    sops = {
      defaultSopsFile = config.myModules.security.sops.defaultSopsFile;
      age.keyFile = config.myModules.security.sops.ageKeyFile;
      
      # Example secrets configuration (uncomment and modify as needed)
      # secrets = {
      #   "wifi/home/password" = {
      #     owner = "root";
      #     group = "root";
      #     mode = "0400";
      #   };
      #   "api_keys/example" = {
      #     owner = config.myModules.primaryUser;
      #     group = "users";
      #     mode = "0400";
      #   };
      # };
    };

    # Install sops for manual secret management
    environment.systemPackages = with pkgs; [
      sops
      age
    ];
  };
}
# sops-nix configuration module
# Enable with: myModules.security.sops.enable = true;
