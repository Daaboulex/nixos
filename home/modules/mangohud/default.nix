# mangohud — Vulkan/OpenGL performance overlay with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.mangohud;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
  # Strip '#' prefix for MangoHud (expects RRGGBB, not #RRGGBB)
  stripHash = s: lib.removePrefix "#" s;
in
{
  options.myModules.home.mangohud = {
    enable = lib.mkEnableOption "MangoHud Vulkan overlay";
    settings = myLib.mkSettingsOption {
      description = "Overrides merged over MangoHud defaults (fps_limit, position, etc.).";
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Default off — enable per-game via Steam launch options or MANGOHUD=1
      (myLib.mkSessionVars { MANGOHUD = lib.mkDefault "0"; })
      {
        programs.mangohud = myLib.mergeSettings {
          defaults = {
            enable = true;
          }
          // lib.optionalAttrs hasTheme {
            settings = {
              text_color = lib.mkDefault (stripHash c.foreground);
              gpu_color = lib.mkDefault (stripHash c.blue);
              cpu_color = lib.mkDefault (stripHash c.red);
              vram_color = lib.mkDefault (stripHash c.green);
              ram_color = lib.mkDefault (stripHash c.orange);
              engine_color = lib.mkDefault (stripHash c.purple);
              io_color = lib.mkDefault (stripHash c.blue-alt);
              frametime_color = lib.mkDefault (stripHash c.green);
              background_color = lib.mkDefault (stripHash c.background);
              media_player_color = lib.mkDefault (stripHash c.blue);
              wine_color = lib.mkDefault (stripHash c.purple);
              battery_color = lib.mkDefault (stripHash c.green);
              network_color = lib.mkDefault (stripHash c.blue-alt);
              background_alpha = lib.mkDefault 0.6;
            };
          };
          overrides = cfg.settings;
        };
      }
    ]
  );
}
