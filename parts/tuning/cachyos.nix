# cachyos-settings — CachyOS upstream tuning toggles (zram, IO schedulers, audio, THP, systemd).
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
      cfg = config.myModules.tuning.cachyos;

      # All upstream sub-option names (passed through to cachyos.settings.*)
      upstreamToggles = [
        "zram"
        "ioSchedulers"
        "audio"
        "storage"
        "thp"
        "systemd"
        "timesyncd"
        "networkManager"
        "ntsync"
        "debuginfod"
        "coredump"
        "nvidia"
        "amdgpuGcnCompat"
      ];

      # GPU-specific toggles default to false; all others default to true
      gpuToggles = [
        "nvidia"
        "amdgpuGcnCompat"
      ];

      mkSubEnable =
        name:
        let
          isGpu = builtins.elem name gpuToggles;
        in
        lib.mkEnableOption "CachyOS ${name}" // lib.optionalAttrs (!isGpu) { default = true; };
    in
    {
      _class = "nixos";
      # ==================================================================
      # Options — myModules wrapper + extraPerformance (not upstream)
      # ==================================================================
      options.myModules.tuning.cachyos = {
        enable = lib.mkEnableOption "CachyOS system optimizations (upstream-matched settings)";

        # Generate sub-option enables that mirror cachyos.settings.*
      }
      // lib.genAttrs upstreamToggles (name: {
        enable = mkSubEnable name;
      })
      // {
        # extraPerformance sysctls moved to tuning/sysctls.nix
      };

      # ==================================================================
      # Config — pass-through to cachyos.settings.*
      # ==================================================================
      config = lib.mkIf cfg.enable {
        cachyos.settings = {
          enable = true;
        }
        // lib.genAttrs upstreamToggles (name: {
          inherit (cfg.${name}) enable;
        });
      };
    };
in
{
  flake.modules.nixos.tuning-cachyos = mod;

}
