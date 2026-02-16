{ inputs, ... }: {
  flake.nixosModules.system-services = { config, lib, pkgs, ... }: {
    options.myModules.system.services.enable = lib.mkEnableOption "Common system services";

    config = lib.mkIf config.myModules.system.services.enable {
      services = {
        printing = { enable = true; browsing = true; defaultShared = false; drivers = [ pkgs.gutenprint pkgs.gutenprintBin ]; };
        libinput.enable = true;
        fstrim.enable = true;
        earlyoom.enable = true;
        acpid.enable = true;
        upower.enable = true;
        geoclue2.enable = true;
        usbmuxd.enable = true;
      };
    };
  };
}
