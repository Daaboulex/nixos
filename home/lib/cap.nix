# cap — capitalize first letter of a string.
#
# Usage:
#   myLib.cap "blue"  → "Blue"
#
# Consumed by HM modules that match ANSI colour names against upstream
# tool config keys expecting capitalized strings (eza field colours,
# tealdeer section keys, csvlens column colours).
{ lib }:
s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (builtins.stringLength s - 1) s
