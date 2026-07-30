# mullvad — thin wrapper over Daaboulex/mullvad-vpn-nix nixosModules.default.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.services.mullvad;
    in
    {
      _class = "nixos";
      imports = [ inputs.mullvad-vpn-nix.nixosModules.default ];

      options.myModules.services.mullvad = {
        enable = lib.mkEnableOption "Mullvad VPN — declarative daemon settings";
        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = ''
            Forwarded to `services.mullvad-vpn-declarative.settings`.
            See Daaboulex/mullvad-vpn-nix README for option reference.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.mullvad-vpn-declarative = {
          enable = true;
          inherit (cfg) settings;
        };
      };
    };
in
{
  flake.modules.nixos.services-mullvad = mod;
}
