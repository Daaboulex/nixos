{ inputs, ... }:
{
  flake.nixosModules.diagnostics-sysdiag =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.diagnostics.sysdiag;
      scriptText = import ../sysdiag-script.nix { inherit pkgs; };
      sysdiag = pkgs.writeShellScriptBin "sysdiag" scriptText;
    in
    {
      _class = "nixos";
      options.myModules.diagnostics.sysdiag = {
        enable = lib.mkEnableOption "sysdiag system diagnostics";
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ sysdiag ];
      };
    };
}
