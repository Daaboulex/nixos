# Fixture: a module writing into ANOTHER module's namespace.
# check-no-foreign-config MUST flag it (dendritic-invariant violation).
{ config, lib, ... }:
{
  options.myModules.home.editor.enable = lib.mkEnableOption "editor";
  config = {
    myModules.home.konsole.gpuAcceleration = true;
  };
}
