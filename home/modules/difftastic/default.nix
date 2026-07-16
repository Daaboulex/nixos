# difftastic — structural, syntax-tree-aware diff (binary `difft`). Complements
# delta (delta is the line-based git pager); not aliased over classic `diff`.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "difftastic";
  description = "difftastic structural syntax-aware diff";
})
  args
