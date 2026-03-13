{ config, ... }:

{
  # --------------------------------------------------------------------------
  # StreamController — Stream Deck configuration
  # --------------------------------------------------------------------------
  # Device: AL22K2C74512 (Stream Deck)
  # HM module (streamcontroller-nix) generates JSON pages and deploys assets.
  # --------------------------------------------------------------------------
  programs.streamcontroller = {
    enable = true;

    # Flatpak data directory (switch to default when migrating to native package)
    dataPath = "${config.home.homeDirectory}/.var/app/com.core447.StreamController/data";

    assets = {
      "goxlr-utility-5.png" = ./streamcontroller-assets/goxlr-utility-5.png;
      "icons8-crt-tv-96.png" = ./streamcontroller-assets/icons8-crt-tv-96.png;
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

      vkbasalt = {
        brightness.value = 75;
        extraConfig.auto-change = {
          enable = true;
          wm_class = "";
          title = "";
          stay_on_page = true;
          decks = [ "AL22K2C74512" ];
        };
        keys = {
          "0x0".states."0" = {
            label.center.text = "Toggle Effects";
            actions = [
              {
                id = "com_core447_OSPlugin::Hotkey";
                settings.keys = [
                  [
                    119
                    1
                  ]
                  [
                    119
                    0
                  ]
                ];
              }
            ];
          };
          "0x1".states."0" = {
            label = {
              top.text = "Sharpen";
              center.text = "+";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl sharpen-up";
              }
            ];
          };
          "1x1".states."0" = {
            label = {
              top.text = "Sharpen";
              center.text = "-";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl sharpen-down";
              }
            ];
          };
          "0x2".states."0" = {
            label = {
              top.text = "Vibrance";
              center.text = "+";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl vibrance-up";
              }
            ];
          };
          "1x2".states."0" = {
            label = {
              top.text = "Vibrance";
              center.text = "-";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl vibrance-down";
              }
            ];
          };
          "2x0".states."0" = {
            label = {
              top.text = "Lift";
              center.text = "+";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl lift-up";
              }
            ];
          };
          "3x0".states."0" = {
            label = {
              top.text = "Lift";
              center.text = "-";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl lift-down";
              }
            ];
          };
          "2x1".states."0" = {
            label = {
              top.text = "Gain";
              center.text = "+";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl gain-up";
              }
            ];
          };
          "3x1".states."0" = {
            label = {
              top.text = "Gain";
              center.text = "-";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl gain-down";
              }
            ];
          };
          "2x2".states."0" = {
            label = {
              top.text = "Gamma";
              center.text = "+";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl gamma-up";
              }
            ];
          };
          "3x2".states."0" = {
            label = {
              top.text = "Gamma";
              center.text = "-";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl gamma-down";
              }
            ];
          };
          "4x1".states."0" = {
            label = {
              top.text = "Show";
              center.text = "Settings";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings = {
                  command = "vkbasalt-ctl show";
                  display_output = true;
                  detached = false;
                };
              }
            ];
          };
          "4x2".states."0" = {
            label = {
              top.text = "Reset";
              center.text = "Settings";
            };
            actions = [
              {
                id = "com_core447_OSPlugin::RunCommand";
                settings.command = "vkbasalt-ctl reset";
              }
            ];
          };
          "4x0".states."0".actions = [
            {
              id = "com_core447_DeckPlugin::ChangePage";
              settings = {
                selected_page = "${config.programs.streamcontroller.dataPath}/pages/Default.json";
                deck_number = "AL22K2C74512";
              };
            }
          ];
        };
      };
    };
  };
}
