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
            settings = lib.mkDefault {
              apply_on_boot = true;
              no_init = false;
              startup_delay = 2;
              thinkpad_full_speed = false;
              handle_dynamic_temps = false;
              liquidctl_integration = true;
              hide_duplicate_devices = true;
              compress = true;
              poll_rate = 1.0;
              drivetemp_suspend = true;
              allow_unencrypted = false;
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
