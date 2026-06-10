# vfio-nvidia — security-research sandbox specialisation.
# Boot entry "ryzen-9950x3d-vfio-nvidia". The 9070 XT keeps driving the host display;
# the 1660S is captured by vfio-pci at boot → win11-nvidia. Purpose: a
# VM-detection-resistant sandbox (real 1660S + a real Windows install on the 0b NVMe
# via ACS) for analysing evasive apps. Each VM is scoped to its own profile.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Shared passthrough machinery: static capture + ACS split + br0 + host-gaming-off.
  imports = [ ./_common-vfio.nix ];

  # win11-nvidia runs on CCD1 (no V-Cache) → keep scx/host on CCD0 (0x00ff00ff)
  # while the VM owns CCD1 (base value 0xff00ff00 is for the CCD0 win11-amd VM).
  myModules.vfio.hostCpuMask = lib.mkForce "0x00ff00ff";
  # amdgpu can't be dropped (it runs the iGPU host head), so vfio-amd relies on
  # vfio-pci.ids to grab only the 9070 XT. nvidia drives nothing the host needs here
  # (the 1660S is its only card and it is passed), so disable it + blacklist nouveau:
  # the card sits unclaimed at boot and vfio-pci.ids captures it before any driver can.
  # (default + vfio-amd keep nvidia loaded.)
  myModules.hardware.gpuNvidia.enable = lib.mkForce false;
  boot.blacklistedKernelModules = [ "nouveau" ];
  # Enable win11-nvidia in this profile only (defined disabled at base). No Looking
  # Glass (disabled globally — ivshmem 1af4 is a detectable VM tell); view the
  # sandbox by switching the monitor input to the 1660S (both dGPUs are cabled).
  myModules.vfio.vms.win11-nvidia.enable = lib.mkForce true;
  # 1 GiB boot-static hugepages for the 32 GiB sandbox (1 GiB pages need boot reservation).
  myModules.vfio.hugepages.size = lib.mkForce "1G";
  myModules.vfio.hugepages.count = lib.mkForce 32; # 32 × 1 GiB = 32 GiB (win11-nvidia base RAM)
  myModules.vfio.hugepages.bootStatic = lib.mkForce true;
  # Core isolation — dedicate CCD1 (win11-nvidia's vCPUs); host + emulator/IO on CCD0.
  boot.kernelParams = [
    "isolcpus=domain,managed_irq,8-15,24-31"
    "nohz_full=8-15,24-31"
    "rcu_nocbs=8-15,24-31"
    "irqaffinity=0-7,16-23"
  ];
  # Autostart DISABLED until win11-nvidia is validated (same trap as vfio-amd, and it has
  # no Windows on 0b yet). Flip back to true once the guest is known-good.
  myModules.vfio.autostart = lib.mkForce false;
}
