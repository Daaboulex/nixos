# theme — unified palette + font source for downstream modules (Breeze Dark base).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.theme;

  palettes = {
    "breeze-dark" = {
      # Source: breeze-6.6.2 BreezeDark.colors (KDE official, installed in Nix store)

      # --- Backgrounds ---
      # Colors:View BackgroundNormal (deepest bg — editor/terminal content)
      background = "#141618";
      background-rgb = "20,22,24";
      # Colors:View BackgroundAlternate (alternating rows)
      background-alt = "#1d1f22";
      background-alt-rgb = "29,31,34";
      # Colors:Window BackgroundNormal (panels, dialogs)
      surface = "#202326";
      surface-rgb = "32,35,38";
      # Colors:Window/Button BackgroundAlternate
      surface-alt = "#292c30";
      surface-alt-rgb = "41,44,48";

      # --- Foregrounds ---
      # ForegroundNormal (all contexts)
      foreground = "#fcfcfc";
      foreground-rgb = "252,252,252";
      # ForegroundInactive
      foreground-dim = "#a1a9b1";
      foreground-dim-rgb = "161,169,177";
      # Selection ForegroundNormal
      foreground-selected = "#fcfcfc";

      # --- Semantic Colors ---
      # ForegroundActive / Selection BackgroundNormal (KDE accent blue)
      blue = "#3daee9";
      blue-rgb = "61,174,233";
      # ForegroundLink
      blue-alt = "#1d99f3";
      blue-alt-rgb = "29,153,243";
      # ForegroundNegative
      red = "#da4453";
      red-rgb = "218,68,83";
      # ForegroundNeutral
      orange = "#f67400";
      orange-rgb = "246,116,0";
      # ForegroundPositive
      green = "#27ae60";
      green-rgb = "39,174,96";
      # ForegroundVisited
      purple = "#9b59b6";
      purple-rgb = "155,89,182";
      # Comment / ghost text (midpoint between surface-alt and foreground-dim)
      comment = "#636c75";
      comment-rgb = "99,108,117";
      # Selection BackgroundNormal
      selection = "#3daee9";
      selection-rgb = "61,174,233";
      # Selection BackgroundAlternate
      selection-alt = "#1e5774";
      selection-alt-rgb = "30,87,116";

      # --- ANSI terminal color name mappings ---
      # For tools limited to named colors. These correspond to how our Konsole
      # BreezeDark-Custom scheme maps ANSI color slots to the palette.
      # If the palette changes, update these to match the new Konsole mapping.
      blue-ansi = "blue";
      red-ansi = "red";
      green-ansi = "green";
      orange-ansi = "yellow"; # ANSI has no orange — yellow is the closest slot
      purple-ansi = "magenta"; # ANSI has no purple — magenta is the closest slot
      blue-alt-ansi = "cyan";
      foreground-dim-ansi = "white"; # ANSI white = Color7 = our foreground-dim in Konsole
      comment-ansi = "black"; # ANSI bright-black (color 8) is closest, but "black" is safer across tools
    };
  };
in
{
  options.myModules.home.theme = {
    enable = lib.mkEnableOption "unified theme (palette, font)";

    palette = lib.mkOption {
      type = lib.types.enum (builtins.attrNames palettes);
      default = "breeze-dark";
      description = "Active color palette name.";
    };

    colors = {
      background = lib.mkOption {
        type = lib.types.str;
        description = "Primary background color (hex).";
      };
      background-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Primary background color (R,G,B decimal — for KDE colorscheme format).";
      };
      background-alt = lib.mkOption {
        type = lib.types.str;
        description = "Alternate background color (hex).";
      };
      background-alt-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Alternate background color (R,G,B decimal).";
      };
      surface = lib.mkOption {
        type = lib.types.str;
        description = "Surface/panel background color (hex).";
      };
      surface-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Surface/panel background color (R,G,B decimal).";
      };
      surface-alt = lib.mkOption {
        type = lib.types.str;
        description = "Alternate surface background color (hex).";
      };
      surface-alt-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Alternate surface background color (R,G,B decimal).";
      };
      foreground = lib.mkOption {
        type = lib.types.str;
        description = "Primary foreground/text color (hex).";
      };
      foreground-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Primary foreground/text color (R,G,B decimal).";
      };
      foreground-dim = lib.mkOption {
        type = lib.types.str;
        description = "Dimmed/inactive foreground color (hex).";
      };
      foreground-dim-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Dimmed/inactive foreground color (R,G,B decimal).";
      };
      foreground-selected = lib.mkOption {
        type = lib.types.str;
        description = "Foreground color for selected items (hex).";
      };
      blue = lib.mkOption {
        type = lib.types.str;
        description = "Accent blue color (hex).";
      };
      blue-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Accent blue color (R,G,B decimal).";
      };
      blue-alt = lib.mkOption {
        type = lib.types.str;
        description = "Alternate blue / link color (hex).";
      };
      blue-alt-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Alternate blue / link color (R,G,B decimal).";
      };
      red = lib.mkOption {
        type = lib.types.str;
        description = "Error/negative color (hex).";
      };
      red-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Error/negative color (R,G,B decimal).";
      };
      orange = lib.mkOption {
        type = lib.types.str;
        description = "Warning/neutral color (hex).";
      };
      orange-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Warning/neutral color (R,G,B decimal).";
      };
      green = lib.mkOption {
        type = lib.types.str;
        description = "Success/positive color (hex).";
      };
      green-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Success/positive color (R,G,B decimal).";
      };
      purple = lib.mkOption {
        type = lib.types.str;
        description = "Visited/special color (hex).";
      };
      purple-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Visited/special color (R,G,B decimal).";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        description = "Comment / ghost text / autosuggestion color (hex).";
      };
      comment-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Comment / ghost text / autosuggestion color (R,G,B decimal).";
      };
      selection = lib.mkOption {
        type = lib.types.str;
        description = "Selection background color (hex).";
      };
      selection-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Selection background color (R,G,B decimal).";
      };
      selection-alt = lib.mkOption {
        type = lib.types.str;
        description = "Alternate selection background color (hex).";
      };
      selection-alt-rgb = lib.mkOption {
        type = lib.types.str;
        description = "Alternate selection background color (R,G,B decimal).";
      };

      # --- ANSI terminal color name mappings ---
      # For tools that only accept named colors (nano, gdb, ripgrep, etc.)
      # Each maps a semantic palette color to its ANSI slot in the Konsole scheme.
      blue-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for blue (accent). Matches Konsole Color4 slot.";
      };
      red-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for red (error). Matches Konsole Color1 slot.";
      };
      green-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for green (success). Matches Konsole Color2 slot.";
      };
      orange-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for orange (warning). Matches Konsole Color3/yellow slot.";
      };
      purple-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for purple (special). Matches Konsole Color5/magenta slot.";
      };
      blue-alt-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for blue-alt (secondary). Matches Konsole Color6/cyan slot.";
      };
      foreground-dim-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for dim text. Matches Konsole Color7/white slot.";
      };
      comment-ansi = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name for comment/ghost text. Closest available ANSI slot.";
      };
    };

    font.family = lib.mkOption {
      type = lib.types.str;
      default = "Hack Nerd Font";
      description = "Monospace font family name for all terminal tools.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      pal = palettes.${cfg.palette};
    in
    {
      home.packages = [ pkgs.nerd-fonts.hack ];

      myModules.home.theme.colors = lib.mapAttrs (_: v: lib.mkDefault v) pal;
    }
  );
}
