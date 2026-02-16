{ inputs, ... }: {
  flake.nixosModules.system-kernel = { config, lib, pkgs, ... }: {
    options.myModules.kernel = {
      enable = lib.mkEnableOption "Custom kernel configuration";
      variant = lib.mkOption { type = lib.types.enum [ "cachyos" "cachyos-lto" "cachyos-sched-ext" "zen" "xanmod" "default" ]; default = "default"; };
      laptopSafe = lib.mkEnableOption "Laptop-safe configuration (cachyos)";
      preferLocalBuild = lib.mkEnableOption "Prefer local build (no cache)";
      mArch = lib.mkOption { type = lib.types.str; default = "x86-64-v3"; description = "Microarchitecture for CachyOS kernel (x86-64-v3, x86-64-v4, ZEN4, ZEN5, etc.)"; };
      extraParams = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "Extra kernel parameters"; };
    };

    config = lib.mkIf config.myModules.kernel.enable {
      boot.kernelPackages = 
        let
          pkgsKernel = if config.myModules.chaotic.optimizations.enable then pkgs else pkgs; # Chaotic overlay applies to pkgs
        in
          if config.myModules.kernel.variant == "cachyos" then pkgsKernel.linuxPackages_cachyos
          else if config.myModules.kernel.variant == "cachyos-lto" then pkgsKernel.linuxPackages_cachyos-lto
          else if config.myModules.kernel.variant == "cachyos-sched-ext" then pkgsKernel.linuxPackages_cachyos-sched-ext
          else if config.myModules.kernel.variant == "zen" then pkgs.linuxPackages_zen
          else if config.myModules.kernel.variant == "xanmod" then pkgs.linuxPackages_xanmod
          else pkgs.linuxPackages;

      # Apply extra parameters
      boot.kernelParams = config.myModules.kernel.extraParams ++ 
        lib.optionals (config.myModules.kernel.variant != "default") [
          # Common CachyOS params if needed
        ];
    };
  };
}
