# etc-overlay — /etc as an immutable erofs lower + writable upper overlay.
#
# Removes the per-activation /etc symlink rebuild from every boot. The
# lower layer holds ONLY environment.etc-managed entries, so anything a
# service creates under /etc at runtime is hidden the moment the overlay
# mounts: password hashes, machine identity, ssh host keys, LUKS
# keyfiles. The assertions below make that loss unrepresentable -- a
# system that still keeps load-bearing runtime state in /etc refuses to
# build with the overlay on. Activate only via nrb --boot + reboot (a
# live switch overmounts the running system's /etc mid-session), and
# purge stale /.rw-etc residue from earlier attempts first: upper
# entries shadow the lower layer.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.boot.etcOverlay;
      btrbk = config.myModules.storage.btrbk;
    in
    {
      _class = "nixos";
      options.myModules.boot.etcOverlay = {
        enable = lib.mkEnableOption "/etc as erofs + overlay (requires a runtime-state-free /etc; enforced by assertions)";
        mutable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Writable upper layer at /.rw-etc/upper on the root filesystem
            (survives reboots; runtime writes like NetworkManager profiles
            land there). false = fully immutable /etc.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        system.etc.overlay = {
          enable = true;
          inherit (cfg) mutable;
        };

        assertions = [
          {
            assertion = !config.users.mutableUsers;
            message = "myModules.boot.etcOverlay: mutable password hashes live only in /etc/shadow, which the overlay hides (login is lost) -- enable myModules.users.passwordFromSite so users.mutableUsers = false with a declarative hash";
          }
          {
            assertion = config.environment.etc ? machine-id;
            message = "myModules.boot.etcOverlay: /etc/machine-id is runtime-created and would regenerate under the overlay (identity fork, journal split) -- pin it from the site registry in hardware-configuration.nix";
          }
          {
            assertion = lib.all (k: !lib.hasPrefix "/etc/" k.path) config.services.openssh.hostKeys;
            message = "myModules.boot.etcOverlay: sshd host keys under /etc would be hidden and regenerate (agenix identity + registry pins lost) -- security-ssh relocates them to /var/lib/ssh";
          }
          {
            assertion =
              !btrbk.enable || btrbk.targetDrive == null || !lib.hasPrefix "/etc/" btrbk.targetDrive.keyFile;
            message = "myModules.boot.etcOverlay: the backup drive keyfile under /etc would be hidden by the overlay -- point myModules.storage.btrbk.targetDrive.keyFile at /var/lib/secrets";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.boot-etc-overlay = mod;

}
