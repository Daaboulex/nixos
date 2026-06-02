# mullvad — thin wrapper over Daaboulex/mullvad-vpn-nix homeManagerModules.default.
{
  config,
  lib,
  inputs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.mullvad;
in
{
  # imports MUST be unconditional — cannot be inside mkIf
  imports = [ inputs.mullvad-vpn-nix.homeManagerModules.default ];

  options.myModules.home.mullvad = {
    enable = lib.mkEnableOption "Mullvad VPN GUI client (HM-managed gui_settings.json + optional autostart)";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Launch Mullvad GUI on session start (writes autostart .desktop entry).";
    };
    settings = myLib.mkSettingsOption {
      description = ''
        Forwarded to `programs.mullvad-vpn-gui.settings`.
        See Daaboulex/mullvad-vpn-nix README for option reference.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.mullvad-vpn-gui = {
      enable = true;
      inherit (cfg) autostart;
      inherit (cfg) settings;
    };
  };
}
