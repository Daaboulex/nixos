{ lib, ... }:

{
  imports =
    let
      # Get all files/directories in the current directory
      files = builtins.readDir ./.;

      # Filter for directories that contain a default.nix
      hasDefault = name: type: type == "directory" && builtins.pathExists (./. + "/${name}/default.nix");

      # Map to import paths
      validModules = lib.filterAttrs hasDefault files;
      importPaths = lib.mapAttrsToList (name: _: ./. + "/${name}") validModules;
    in
    importPaths;
}
