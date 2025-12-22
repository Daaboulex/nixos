{ config, pkgs, lib, ... }:
{
  options.myModules.virtualization.libvirt.enable = lib.mkEnableOption "Libvirt virtualization";
  config = lib.mkIf config.myModules.virtualization.libvirt.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        package = pkgs.qemu_kvm;
      };
    };
    virtualisation.spiceUSBRedirection.enable = true;
    programs.virt-manager.enable = true;
    environment.systemPackages = with pkgs; [ libvirt qemu_kvm ];
    users.groups.libvirtd = {};
    users.groups.kvm = {};
    users.groups.qemu-libvirtd = {};
    users.groups.libvirt-qemu = {};
    users.users.${config.myModules.primaryUser}.extraGroups = [ "libvirtd" "kvm" "qemu-libvirtd" "libvirt-qemu" ];
  };
}
# Virtualization: generic libvirt enable (Alienware) with ovmf/swtpm and groups
# Example: programs.virt-manager.enable = true;