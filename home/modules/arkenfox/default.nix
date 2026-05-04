# arkenfox — auto-download Arkenfox user.js for Firefox security hardening.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.arkenfox;
  downloadScript = pkgs.writeScriptBin "arkenfox-download" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    TARGET_DIR="${cfg.targetDir}"
    USER_JS_PATH="$TARGET_DIR/user.js"
    USER_OVERRIDES_PATH="$TARGET_DIR/user-overrides.js"
    URL="https://github.com/arkenfox/user.js/releases/latest/download/user.js"
    if [ ! -d "$TARGET_DIR" ]; then echo "Target dir not found, skipping"; exit 0; fi
    if ${pkgs.curl}/bin/curl -L --fail -o "$USER_JS_PATH.tmp" "$URL"; then
      mv "$USER_JS_PATH.tmp" "$USER_JS_PATH"
    else
      rm -f "$USER_JS_PATH.tmp"
      if ${pkgs.curl}/bin/curl -L --fail -o "$USER_JS_PATH.tmp" "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"; then
        mv "$USER_JS_PATH.tmp" "$USER_JS_PATH"
      else
        exit 1
      fi
    fi
    if [ ! -f "$USER_OVERRIDES_PATH" ]; then echo "" > "$USER_OVERRIDES_PATH"; fi
    exit 0
  '';
in
{
  options.myModules.home.arkenfox = {
    enable = lib.mkEnableOption "Arkenfox Firefox security configuration";
    targetDir = lib.mkOption {
      type = lib.types.str;
      description = "Target directory for Firefox profile";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.arkenfox-flatpak-download = {
      Unit = {
        Description = "Download Arkenfox user.js for Flatpak Firefox";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "5min";
        ExecStart = "${downloadScript}/bin/arkenfox-download";
      };
    };

    systemd.user.timers.arkenfox-flatpak-download = {
      Unit.Description = "Timer for Arkenfox user.js updates";
      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1d";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
