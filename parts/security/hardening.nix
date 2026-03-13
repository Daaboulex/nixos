{ inputs, ... }:
{
  flake.nixosModules.security-hardening =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.security.hardening;
    in
    {
      _class = "nixos";
      options.myModules.security.hardening = {
        enable = lib.mkEnableOption "System-wide security hardening";
        firejail.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Firejail sandboxing";
        };
      };

      config = lib.mkIf cfg.enable {
        security.rtkit.enable = true;

        # @audio rtprio is handled by myModules.system.cachyos (CachyOS upstream)
        security.pam.loginLimits = [
          {
            domain = "@audio";
            type = "soft";
            item = "memlock";
            value = -1;
          }
          {
            domain = "@audio";
            type = "hard";
            item = "memlock";
            value = -1;
          }
          {
            domain = "@wheel";
            type = "-";
            item = "rtprio";
            value = 99;
          }
          {
            domain = "@wheel";
            type = "-";
            item = "nice";
            value = -20;
          }
        ];

        security.sudo = {
          enable = true;
          wheelNeedsPassword = true;
        };
        security.polkit.enable = true;
        security.pam.services.login.limits = [
          {
            domain = "*";
            type = "hard";
            item = "core";
            value = 0;
          }
        ];

        environment.systemPackages =
          with pkgs;
          [
            gnupg
            pinentry-gtk2
          ]
          ++ lib.optionals cfg.firejail.enable [ firejail ];
      };
    };
}
