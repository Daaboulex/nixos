{ config, pkgs, lib, ... }:
{
  options.myModules.virtualization.vmware.enable = lib.mkEnableOption "Enable VMware host support";
  config = lib.mkIf config.myModules.virtualization.vmware.enable {
    virtualisation.vmware.host.enable = true;
    services.xserver.videoDrivers = lib.mkOptionDefault [ "vmware" ];
    users.users.user.extraGroups = [ "vmware" ];
  };
}
# VMware: opt-in host enable; driver list added with mkOptionDefault
# Example: myModules.vmwareHost.enable = true;