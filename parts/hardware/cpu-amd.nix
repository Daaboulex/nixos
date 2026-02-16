{ inputs, ... }: {
  flake.nixosModules.hardware-cpu-amd = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.cpu.amd;
    in {
      options.myModules.hardware.cpu.amd = {
        enable = lib.mkEnableOption "AMD CPU optimizations";
        
        pstate = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable AMD P-State driver for modern power management";
          };
          mode = lib.mkOption {
            type = lib.types.enum [ "active" "passive" "guided" ];
            default = "active";
            description = "AMD P-State mode (active recommended for Zen 3+)";
          };
        };
        
        prefcore = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable AMD Preferred Core technology";
          };
        };
        
        kvm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable KVM-AMD virtualization support";
          };
        };
        
        updateMicrocode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Update AMD CPU microcode";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.concatLists [
          (lib.optionals cfg.pstate.enable [ "amd_pstate=${cfg.pstate.mode}" ])
          (lib.optionals cfg.prefcore.enable [ "amd_prefcore=enable" ])
        ];
        
        boot.kernelModules = lib.concatLists [
          [ "k10temp" ]
          (lib.optionals cfg.kvm.enable [ "kvm-amd" ])
        ];
        
        hardware.cpu.amd.updateMicrocode = cfg.updateMicrocode;
      };
    };
}
