# earlyoom — early OOM killer that prevents system freezes under memory pressure.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.services.earlyoom;
    in
    {
      _class = "nixos";
      options.myModules.services.earlyoom = {
        enable = lib.mkEnableOption "Early OOM killer (prevents system freezes)";

        memoryThreshold = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Minimum free memory percentage before killing";
        };

        swapThreshold = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Minimum free swap percentage before killing";
        };

        preferRegex = lib.mkOption {
          type = lib.types.str;
          default = "^(Web Content|Isolated Web|firefox|chromium|steam|gamescope)$";
          description = ''
            Regex matching process names that earlyoom should preferentially kill
            under memory pressure. Per-host overridable so low-RAM hosts (e.g.
            MBP 9,2) can include nix-daemon, build compilers, and editors that
            commonly trigger OOM cascades.
          '';
        };

        avoidRegex = lib.mkOption {
          type = lib.types.str;
          default = "^(sshd|systemd|Xorg|Xwayland|kwin|plasmashell|pipewire|wireplumber)$";
          description = "Regex matching process names earlyoom must never kill.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Disable systemd-oomd — earlyoom handles OOM with smarter prefer/avoid lists
        systemd.oomd.enable = false;

        services.earlyoom = {
          enable = true;
          freeMemThreshold = cfg.memoryThreshold;
          freeSwapThreshold = cfg.swapThreshold;
          enableNotifications = true;
          extraArgs = [
            "--prefer"
            cfg.preferRegex
            "--avoid"
            cfg.avoidRegex
          ];
        };
      };
    };
in
{
  flake.modules.nixos.services-earlyoom = mod;

}
