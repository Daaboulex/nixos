# obsidian — Obsidian knowledge base editor.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "obsidian";
  description = "Obsidian knowledge base editor";
})
  args
