{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.development.antigravity;
  
  # Update script that runs before nixos-rebuild (for manual use)
  antigravityUpdateScript = pkgs.writeShellScriptBin "antigravity-update" ''
    #!/usr/bin/env bash
    # Auto-update Google Antigravity to latest version
    set -euo pipefail
    
    # Module location (auto-detected from flake)
    FLAKE_DIR="/home/user/Documents/nix/modules/antigravity"
    
    if [[ ! -d "$FLAKE_DIR" ]]; then
      echo "Error: Antigravity module directory not found at $FLAKE_DIR"
      exit 1
    fi
    
    cd "$FLAKE_DIR"
    
    if [[ -x "$FLAKE_DIR/scripts/update-version.sh" ]]; then
      echo "Checking for Antigravity updates..."
      "$FLAKE_DIR/scripts/update-version.sh" || true
    else
      echo "Update script not found at $FLAKE_DIR/scripts/update-version.sh"
    fi
  '';
in
{
  options.myModules.development.antigravity.enable = lib.mkEnableOption "Google Antigravity IDE";
  
  options.myModules.development.antigravity.browser = lib.mkOption {
    type = lib.types.enum [ "google-chrome" "ungoogled-chromium" "disabled" ];
    default = "ungoogled-chromium";
    description = "Browser to use with Antigravity (google-chrome, ungoogled-chromium, or disabled)";
  };
  
  options.myModules.development.antigravity.autoUpdate = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable automatic update checks via systemd timer";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ 
      (google-antigravity.override {
        google-chrome = if cfg.browser == "google-chrome" then google-chrome else null;
        ungoogled-chromium = if cfg.browser == "ungoogled-chromium" then ungoogled-chromium else null;
      })
      # Manual update helper script
      antigravityUpdateScript
    ];
    
    # Systemd timer to check for updates daily
    systemd.user.services.antigravity-update = lib.mkIf cfg.autoUpdate {
      description = "Check for Antigravity IDE updates";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${antigravityUpdateScript}/bin/antigravity-update";
      };
    };
    
    systemd.user.timers.antigravity-update = lib.mkIf cfg.autoUpdate {
      description = "Daily Antigravity update check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}