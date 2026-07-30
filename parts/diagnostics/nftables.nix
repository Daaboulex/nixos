# nftables CLI -- inspect the kernel's live nft state: the split-tunnel
# alias table, firewall chains, fail2ban sets. The netlink API needs
# CAP_NET_ADMIN, so real use pairs with sudo; the system-wide install
# keeps it on root's PATH.
_:
let
  mod =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.diagnostics.nftables;
    in
    {
      _class = "nixos";
      options.myModules.diagnostics.nftables.enable =
        lib.mkEnableOption "the nft CLI for inspecting live nftables rulesets";

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.nftables ];
      };
    };
in
{
  flake.modules.nixos.diagnostics-nftables = mod;
}
