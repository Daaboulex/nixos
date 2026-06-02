# kvmfr — KVMFR shared memory for Looking Glass frame relay (zero-copy host/guest display).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.vfio;
      user = config.myModules.primaryUser;
    in
    {
      _class = "nixos";

      options.myModules.vfio.kvmfr = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "KVMFR shared memory for Looking Glass frame relay";
        };
        memoryMB = lib.mkOption {
          type = lib.types.int;
          default = 64;
          description = "KVMFR shared memory size in MB (32=1440p SDR, 64=4K SDR, 128=4K HDR)";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.kvmfr.enable) {
        boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
        boot.kernelModules = [ "kvmfr" ];
        boot.extraModprobeConfig = ''
          options kvmfr static_size_mb=${toString cfg.kvmfr.memoryMB}
        '';

        services.udev.extraRules = ''
          SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", RUN+="${pkgs.coreutils}/bin/chown ${
            toString config.users.users.${user}.uid
          } /dev/$name"
        '';

        # looking-glass-client GUI moved to HM module home/modules/looking-glass/
      };
    };
in
{
  flake.modules.nixos.vfio-kvmfr = mod;

}
