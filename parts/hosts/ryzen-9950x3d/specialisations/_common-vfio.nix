# _common-vfio — the passthrough machinery the VFIO spec shares.
# Imported by vfio-dynamic; the _ prefix keeps it out of
# mkSpecialisations discovery (it is a fragment, not a boot entry).
{ config, lib, ... }:
{
  # Static vfio-pci capture at boot (managed='no') — no live detach of a running
  # GPU; the IDs derive from each enabled VM's gpu.staticIds.
  myModules.vfio.passthrough.enable = lib.mkForce true;
  myModules.vfio.bindMethod = lib.mkForce "static";
  # ACS override ON in every VFIO profile (never in normal): each profile passes
  # an NVMe that shares IOMMU group 22, and the split hands ONLY the passed
  # device(s) to the guest. This fakes PCIe isolation — guest DMA can still reach
  # the other group-22 devices — so keep nothing sensitive on the group-22 NVMe
  # that is NOT passed.
  myModules.vfio.acsOverride = "downstream,multifunction";
  # Bridged LAN: the bridge (lanBridge.name) enslaves this host's configured
  # uplink so guests get real LAN IPs (bridge-nf-call=0 → guest frames bypass
  # the host firewall/VPN).
  myModules.hardware.networking.lanBridge.enable = lib.mkForce true;
  # Gaming happens IN-GUEST in every VFIO profile — the host desktop, where one
  # exists at all, only manages the VMs: no host streaming, no host frame-gen.
  myModules.services.sunshine.enable = lib.mkForce false;
  # Why mkForce (riftCv1/xrizer): the Rift CV1 needs the host-bound 9070 XT,
  # which every VFIO profile hands to a guest -- the Monado runtime and the
  # Steam OpenVR layer follow host gaming off. ONE dynamic users.${...} attr
  # for both HM toggles: Nix rejects the same dynamic key twice per literal.
  myModules.hardware.riftCv1.enable = lib.mkForce false;
  home-manager.users.${config.myModules.primaryUser}.myModules.home = {
    lsfg-vk.enable = lib.mkForce false;
    xrizer.enable = lib.mkForce false;
  };
}
