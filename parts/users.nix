# users — primary user account, groups, and shell configuration.
{ inputs, ... }:
let
  mod =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.users;
    in
    {
      _class = "nixos";
      options.myModules.users = {
        enable = lib.mkEnableOption "User configuration";

        passwordFromSite = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Fully declarative login: users.mutableUsers = false with the
            primary user's password hash decrypted by agenix from the site
            registry (secrets/user-password.age, created with
            `mkpasswd -m yescrypt`). Required by the etc overlay -- mutable
            hashes live only in /etc/shadow, which the overlay hides -- and
            gives a bare-metal install a working password on first boot.
            root stays locked: wheel + sudo covers admin; console rescue is
            the installer USB.
          '';
        };
      };

      options.myModules.primaryUser = lib.mkOption {
        type = lib.types.str;
        default = "user";
        description = "Primary system username used across all modules";
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (lib.mkIf cfg.passwordFromSite {
            # This module only READS config.age.secrets (lazy, safe without
            # agenix imported); the HOST declares the secret -- defining
            # age.* here would hard-couple every users-module consumer to
            # agenix (the standalone module evals break).
            assertions = [
              {
                # options-guard first: on a host without the agenix module
                # (e.g. the AVF VM) a bare config.age read would die with a
                # raw missing-option error instead of this message.
                assertion = (options ? age) && config.age.secrets ? user-password;
                message = "myModules.users: passwordFromSite needs agenix (security-agenix imported) and the `user-password` secret — add `myModules.security.agenix.secrets.user-password = { };` to this host.";
              }
              {
                assertion = builtins.pathExists (inputs.site + "/secrets/user-password.age");
                message = "myModules.users: passwordFromSite is on but the site registry has no secrets/user-password.age (mkpasswd -m yescrypt | age -e -a -r <host recipients> > repos/site/secrets/user-password.age, then bump the site input)";
              }
            ];
            users.mutableUsers = false;
            # Guarded so a missing declaration can never crash eval mid-way
            # through another module's assertion -- the assertion above is
            # the single, readable error channel for that misconfiguration.
            users.users.${config.myModules.primaryUser}.hashedPasswordFile = lib.mkIf (
              (options ? age) && config.age.secrets ? user-password
            ) config.age.secrets.user-password.path;
            # Locked deliberately: wheel + sudo is the admin path; a
            # declarative root hash would double the credential surface.
            users.users.root.hashedPassword = "!";
          })
          {
            programs.zsh.enable = true;

            users.groups = {
              networkmanager = { };
              wheel = { };
              video = { };
              input = { };
              disk = { };
              bluetooth = { };
              dialout = { };
              i2c = { };
            };

            users.users.${config.myModules.primaryUser} = {
              isNormalUser = true;
              uid = 1000;
              description = config.myModules.primaryUser;
              extraGroups = [
                "networkmanager"
                "wheel"
                "video"
                "input"
                "bluetooth"
                "dialout"
                "i2c"
              ];
              shell = pkgs.zsh;
            };
          }
        ]
      );
    };
in
{
  flake.modules.nixos.users = mod;

}
