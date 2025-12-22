{ config, lib, pkgs, ... }:

# sudo nix-channel --list
# nixos https://nixos.org/channels/nixos-25.05
# nixos-wsl https://github.com/nix-community/NixOS-WSL/archive/refs/heads/release-25.05.tar.gz

{
  imports = [
    # include NixOS-WSL modules
    <nixos-wsl/modules>
  ];

  wsl.enable = true;
  wsl.defaultUser = "nixos";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Enable flakes support
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Optional: Define some flakes inputs (if you're using flakes)
  # This is an example of how to import a flake to your system
  # inputs.nixos.url = "github:nixos/nixpkgs/nixos-unstable";

  # Example of using flakes with specific packages or configurations
  # systemPackages = [ pkgs.someFlakePackage ];

  # If you're using flakes to manage system configurations, you can enable `nixosConfigurations` here
  # nixosConfigurations = {
  #   myConfig = {
  #     # Configuration options related to your flake
  #   };
  # };
}