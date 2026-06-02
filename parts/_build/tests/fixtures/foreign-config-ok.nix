# Fixture: a module writing only its OWN namespace. Must PASS.
{ config, lib, ... }:
{
  options.myModules.home.editor.enable = lib.mkEnableOption "editor";
  config = {
    myModules.home.editor.fontSize = 12;
  };
}
