{ config, pkgs, lib, ... }:
{
  options.myModules.music.tidalcycles.enable = lib.mkEnableOption "Enable TidalCycles and SuperDirt tools";
  options.myModules.music.tidalcycles.autostartSuperDirt = lib.mkOption { type = lib.types.bool; default = false; };
  
  config = lib.mkIf config.myModules.music.tidalcycles.enable {
    environment.systemPackages = with pkgs; [ tidal superdirt-start superdirt-install ];
    
    # Audio configuration for SuperDirt
    services.pipewire.enable = true;
    services.pipewire.pulse.enable = true;
    services.pipewire.jack.enable = true;
    
    systemd.user.services.superdirt-start = lib.mkIf config.myModules.music.tidalcycles.autostartSuperDirt {
      description = "Start SuperDirt (SuperCollider)";
      wantedBy = [ "default.target" ];
      after = [ "default.target" ];
      serviceConfig = { Type = "simple"; ExecStart = "${pkgs.superdirt-start}/bin/superdirt-start"; Restart = "on-failure"; };
    };
  };
}
# TidalCycles Module
# Provides TidalCycles and SuperDirt (SuperCollider)
# Editor integration removed (use manual setup if needed)