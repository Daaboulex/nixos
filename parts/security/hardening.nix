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

      nrb-activate = pkgs.writeShellApplication {
        name = "nrb-activate";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.nix
        ];
        text = ''
          set -euo pipefail

          usage() {
            echo "Usage: nrb-activate {set-profile|switch|boot|test} /nix/store/<hash>-nixos-system-*" >&2
            exit 1
          }

          [[ $# -eq 2 ]] || usage

          action="$1"
          store_path="$2"

          # Validate action
          case "$action" in
            set-profile|switch|boot|test) ;;
            *) echo "nrb-activate: invalid action '$action'" >&2; exit 1 ;;
          esac

          # Validate store path: must be a real /nix/store path, not a symlink chain
          # that resolves elsewhere
          real_path=$(readlink -f "$store_path")
          if [[ "$real_path" != /nix/store/* ]]; then
            echo "nrb-activate: path does not resolve to /nix/store/" >&2
            exit 1
          fi

          # Validate NixOS system closure naming convention
          basename=$(basename "$real_path")
          if [[ ! "$basename" =~ ^[a-z0-9]{32}-nixos-system-.+ ]]; then
            echo "nrb-activate: not a NixOS system closure: $basename" >&2
            exit 1
          fi

          # Validate the closure has the expected structure
          if [[ ! -x "$real_path/bin/switch-to-configuration" ]]; then
            echo "nrb-activate: missing bin/switch-to-configuration in $real_path" >&2
            exit 1
          fi
          if [[ ! -e "$real_path/nixos-version" ]]; then
            echo "nrb-activate: missing nixos-version in $real_path" >&2
            exit 1
          fi

          # Verify store path integrity — re-hashes contents against NAR hash
          # in the nix DB. Catches tampered store paths.
          verify_rc=0
          timeout 30 nix store verify --no-trust "$real_path" 2>/dev/null || verify_rc=$?
          if (( verify_rc == 124 )); then
            echo "nrb-activate: store verify timed out (30s) for $real_path — try when I/O is idle" >&2
            exit 1
          elif (( verify_rc != 0 )); then
            echo "nrb-activate: store integrity check failed for $real_path" >&2
            exit 1
          fi

          case "$action" in
            set-profile)
              exec nix-env -p /nix/var/nix/profiles/system --set "$real_path"
              ;;
            switch|boot|test)
              exec "$real_path/bin/switch-to-configuration" "$action"
              ;;
          esac
        '';
      };
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
                    command = "${nrb-activate}/bin/nrb-activate *";
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

        environment.systemPackages = [
          nrb-activate
        ]
        ++ lib.optionals cfg.firejail.enable [ pkgs.firejail ];
      };
    };
in
{
  flake.modules.nixos.security-hardening = mod;

}
