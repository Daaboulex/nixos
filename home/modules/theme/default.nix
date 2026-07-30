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

    # One option per palette key — generated, so the option set and the
    # palette can never drift apart (an unknown key still fails eval). Value
    # format is encoded in the name suffix; each color's KDE role is
    # documented at its palette definition above.
    colors = lib.genAttrs (builtins.attrNames palettes.breeze-dark) (
      name:
      lib.mkOption {
        type = lib.types.str;
        description =
          if lib.hasSuffix "-rgb" name then
            "Palette color ${name} (R,G,B decimal — KDE colorscheme format)."
          else if lib.hasSuffix "-ansi" name then
            "Palette color ${name} (named ANSI slot, per the Konsole scheme mapping)."
          else
            "Palette color ${name} (hex).";
      }
    );

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
