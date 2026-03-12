{ inputs, ... }:
{
  flake.nixosModules.tidalcycles =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.tidalcycles;
    in
    {
      _class = "nixos";
      options.myModules.tidalcycles = {
        enable = lib.mkEnableOption "TidalCycles and SuperDirt";
        autostartSuperDirt = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-start SuperDirt (SuperCollider) as a systemd user service";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
          tidal
          superdirt-start
          superdirt-install
        ];
        services.pipewire = {
          enable = true;
          pulse.enable = true;
          jack.enable = true;
        };

        systemd.user.services.superdirt-start = lib.mkIf cfg.autostartSuperDirt {
          description = "Start SuperDirt (SuperCollider)";
          wantedBy = [ "default.target" ];
          after = [ "default.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.superdirt-start}/bin/superdirt-start";
            Restart = "on-failure";
          };
        };
      };
    };
}
