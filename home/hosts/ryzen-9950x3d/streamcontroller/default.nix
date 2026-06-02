{ config, ... }:

{
  # Host-specific StreamController settings — merged over module defaults
  myModules.home.streamcontroller.settings = {
    enable = true;

    dataPath = "${config.home.homeDirectory}/.local/share/StreamController";

    assets = {
      "goxlr-utility-5.png" = ./assets/goxlr-utility-5.png;
      "icons8-crt-tv-96.png" = ./assets/icons8-crt-tv-96.png;
    };

    defaultPages."AL22K2C74512" = "Default";

    pages = {
      Default = {
        brightness.value = 100;
        keys = {
          "0x0".states."0".actions = [
            {
              id = "com_core447_Battery::BatteryPercentage";
              settings.device = "G502 LIGHTSPEED Wireless Gaming Mouse";
            }
          ];
          "1x0".states."0".actions = [
            {
              id = "com_core447_Battery::BatteryPercentage";
              settings.device = "Logitech G502";
            }
          ];
          "1x1".states."0" = {
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "goxlr-toggle";
              }
            ];
            media = {
              path = "${config.programs.streamcontroller.dataPath}/assets/goxlr-utility-5.png";
              size = 0.7;
            };
          };
          "2x1".states."0" = {
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "crt-toggle";
              }
            ];
            media = {
              path = "${config.programs.streamcontroller.dataPath}/assets/icons8-crt-tv-96.png";
              size = 0.7;
            };
          };
          "0x2".states."0".actions = [
            {
              id = "com_core447_MediaPlugin::Previous";
              settings = {
                show_label = true;
                show_thumbnail = true;
              };
            }
          ];
          "1x2".states."0".actions = [
            {
              id = "com_core447_MediaPlugin::PlayPause";
              settings = {
                show_label = true;
                show_thumbnail = true;
              };
            }
          ];
          "2x2".states."0".actions = [
            {
              id = "com_core447_MediaPlugin::Next";
              settings = {
                show_label = true;
                show_thumbnail = true;
              };
            }
          ];
        };
      };

    };
  };
}
