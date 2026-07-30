# goxlr-toggle — script for switching between active and sleep GoXLR profiles.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.goxlr.toggle;
in
{
  options.myModules.home.goxlr.toggle = {
    enable = lib.mkEnableOption "goxlr-toggle script for switching between active and sleep profiles";
    activeProfile = lib.mkOption {
      type = lib.types.str;
      default = "Default";
      description = "Device profile to load when waking (active state)";
    };
    activeMicProfile = lib.mkOption {
      type = lib.types.str;
      default = "Default";
      description = "Microphone profile to load when waking (active state)";
    };
    sleepProfile = lib.mkOption {
      type = lib.types.str;
      default = "Sleep";
      description = "Device profile to load when sleeping";
    };
    sleepMicProfile = lib.mkOption {
      type = lib.types.str;
      default = "Sleep";
      description = "Microphone profile to load when sleeping";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "goxlr-toggle" ''
        current=$(${pkgs.goxlr-utility}/bin/goxlr-client --status-json 2>/dev/null \
          | ${pkgs.python3}/bin/python3 -c "
        import json, sys
        d = json.load(sys.stdin)
        for m in d.get(\"mixers\", {}).values():
            print(m.get(\"profile_name\", \"\")); break
        " 2>/dev/null)

        # Inhibit the wake path unit from reverting this manual toggle
        touch /tmp/goxlr-toggle-inhibit

        if [ "$current" = "${cfg.sleepProfile}" ]; then
          ${pkgs.goxlr-utility}/bin/goxlr-client profiles device load "${cfg.activeProfile}"
          ${pkgs.goxlr-utility}/bin/goxlr-client profiles microphone load "${cfg.activeMicProfile}"
          echo "GoXLR -> Active (${cfg.activeProfile})"
        else
          ${pkgs.goxlr-utility}/bin/goxlr-client profiles device load "${cfg.sleepProfile}"
          ${pkgs.goxlr-utility}/bin/goxlr-client profiles microphone load "${cfg.sleepMicProfile}"
          echo "GoXLR -> Sleep (${cfg.sleepProfile})"
        fi
      '')
    ];
  };
}
