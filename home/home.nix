{ config, pkgs, lib, ... }:

let
  # Derive hostname and username from system configuration
  hostname = config.networking.hostName;
  username = config.myModules.primaryUser;
in
{
  # ============================================================================
  # Home Manager Configuration
  # ============================================================================
  home-manager = {
    # Use system-wide package set for consistency
    useGlobalPkgs = true;
    useUserPackages = true;

    # Backup existing files instead of failing
    backupFileExtension = "backup";

    # User-specific configuration
    users.${username} = {
      imports = [
        ./modules                   # Modularized configuration
        ./hosts/${hostname}         # Host-specific user configuration
      ];
    };
  };
}