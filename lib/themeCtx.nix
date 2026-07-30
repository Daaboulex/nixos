# themeCtx — gathered theme context for HM modules.
#
# Collapses the 3-line boilerplate that opens 30 themed HM modules:
#
#   themeCfg = config.myModules.home.theme;
#   hasTheme = themeCfg.enable or false;
#   c = themeCfg.colors;
#
# into a single import:
#
#   inherit (myLib.themeCtx { inherit config; }) hasTheme c;
#
# `c` is the colour palette when the theme is enabled, `{}` otherwise.
{ config }:
let
  themeCfg = config.myModules.home.theme;
  hasTheme = themeCfg.enable or false;
  colors = if hasTheme then themeCfg.colors else { };
in
{
  inherit hasTheme;
  c = colors;
  # Raw theme attrset — access to `.font.family`, `.colors` (as-declared), etc.
  theme = themeCfg;
}
