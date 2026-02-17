{ inputs, ... }: {
  flake.nixosModules.hardware-networking = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.networking;
    in
    {
    options.myModules.hardware.networking = {
      enable = lib.mkEnableOption "Networking configuration";
      openPorts = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "List of TCP ports to open";
      };
      openPortRanges = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        description = "List of TCP port ranges to open (e.g. [{ from = 1000; to = 2000; }])";
      };
    };

    config = lib.mkIf cfg.enable {
      networking = {
        networkmanager.enable = true;
        firewall = {
          enable = true;
          allowedTCPPorts = cfg.openPorts;
          allowedTCPPortRanges = cfg.openPortRanges;
          allowedUDPPortRanges = cfg.openPortRanges;
        };
        nameservers = [
          "176.9.93.198" "176.9.1.117" "2a01:4f8:151:34aa::198" "2a01:4f8:141:316d::117"
          "9.9.9.9" "149.112.112.112" "2620:fe::fe" "2620:fe::9"
        ];
      };
    };
  };
}
