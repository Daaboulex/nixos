{ inputs, ... }: {
  flake.nixosModules.hardware-networking = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.networking;
    in {
      _class = "nixos";
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
        nameservers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "9.9.9.9" "149.112.112.112" "2620:fe::fe" "2620:fe::9" ];
          description = "DNS nameservers (default: Quad9)";
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
          nameservers = cfg.nameservers;
        };
      };
    };
}
