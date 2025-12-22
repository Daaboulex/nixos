{ lib, ... }:
let
  # Auto-discover all subdirectories with default.nix
  moduleDirs = builtins.attrNames (
    lib.filterAttrs 
      (n: v: v == "directory" && builtins.pathExists (./. + "/${n}/default.nix"))
      (builtins.readDir ./.)
  );
in {
  # ============================================================================
  # Global Module Options
  # ============================================================================
  options.myModules.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "user";
    description = "Primary system username used across all modules";
  };

  # ============================================================================
  # Auto-discovered Module Imports
  # ============================================================================
  # All subdirectories with a default.nix are automatically imported.
  # To add a new module, simply create: modules/<name>/default.nix
  imports = map (dir: ./${dir}) moduleDirs;
}
