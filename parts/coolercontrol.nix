{ inputs, ... }:
{
  flake.nixosModules.coolercontrol =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.coolercontrol;
    in
    {
      _class = "nixos";

      options.myModules.coolercontrol = {
        enable = lib.mkEnableOption "CoolerControl fan and cooling device management";
        autostart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to autostart the CoolerControl GUI at login via XDG autostart";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.coolercontrol.enable = true;

        # XDG autostart for the GUI desktop application
        # The nixpkgs module only starts the daemon (coolercontrold) — the GUI
        # needs an autostart entry to launch at login.
        environment.etc."xdg/autostart/coolercontrol.desktop" = lib.mkIf cfg.autostart {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=CoolerControl
            Exec=coolercontrol
            Icon=org.coolercontrol.CoolerControl
            X-KDE-autostart-phase=2
          '';
        };
      };
    };
}
