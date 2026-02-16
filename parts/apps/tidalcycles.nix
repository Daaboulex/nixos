{ inputs, ... }: {
  flake.nixosModules.apps-tidalcycles = { config, lib, pkgs, ... }: {
    options.myModules.music.tidalcycles = {
      enable = lib.mkEnableOption "Enable TidalCycles and SuperDirt";
      autostartSuperDirt = lib.mkOption { type = lib.types.bool; default = false; };
    };

    config = lib.mkIf config.myModules.music.tidalcycles.enable {
      environment.systemPackages = with pkgs; [ tidal superdirt-start superdirt-install ];
      services.pipewire = { enable = true; pulse.enable = true; jack.enable = true; };
      
      systemd.user.services.superdirt-start = lib.mkIf config.myModules.music.tidalcycles.autostartSuperDirt {
        description = "Start SuperDirt (SuperCollider)";
        wantedBy = [ "default.target" ];
        after = [ "default.target" ];
        serviceConfig = { Type = "simple"; ExecStart = "${pkgs.superdirt-start}/bin/superdirt-start"; Restart = "on-failure"; };
      };
    };
  };
}
