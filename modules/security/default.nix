{ config, pkgs, lib, ... }:
let
  hostName = config.networking.hostName;
  isAlienware = hostName == "alienware-r7";
in {
  options.myModules.security.system.enable = lib.mkEnableOption "System security settings";
  config = lib.mkIf config.myModules.security.system.enable {
    security.rtkit.enable = true;
    security.pam.loginLimits = [
      { domain = "@audio"; type = "soft"; item = "rtprio"; value = 95; }
      { domain = "@audio"; type = "hard"; item = "rtprio"; value = 99; }
      { domain = "@audio"; type = "soft"; item = "memlock"; value = -1; }
      { domain = "@audio"; type = "hard"; item = "memlock"; value = -1; }
      # Allow wheel group real-time priority (fixes SDDM/KWin CAP_SYS_NICE warnings)
      { domain = "@wheel"; type = "-"; item = "rtprio"; value = 99; }
      { domain = "@wheel"; type = "-"; item = "nice"; value = -20; }
    ] ++ lib.optionals isAlienware [
      { domain = "@gamemode"; type = "soft"; item = "nice"; value = -10; }
      { domain = "@gamemode"; type = "hard"; item = "nice"; value = -10; }
    ];
    security.sudo = { enable = true; wheelNeedsPassword = true; };
    security.polkit.enable = true;
    security.pam.services.login.limits = [ { domain = "*"; type = "hard"; item = "core"; value = 0; } ];
    environment.systemPackages = with pkgs; [ gnupg pinentry-gtk2 ] ++ lib.optionals isAlienware [ firejail ];
  };
}
# Security settings: rtkit, sudo/polkit, PAM limits (single owner of rtkit)
# Example: raise audio rtprio in pam.loginLimits if needed