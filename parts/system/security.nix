{ inputs, ... }: {
  flake.nixosModules.system-security = { config, lib, pkgs, ... }: 
    let
    in {
        options.myModules.security.system = {
        enable = lib.mkEnableOption "System-wide security hardening";
        firejail.enable = lib.mkOption { type = lib.types.bool; default = false; description = "Enable Firejail sandboxing"; };
      };

      config = lib.mkIf config.myModules.security.system.enable {
        security.rtkit.enable = true;
        
        security.pam.loginLimits = [
          { domain = "@audio"; type = "soft"; item = "rtprio"; value = 95; }
          { domain = "@audio"; type = "hard"; item = "rtprio"; value = 99; }
          { domain = "@audio"; type = "soft"; item = "memlock"; value = -1; }
          { domain = "@audio"; type = "hard"; item = "memlock"; value = -1; }
          { domain = "@wheel"; type = "-"; item = "rtprio"; value = 99; }
          { domain = "@wheel"; type = "-"; item = "nice"; value = -20; }
        ];

        security.sudo = { enable = true; wheelNeedsPassword = true; };
        security.polkit.enable = true;
        security.pam.services.login.limits = [ { domain = "*"; type = "hard"; item = "core"; value = 0; } ];
        
        environment.systemPackages = with pkgs; [ gnupg pinentry-gtk2 ] ++ lib.optionals config.myModules.security.system.firejail.enable [ firejail ];
      };
    };
}
