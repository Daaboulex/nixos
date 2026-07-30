# vfio-dynamic -- the single dynamic GPU-passthrough profile. Boot entry
# "ryzen-9950x3d-vfio-dynamic". Both win11-amd (RX 9070 XT) and win11-nvidia (1660S) are
# available; start either, ONE AT A TIME (dynamic hugepages + cpuPin allocate per running
# VM). Each dGPU reaches vfio-pci via libvirt (managed='yes') at VM start and is released
# on stop -- no boot vfio-pci.ids capture.
#
# DISPLAY MODEL (the "seamless" half). The host desktop renders on the iGPU (primary) and
# scans out to the 9070 XT's main monitor (DP-1); the iGPU is listed primary so KWin
# SURVIVES the 9070 XT being pulled when win11-amd starts (a primary-GPU removal would
# kill the session). The 1660S is held OUT of KWin entirely (gpuNvidia disabled below), so:
#   - win11-nvidia (the functional VM): grabs the 1660S, which KWin never held -> the host
#     desktop is completely undisturbed. This is the genuinely seamless path.
#   - win11-amd (WIP): grabs the 9070 XT, so the main monitor switches to the VM and the
#     host falls back to the (monitor-less) iGPU until the VM stops. KWin survives.
# The portrait panel on the 1660S (DP-5) shows win11-nvidia when it runs, else stays dark.
#
# WIP: win11-amd's AMD driver does not yet install (known Navi 48 problem -- memory note
# 9070xt-vfio-corruption) AND libvirt's managed='yes' release rebinds amdgpu to the 9070 XT
# on stop, which can BUG kernel 7.1 (amdgpu_device_mm_access). Do NOT rely on win11-amd
# until that is resolved; reboot to recover the card if its stop wedges it. win11-nvidia is
# the functional VM.
{ lib, ... }:
{
  # Shared passthrough machinery (IOMMU + vfio modules + ACS split + br0 + host-gaming-off).
  # bindMethod stays "static" but captures nothing here: both dGPUs are libvirtManaged, so
  # they are excluded from vfio-pci.ids and reach vfio-pci via libvirt at VM start instead.
  imports = [
    ./_common-vfio.nix
  ];

  # The 1660S is handed to win11-nvidia: keep the host nvidia driver inert and
  # blacklist nouveau (no nvidia iGPU to lose). amdgpu stays ON — the host desktop
  # renders on the iGPU and scans out to the 9070 XT (DP-1) until win11-amd grabs
  # it via libvirt, so this is NOT gpuAmd.passthrough. See parts/hardware/gpu-nvidia.nix.
  myModules.hardware.gpuNvidia.passthrough.enable = lib.mkForce true;

  # Host desktop on the iGPU (primary render, survives the 9070 XT release) + the 9070 XT as
  # a secondary scan-out head for the main monitor. The 1660S is absent -> KWin never opens
  # it, so win11-nvidia's grab is invisible to the desktop.
  myModules.vfio.sessionGpuDevices = lib.mkForce [
    "/dev/dri/by-gpu/igpu" # iGPU (7c:00.0) -- primary render; survives a dGPU being pulled
    "/dev/dri/by-gpu/amd" # RX 9070 XT (03:00.0) -- scan-out for the main monitor (DP-1)
  ];

  # Both VMs available; libvirt binds each dGPU to vfio-pci at VM start, releases on stop.
  myModules.vfio.vms.win11-amd.enable = lib.mkForce true;
  myModules.vfio.vms.win11-amd.gpu.libvirtManaged = lib.mkForce true;
  myModules.vfio.vms.win11-nvidia.enable = lib.mkForce true;
  myModules.vfio.vms.win11-nvidia.gpu.libvirtManaged = lib.mkForce true;

  # The 0f NVMe (/mnt/Windows-SSD) is passed to win11-amd. Disarm its systemd automount so
  # the host cannot re-grab the disk in the window between the hook unmount and libvirt's
  # PCI detach; remount by hand (or reboot) after the VM stops.
  fileSystems."/mnt/Windows-SSD".options = lib.mkForce [
    "uid=1000"
    "gid=100"
    "dmask=022"
    "fmask=133"
    "noexec"
    "nosuid"
    "nodev"
    "nofail"
    "noauto"
  ];

  # Dynamic host resources -- the host keeps every core + all RAM when no VM runs. No boot
  # isolcpus; the qemu prepare hook confines host tasks (cgroup AllowedCPUs) to the cores the
  # running VM does NOT use, and allocates that VM's hugepages, restoring both on stop. The
  # hook refuses to start a second dynamic-pinned VM while one runs (one at a time).
  myModules.vfio.cpuPin.dynamic = lib.mkForce true;
  myModules.vfio.cpuPin.threads = lib.mkForce 32; # 16c/32t Zen 5
  myModules.vfio.hugepages.enable = lib.mkForce true;
  myModules.vfio.hugepages.bootStatic = lib.mkForce false; # per-VM runtime allocation
  myModules.vfio.hugepages.size = lib.mkForce "2M"; # 2M allocates reliably at runtime (1G needs boot reservation)
  myModules.vfio.hugepages.count = lib.mkForce 16384; # 16384 x 2M = 32 GiB (either VM, one at a time)

  # Started by hand after login -- this is an interactive desktop profile, not a thin host.
  myModules.vfio.autostart = lib.mkForce false;
}
