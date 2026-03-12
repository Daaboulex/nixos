{ inputs, ... }:
{
  flake.nixosModules.sysdiag =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules;
      scriptText = import ./sysdiag-script.nix { inherit pkgs; };
      sysdiag = pkgs.writeShellScriptBin "sysdiag" scriptText;
    in
    {
      _class = "nixos";
      options.myModules.sysdiag = lib.mkEnableOption "sysdiag system diagnostics";

      config = lib.mkIf cfg.sysdiag {
        environment.systemPackages = [ sysdiag ];
      };
    };
}
