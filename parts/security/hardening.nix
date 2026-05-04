# hardening — system-wide security hardening (kernel, sysctl, AppArmor).
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
        security = {
          rtkit.enable = true;
          polkit.enable = true;
          sudo = {
            enable = true;
            wheelNeedsPassword = true;
            extraRules = [
              {
                users = [ config.myModules.primaryUser ];
                commands = [
                  {
                    command = "/run/current-system/sw/bin/true";
                    options = [ "NOPASSWD" ];
                  }
                  {
                    command = "/run/current-system/sw/bin/nix-env -p /nix/var/nix/profiles/system --set /nix/store/*";
                    options = [ "NOPASSWD" ];
                  }
                  {
                    command = "/nix/store/*/bin/switch-to-configuration *";
                    options = [ "NOPASSWD" ];
                  }
                ];
              }
            ];
          };
          # @audio rtprio is handled by myModules.tuning.cachyos (CachyOS upstream)
          pam = {
            loginLimits = [
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
            services.login.limits = [
              {
                domain = "*";
                type = "hard";
                item = "core";
                value = 0;
              }
            ];
          };
        };

        boot.kernel.sysctl = {
          "kernel.yama.ptrace_scope" = lib.mkDefault 1;
          "kernel.kptr_restrict" = lib.mkDefault 1;
          "kernel.unprivileged_bpf_disabled" = lib.mkDefault 1;
          "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
          "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
          "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
          "net.ipv6.conf.all.accept_redirects" = lib.mkDefault 0;
          "net.ipv4.conf.all.send_redirects" = lib.mkDefault 0;
          "net.ipv4.conf.all.log_martians" = lib.mkDefault 1;
          "net.ipv4.tcp_syncookies" = lib.mkDefault 1;
        };

        environment.systemPackages = lib.optionals cfg.firejail.enable [ pkgs.firejail ];
      };
    };
in
{
  flake.modules.nixos.security-hardening = mod;

}
