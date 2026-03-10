{ inputs, ... }: {
  flake.nixosModules.system-sops = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.security.sops;
    in {
      _class = "nixos";
      options.myModules.security.sops = {
        enable = lib.mkEnableOption "sops-nix secret management";
        defaultSopsFile = lib.mkOption { type = lib.types.path; default = ../../secrets/secrets.yaml; description = "Default sops file"; };
        ageKeyFile = lib.mkOption { type = lib.types.str; default = "/var/lib/sops-nix/key.txt"; description = "Path to the age key file"; };
      };

      config = lib.mkIf cfg.enable {
        sops = {
          defaultSopsFile = cfg.defaultSopsFile;
          age.keyFile = cfg.ageKeyFile;
        };
        environment.systemPackages = [ pkgs.sops pkgs.age ];
      };
    };
}
