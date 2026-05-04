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
# `c` is the colour palette when the theme is enabled, `{}` otherwise. The
# `when` helper is shorthand for `lib.optionalAttrs hasTheme`:
#
#   xdg.configFile."foo".text = when {
#     colour = c.blue;
#     ...
#   };
#
# Modules may opt in to `.when` gradually; existing `lib.optionalAttrs hasTheme`
# callsites remain valid.
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
  when = attrs: if hasTheme then attrs else { };
}
