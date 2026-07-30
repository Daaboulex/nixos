# coolercontrol — declarative fan/cooling configuration with optional GUI autostart.
{
  config,
  lib,
  pkgs,
  options,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.coolercontrol;
in
{
  options.myModules.home.coolercontrol = {
    enable = lib.mkEnableOption "CoolerControl declarative fan/cooling configuration";
    autostart = lib.mkEnableOption "CoolerControl GUI autostart at login";
    settings = myLib.mkSettingsOption {
      description = "CoolerControl settings merged over module defaults. Set per-host for hardware specifics.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = lib.optional (pkgs ? coolercontrol.coolerctl) pkgs.coolercontrol.coolerctl;
      }

      (lib.optionalAttrs (options.programs ? coolercontrol) {
        programs.coolercontrol = myLib.mergeSettings {
          defaults = {
            enable = true;
            url = lib.mkDefault "https://localhost:11987";
            # Leaf-level mkDefault: a whole-attrset wrapper here is silently
            # broken under mergeSettings (see lib/mergeSettings.nix).
            settings = {
              apply_on_boot = lib.mkDefault true;
              no_init = lib.mkDefault false;
              startup_delay = lib.mkDefault 2;
              thinkpad_full_speed = lib.mkDefault false;
              handle_dynamic_temps = lib.mkDefault false;
              liquidctl_integration = lib.mkDefault true;
              hide_duplicate_devices = lib.mkDefault true;
              compress = lib.mkDefault true;
              poll_rate = lib.mkDefault 1.0;
              drivetemp_suspend = lib.mkDefault true;
              allow_unencrypted = lib.mkDefault false;
            };
          };
          overrides = cfg.settings;
        };
      })

      (lib.mkIf cfg.autostart {
        xdg.configFile."autostart/coolercontrol.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=CoolerControl
          Exec=coolercontrol
          Icon=org.coolercontrol.CoolerControl
          X-KDE-autostart-phase=2
        '';
      })
    ]
  );
}
