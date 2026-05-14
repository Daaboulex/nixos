# avahi — mDNS/zeroconf hostname resolution (.local) + service discovery.
#
# Enables avahi-daemon + wires NSS mdns4 so libc resolves `.local`
# names. Without this, SSH to `foo.local` returns "temporary failure
# in name resolution" because the libc nsswitch path doesn't try
# mDNS by default on NixOS.
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
      cfg = config.myModules.services.avahi;
    in
    {
      _class = "nixos";
      options.myModules.services.avahi = {
        enable = lib.mkEnableOption "Avahi mDNS/zeroconf daemon + NSS integration";
        publish = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this host advertises itself via mDNS. Default true
            so other LAN hosts can resolve us by `.local` name. Set
            false on hosts that shouldn't be discoverable.
          '';
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Open UDP port 5353 for mDNS multicast in the host firewall.
            Required for any mDNS interaction — both advertisement AND
            consumption rely on inbound multicast. Disabling this blocks
            other hosts' announcements too. To stop advertising while
            staying able to resolve `.local` names, set `publish = false`
            and keep `openFirewall = true`.
          '';
        };
      };
      config = lib.mkIf cfg.enable {
        services.avahi = {
          enable = true;
          nssmdns4 = true;
          inherit (cfg) openFirewall;
          publish = lib.mkIf cfg.publish {
            enable = true;
            addresses = true;
            hinfo = false;
            workstation = true;
            userServices = true;
          };
        };
      };
    };
in
{
  flake.modules.nixos.services-avahi = mod;
}
