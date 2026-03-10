{ inputs, ... }: {
  flake.nixosModules.apps-arkenfox = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.security.arkenfox;
      downloadScript = pkgs.writeScriptBin "arkenfox-download" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        TARGET_DIR="${cfg.targetDir}"
        USER_JS_PATH="$TARGET_DIR/user.js"
        USER_OVERRIDES_PATH="$TARGET_DIR/user-overrides.js"
        URL="https://github.com/arkenfox/user.js/releases/latest/download/user.js"
        if [ ! -d "$TARGET_DIR" ]; then exit 1; fi
        if curl -L --fail -o "$USER_JS_PATH.tmp" "$URL"; then
          mv "$USER_JS_PATH.tmp" "$USER_JS_PATH"
        else
          rm -f "$USER_JS_PATH.tmp"
          if curl -L --fail -o "$USER_JS_PATH.tmp" "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"; then
            mv "$USER_JS_PATH.tmp" "$USER_JS_PATH"
          else
            exit 1
          fi
        fi
        if [ ! -f "$USER_OVERRIDES_PATH" ]; then echo "" > "$USER_OVERRIDES_PATH"; fi
        exit 0
      '';
    in {
      _class = "nixos";
      options.myModules.security.arkenfox = {
        enable = lib.mkEnableOption "Arkenfox Firefox security configuration";
        targetDir = lib.mkOption { type = lib.types.str; description = "Target directory for Firefox profile"; };
        user = lib.mkOption { type = lib.types.str; default = config.myModules.primaryUser; description = "User to run the service as"; };
        group = lib.mkOption { type = lib.types.str; default = "users"; description = "Group to run the service as"; };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.arkenfox-flatpak-download = {
          description = "Download Arkenfox user.js for Flatpak Firefox";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          path = [ pkgs.curl pkgs.coreutils pkgs.bash ];
          unitConfig.ConditionPathIsDirectory = cfg.targetDir;
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            TimeoutStartSec = "5min";
            ExecStart = "${downloadScript}/bin/arkenfox-download";
          };
        };

        systemd.timers.arkenfox-flatpak-download = {
          description = "Timer for Arkenfox user.js updates";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "1d";
            Persistent = true;
          };
        };
      };
    };
}
