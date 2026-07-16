# agenix — age-encrypted secret deployment via host SSH identities.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.security.agenix;
      secretType = lib.types.submodule (
        { name, ... }:
        {
          options = {
            file = lib.mkOption {
              type = lib.types.path;
              default = cfg.secretsRoot + "/${name}.age";
              description = "Encrypted age file for `${name}`.";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Owner of the decrypted `${name}` secret.";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "Group of the decrypted `${name}` secret.";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
              description = "Permission mode for the decrypted `${name}` secret.";
            };
            path = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional absolute path for the decrypted `${name}` secret.";
            };
            symlink = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether agenix should expose `${name}` through a symlink.";
            };
          };
        }
      );
      renderSecret =
        _name: secret:
        {
          inherit (secret)
            file
            owner
            group
            mode
            symlink
            ;
        }
        // lib.optionalAttrs (secret.path != null) {
          inherit (secret) path;
        };
    in
    {
      _class = "nixos";
      options.myModules.security.agenix = {
        enable = lib.mkEnableOption "agenix secret management";
        identityPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Private identity files agenix may use to decrypt host secrets.
            Empty = follow services.openssh.hostKeys (ed25519), so the
            identity never drifts from where sshd actually keeps its keys.
          '';
        };
        secretsRoot = lib.mkOption {
          type = lib.types.path;
          # Secrets live in the private, never-pushed `site` registry — NOT in
          # this (public) repo. The encrypted *.age blobs sit beside the agenix
          # rules in repos/site/secrets/.
          default = inputs.site + /secrets;
          description = "Directory containing encrypted agenix secret files (private `site` registry).";
        };
        secrets = lib.mkOption {
          type = lib.types.attrsOf secretType;
          default = { };
          description = "Encrypted agenix secrets keyed by runtime secret name. Defaults each entry to `secretsRoot/<name>.age`.";
        };
      };

      config = lib.mkIf cfg.enable {
        age = {
          identityPaths =
            if cfg.identityPaths != [ ] then
              cfg.identityPaths
            else
              # agenix skips identity files that do not exist, so the legacy
              # /etc/ssh path is a free fallback: it carries hosts through
              # the /var/lib/ssh relocation (any ordering) and hosts that
              # never relocate.
              map (k: k.path) (lib.filter (k: k.type == "ed25519") config.services.openssh.hostKeys)
              ++ [ "/etc/ssh/ssh_host_ed25519_key" ];
          secrets = lib.mapAttrs renderSecret cfg.secrets;
        };

        environment.systemPackages = [
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
          pkgs.age
        ];
      };
    };
in
{
  flake.modules.nixos.security-agenix = mod;
}
